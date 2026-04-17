import AppKit

/// Transparent fullscreen overlay for area selection with crosshair and drag-to-select
public class SelectionWindow: NSWindow {
    public init(
        screenshot: NSImage,
        screen: NSScreen,
        onSelected: @escaping (NSImage) -> Void,
        onCancelled: @escaping () -> Void
    ) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hasShadow = false
        self.setFrame(screen.frame, display: false)

        let view = SelectionView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screenshot: screenshot,
            onSelected: onSelected,
            onCancelled: onCancelled
        )
        self.contentView = view
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }
}

private class SelectionView: NSView {
    private let screenshot: NSImage
    private let onSelected: (NSImage) -> Void
    private let onCancelled: () -> Void

    private var isDragging = false
    private var startPoint: NSPoint = .zero
    private var currentPoint: NSPoint = .zero
    private var mouseLocation: NSPoint = .zero

    init(
        frame: NSRect,
        screenshot: NSImage,
        onSelected: @escaping (NSImage) -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.screenshot = screenshot
        self.onSelected = onSelected
        self.onCancelled = onCancelled
        super.init(frame: frame)

        addTrackingArea(NSTrackingArea(
            rect: frame,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw the screenshot as background
        if let cgImage = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            ctx.draw(cgImage, in: bounds)
        }

        // Dark overlay
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.fill(bounds)

        if isDragging {
            let selRect = normalizedRect

            // Clear the selection area (show screenshot through)
            ctx.saveGState()
            if let cgImage = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                ctx.clip(to: selRect)
                ctx.draw(cgImage, in: bounds)
            }
            ctx.restoreGState()

            // Selection border
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(1.5)
            ctx.stroke(selRect)

            // Dimension label
            let w = Int(selRect.width * (screenshot.size.width / bounds.width))
            let h = Int(selRect.height * (screenshot.size.height / bounds.height))
            drawDimensionLabel(ctx: ctx, text: "\(w) x \(h)", at: selRect)
        }

        // Crosshair lines (when not dragging)
        if !isDragging {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor)
            ctx.setLineWidth(0.5)
            ctx.setLineDash(phase: 0, lengths: [4, 4])

            // Horizontal
            ctx.move(to: CGPoint(x: 0, y: mouseLocation.y))
            ctx.addLine(to: CGPoint(x: bounds.width, y: mouseLocation.y))
            // Vertical
            ctx.move(to: CGPoint(x: mouseLocation.x, y: 0))
            ctx.addLine(to: CGPoint(x: mouseLocation.x, y: bounds.height))
            ctx.strokePath()
        }

        // Help text
        if !isDragging {
            let text = "Drag to select area. Press Esc to cancel."
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.7)
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            let bgRect = NSRect(
                x: bounds.midX - size.width / 2 - 12,
                y: 40,
                width: size.width + 24,
                height: size.height + 12
            )
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 8, yRadius: 8)
            NSColor.black.withAlphaComponent(0.6).setFill()
            bgPath.fill()
            (text as NSString).draw(
                at: NSPoint(x: bgRect.minX + 12, y: bgRect.minY + 6),
                withAttributes: attrs
            )
        }
    }

    private var normalizedRect: NSRect {
        let x = min(startPoint.x, currentPoint.x)
        let y = min(startPoint.y, currentPoint.y)
        let w = abs(currentPoint.x - startPoint.x)
        let h = abs(currentPoint.y - startPoint.y)
        return NSRect(x: x, y: y, width: w, height: h)
    }

    private func drawDimensionLabel(ctx: CGContext, text: String, at selRect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let labelH = size.height + 6
        let labelW = size.width + 12

        // Position above selection, but flip to below if too close to top
        let aboveY = selRect.maxY + 6
        let belowY = selRect.minY - labelH - 6
        let labelY = aboveY + labelH > bounds.maxY ? max(belowY, 0) : aboveY

        let labelRect = NSRect(
            x: min(selRect.minX, bounds.maxX - labelW),
            y: labelY,
            width: labelW,
            height: labelH
        )

        NSGraphicsContext.saveGraphicsState()
        let bgPath = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bgPath.fill()
        (text as NSString).draw(
            at: NSPoint(x: labelRect.minX + 6, y: labelRect.minY + 3),
            withAttributes: attrs
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        isDragging = true
        startPoint = point
        currentPoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        isDragging = false

        let selRect = normalizedRect
        guard selRect.width > 5 && selRect.height > 5 else {
            needsDisplay = true
            return
        }

        // Crop the screenshot to the selected area
        let scaleX = screenshot.size.width / bounds.width
        let scaleY = screenshot.size.height / bounds.height

        let flippedY = screenshot.size.height - (selRect.maxY * scaleY)
        var cropRect = NSRect(
            x: selRect.origin.x * scaleX,
            y: flippedY,
            width: selRect.width * scaleX,
            height: selRect.height * scaleY
        )

        guard let cgImage = screenshot.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        // Clamp to image bounds so edge-of-screen selections don't silently
        // return nil from cgImage.cropping(to:).
        let imageBounds = NSRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        cropRect = cropRect.intersection(imageBounds)
        guard cropRect.width > 0, cropRect.height > 0,
              let cropped = cgImage.cropping(to: cropRect) else { return }

        let croppedImage = NSImage(cgImage: cropped, size: cropRect.size)
        onSelected(croppedImage)
    }

    override func mouseMoved(with event: NSEvent) {
        mouseLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancelled()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
