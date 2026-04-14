import AppKit

/// Custom NSView that renders the screenshot + annotations and handles drawing interactions
public class AnnotationView: NSView {
    public var image: NSImage? { didSet { needsDisplay = true } }
    public var annotations: [Annotation] = []
    public var activeTool: AnnotationToolType = .rectangle
    public var activeColor: NSColor = defaultColors[0] // Red
    public var activeStrokeWidth: CGFloat = 3
    public var activeFontSize: CGFloat = 20
    public var counterValue: Int = 1

    // Callbacks
    public var onAnnotationsChanged: (() -> Void)?

    // Drawing state
    private var isDragging = false
    private var dragStart: NSPoint = .zero
    private var dragCurrent: NSPoint = .zero
    private var inProgressAnnotation: Annotation?
    private var selectedAnnotation: Annotation?
    private var dragOffset: NSPoint = .zero

    // Text editing
    private var textField: NSTextField?

    override public var acceptsFirstResponder: Bool { true }
    override public var isFlipped: Bool { false }

    override public func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background
        ctx.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor)
        ctx.fill(bounds)

        // Draw the screenshot
        if let image = image,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let imageRect = imageDrawRect
            ctx.saveGState()
            // Flip for correct orientation
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1, y: -1)
            let flippedRect = CGRect(
                x: imageRect.origin.x,
                y: bounds.height - imageRect.origin.y - imageRect.height,
                width: imageRect.width,
                height: imageRect.height
            )
            ctx.draw(cgImage, in: flippedRect)
            ctx.restoreGState()
        }

        // Draw all annotations
        for annotation in annotations {
            annotation.draw(in: ctx, viewBounds: bounds)
        }

        // Draw in-progress annotation
        inProgressAnnotation?.draw(in: ctx, viewBounds: bounds)
    }

    /// The rect where the image is drawn (centered, scaled to fit)
    private var imageDrawRect: NSRect {
        guard let image = image else { return bounds }
        let imgW = image.size.width
        let imgH = image.size.height
        let scale = min(bounds.width / imgW, bounds.height / imgH, 1)
        let w = imgW * scale
        let h = imgH * scale
        let x = (bounds.width - w) / 2
        let y = (bounds.height - h) / 2
        return NSRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Mouse Events

    override public func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        commitTextEditing()

        if activeTool == .select {
            // Hit test for existing annotations (reverse order = top first)
            selectedAnnotation?.isSelected = false
            selectedAnnotation = nil

            for annotation in annotations.reversed() {
                if annotation.hitTest(point: point) {
                    selectedAnnotation = annotation
                    annotation.isSelected = true
                    dragOffset = NSPoint(x: point.x - annotation.bounds.midX, y: point.y - annotation.bounds.midY)
                    isDragging = true
                    dragStart = point
                    needsDisplay = true
                    return
                }
            }
            needsDisplay = true
            return
        }

        if activeTool == .text {
            showTextField(at: point)
            return
        }

        if activeTool == .counter {
            let counter = CounterAnnotation(center: point, number: counterValue, color: activeColor)
            annotations.append(counter)
            counterValue += 1
            onAnnotationsChanged?()
            needsDisplay = true
            return
        }

        isDragging = true
        dragStart = point
        dragCurrent = point

        // Create in-progress annotation
        switch activeTool {
        case .rectangle:
            let a = RectAnnotation(origin: point, size: .zero, color: activeColor, strokeWidth: activeStrokeWidth)
            inProgressAnnotation = a
        case .ellipse:
            let a = EllipseAnnotation(origin: point, size: .zero, color: activeColor, strokeWidth: activeStrokeWidth)
            inProgressAnnotation = a
        case .arrow:
            let a = ArrowAnnotation(start: point, end: point, color: activeColor, strokeWidth: activeStrokeWidth)
            inProgressAnnotation = a
        case .line:
            let a = LineAnnotation(start: point, end: point, color: activeColor, strokeWidth: activeStrokeWidth)
            inProgressAnnotation = a
        case .freehand:
            let a = FreehandAnnotation(color: activeColor, strokeWidth: activeStrokeWidth)
            a.points.append(point)
            inProgressAnnotation = a
        case .highlight:
            let a = HighlightAnnotation(origin: point, size: .zero, color: activeColor)
            inProgressAnnotation = a
        case .blur:
            let a = BlurAnnotation(origin: point, size: .zero)
            inProgressAnnotation = a
        default:
            break
        }
    }

    override public func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragCurrent = point

        if activeTool == .select, isDragging, let selected = selectedAnnotation {
            let delta = NSPoint(x: point.x - dragStart.x, y: point.y - dragStart.y)
            selected.move(by: delta)
            dragStart = point
            needsDisplay = true
            return
        }

        guard isDragging else { return }

        // Update in-progress annotation
        switch inProgressAnnotation {
        case let rect as RectAnnotation:
            rect.origin = NSPoint(x: min(dragStart.x, point.x), y: min(dragStart.y, point.y))
            rect.size = NSSize(width: abs(point.x - dragStart.x), height: abs(point.y - dragStart.y))
        case let ellipse as EllipseAnnotation:
            ellipse.origin = NSPoint(x: min(dragStart.x, point.x), y: min(dragStart.y, point.y))
            ellipse.size = NSSize(width: abs(point.x - dragStart.x), height: abs(point.y - dragStart.y))
        case let arrow as ArrowAnnotation:
            arrow.end = point
        case let line as LineAnnotation:
            line.end = point
        case let freehand as FreehandAnnotation:
            freehand.points.append(point)
        case let highlight as HighlightAnnotation:
            highlight.origin = NSPoint(x: min(dragStart.x, point.x), y: min(dragStart.y, point.y))
            highlight.size = NSSize(width: abs(point.x - dragStart.x), height: abs(point.y - dragStart.y))
        case let blur as BlurAnnotation:
            blur.origin = NSPoint(x: min(dragStart.x, point.x), y: min(dragStart.y, point.y))
            blur.size = NSSize(width: abs(point.x - dragStart.x), height: abs(point.y - dragStart.y))
        default:
            break
        }

        needsDisplay = true
    }

    override public func mouseUp(with event: NSEvent) {
        isDragging = false

        if let annotation = inProgressAnnotation {
            // Only add if it has meaningful size
            let b = annotation.bounds
            if b.width > 3 || b.height > 3 || annotation is FreehandAnnotation {
                annotations.append(annotation)
                onAnnotationsChanged?()
            }
            inProgressAnnotation = nil
        }

        needsDisplay = true
    }

    override public func keyDown(with event: NSEvent) {
        // Delete/Backspace to remove selected
        if event.keyCode == 51 || event.keyCode == 117 { // Backspace / Delete
            if let selected = selectedAnnotation {
                annotations.removeAll { $0.id == selected.id }
                selectedAnnotation = nil
                onAnnotationsChanged?()
                needsDisplay = true
                return
            }
        }

        // Cmd+Z undo
        if event.modifierFlags.contains(.command) && event.keyCode == 6 { // Z
            if !annotations.isEmpty {
                annotations.removeLast()
                onAnnotationsChanged?()
                needsDisplay = true
            }
            return
        }

        // Tool shortcuts (only when no modifiers)
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            for tool in AnnotationToolType.allCases {
                if event.keyCode == tool.keyCode {
                    activeTool = tool
                    onAnnotationsChanged?()
                    return
                }
            }
        }

        super.keyDown(with: event)
    }

    // MARK: - Text Editing

    private func showTextField(at point: NSPoint) {
        let field = NSTextField(frame: NSRect(x: point.x, y: point.y - 12, width: 200, height: 28))
        field.font = NSFont.systemFont(ofSize: activeFontSize, weight: .bold)
        field.textColor = activeColor
        field.backgroundColor = NSColor.white.withAlphaComponent(0.1)
        field.isBordered = true
        field.focusRingType = .none
        field.isEditable = true
        field.placeholderString = "Type here..."
        field.target = self
        field.action = #selector(textFieldDone(_:))
        field.cell?.sendsActionOnEndEditing = true

        addSubview(field)
        window?.makeFirstResponder(field)
        textField = field
    }

    @objc private func textFieldDone(_ sender: NSTextField) {
        let text = sender.stringValue
        if !text.isEmpty {
            let origin = NSPoint(x: sender.frame.origin.x, y: sender.frame.origin.y)
            let annotation = TextAnnotation(origin: origin, text: text, color: activeColor, fontSize: activeFontSize)
            annotations.append(annotation)
            onAnnotationsChanged?()
        }
        sender.removeFromSuperview()
        textField = nil
        needsDisplay = true
    }

    private func commitTextEditing() {
        if let field = textField {
            textFieldDone(field)
        }
    }

    // MARK: - Export

    /// Render the view to an NSImage (for copy/save)
    public func exportImage() -> NSImage? {
        guard let image = image else { return nil }
        let imgSize = image.size

        let exportImage = NSImage(size: imgSize)
        exportImage.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            exportImage.unlockFocus()
            return nil
        }

        // Draw the original screenshot at full resolution
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            ctx.draw(cgImage, in: CGRect(origin: .zero, size: imgSize))
        }

        // Scale annotations from view coords to image coords
        let viewRect = imageDrawRect
        let scaleX = imgSize.width / viewRect.width
        let scaleY = imgSize.height / viewRect.height

        ctx.saveGState()
        ctx.translateBy(x: -viewRect.origin.x * scaleX, y: -viewRect.origin.y * scaleY)
        ctx.scaleBy(x: scaleX, y: scaleY)

        for annotation in annotations {
            annotation.draw(in: ctx, viewBounds: bounds)
        }

        ctx.restoreGState()
        exportImage.unlockFocus()
        return exportImage
    }

    // MARK: - Public Actions

    public func undo() {
        if !annotations.isEmpty {
            annotations.removeLast()
            onAnnotationsChanged?()
            needsDisplay = true
        }
    }

    public func clearAll() {
        annotations.removeAll()
        selectedAnnotation = nil
        counterValue = 1
        onAnnotationsChanged?()
        needsDisplay = true
    }

    public func deleteSelected() {
        if let selected = selectedAnnotation {
            annotations.removeAll { $0.id == selected.id }
            selectedAnnotation = nil
            onAnnotationsChanged?()
            needsDisplay = true
        }
    }
}
