import AppKit

/// Main editor window with annotation canvas + sidebar toolbar
public class AnnotationWindow: NSWindow {
    private let annotationView: AnnotationView

    /// True if the editor canvas has any annotations the user drew.
    /// AppDelegate checks this before silently replacing a visible editor.
    public var hasUnsavedAnnotations: Bool { !annotationView.annotations.isEmpty }

    private var toolButtons: [AnnotationToolType: NSButton] = [:]
    // Keyed by index into defaultColors, not NSColor — NSColor equality across
    // color spaces is unreliable and breaks swatch-highlight lookups.
    private var colorButtons: [Int: NSButton] = [:]
    private var strokeButtons: [CGFloat: NSButton] = [:]
    private var strokeDots: [CGFloat: NSView] = [:]

    public init(image: NSImage) {
        annotationView = AnnotationView()
        annotationView.image = image

        // Size the window based on image, with max bounds
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let maxW = screen.visibleFrame.width * 0.85
        let maxH = screen.visibleFrame.height * 0.85
        let scale = min(maxW / image.size.width, maxH / image.size.height, 1)
        let sidebarW: CGFloat = 180
        let titleBarH: CGFloat = 38

        // Floor to keep the sidebar usable. The sidebar is laid out top-down
        // with relative offsets for tools/color/stroke, but the 4 action
        // buttons (Copy/Save/Undo/Clear) are pinned to absolute y=12..80 at
        // the bottom. The stroke row sits at y = canvasH - 488; if the canvas
        // height drops below ~580 the stroke row collides with the action
        // buttons. 600 leaves ~32pt of breathing room.
        let minCanvasW: CGFloat = 320
        let minCanvasH: CGFloat = 600
        let canvasW = max(image.size.width * scale, minCanvasW)
        let canvasH = max(image.size.height * scale, minCanvasH)

        let windowW = canvasW + sidebarW
        let windowH = canvasH + titleBarH

        let frame = NSRect(
            x: (screen.visibleFrame.width - windowW) / 2 + screen.visibleFrame.origin.x,
            y: (screen.visibleFrame.height - windowH) / 2 + screen.visibleFrame.origin.y,
            width: windowW,
            height: windowH
        )

        super.init(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.title = "LocalShot"
        self.backgroundColor = NSColor(white: 0.1, alpha: 1)
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowW, height: windowH - titleBarH))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1).cgColor

        // Sidebar
        let sidebar = buildSidebar(height: contentView.frame.height)
        sidebar.frame.origin = NSPoint(x: 0, y: 0)
        contentView.addSubview(sidebar)

        // Canvas
        annotationView.frame = NSRect(
            x: sidebarW,
            y: 0,
            width: contentView.frame.width - sidebarW,
            height: contentView.frame.height
        )
        annotationView.autoresizingMask = [.width, .height]
        contentView.addSubview(annotationView)

        self.contentView = contentView
        updateToolSelection()

        // Wire up keyboard shortcut callbacks
        annotationView.onCopyRequest = { [weak self] in self?.handleCopy() }
        annotationView.onSaveRequest = { [weak self] in self?.saveAnnotatedImage() }

        // Make canvas first responder
        makeFirstResponder(annotationView)
    }

    // MARK: - Sidebar

    private func buildSidebar(height: CGFloat) -> NSView {
        let sidebarW: CGFloat = 180
        let sidebar = NSView(frame: NSRect(x: 0, y: 0, width: sidebarW, height: height))
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor(white: 0.11, alpha: 1).cgColor
        sidebar.autoresizingMask = [.height]

        var y = height - 12

        // Title
        y -= 20
        let title = makeLabel("TOOLS", size: 10, color: .init(white: 0.4, alpha: 1), bold: true)
        title.frame.origin = NSPoint(x: 14, y: y)
        sidebar.addSubview(title)

        // Tool buttons
        y -= 8
        for tool in AnnotationToolType.allCases {
            y -= 30
            let btn = makeToolButton(tool: tool, y: y)
            sidebar.addSubview(btn)
            toolButtons[tool] = btn
        }

        // Divider
        y -= 16
        let div1 = makeDivider(y: y, width: sidebarW)
        sidebar.addSubview(div1)

        // Color section
        y -= 20
        let colorLabel = makeLabel("COLOR", size: 10, color: .init(white: 0.4, alpha: 1), bold: true)
        colorLabel.frame.origin = NSPoint(x: 14, y: y)
        sidebar.addSubview(colorLabel)

        y -= 8
        let colorRow = NSView(frame: NSRect(x: 12, y: y - 28, width: sidebarW - 24, height: 28))
        var cx: CGFloat = 0
        for (index, color) in defaultColors.enumerated() {
            let btn = makeColorButton(color: color, x: cx)
            btn.tag = index
            colorRow.addSubview(btn)
            colorButtons[index] = btn
            // 18pt swatch + 1pt gap; 8 swatches fit in (sidebarW - 24) = 156.
            cx += 19
        }
        sidebar.addSubview(colorRow)
        y -= 36

        // Stroke width section
        y -= 12
        let strokeLabel = makeLabel("STROKE", size: 10, color: .init(white: 0.4, alpha: 1), bold: true)
        strokeLabel.frame.origin = NSPoint(x: 14, y: y)
        sidebar.addSubview(strokeLabel)

        y -= 8
        let strokeRow = NSView(frame: NSRect(x: 12, y: y - 28, width: sidebarW - 24, height: 28))
        var sx: CGFloat = 0
        for width: CGFloat in [1, 2, 3, 5, 8] {
            let btn = makeStrokeButton(width: width, x: sx)
            strokeRow.addSubview(btn)
            strokeButtons[width] = btn
            sx += 30
        }
        sidebar.addSubview(strokeRow)

        // Action buttons at bottom
        let actionsY: CGFloat = 12
        let copyBtn = makeActionButton(title: "Copy", x: 12, y: actionsY + 38, color: NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1), action: #selector(handleCopy))
        sidebar.addSubview(copyBtn)

        let saveBtn = makeActionButton(title: "Save", x: 12, y: actionsY, color: NSColor(red: 0.2, green: 0.83, blue: 0.6, alpha: 1), action: #selector(saveAnnotatedImage))
        sidebar.addSubview(saveBtn)

        // Undo + Clear row
        let undoBtn = makeSmallAction(title: "Undo", x: 97, y: actionsY + 38, action: #selector(handleUndo))
        sidebar.addSubview(undoBtn)

        let clearBtn = makeSmallAction(title: "Clear", x: 97, y: actionsY, action: #selector(handleClear))
        sidebar.addSubview(clearBtn)

        return sidebar
    }

    // MARK: - Button Factories

    private func makeToolButton(tool: AnnotationToolType, y: CGFloat) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 8, y: y, width: 164, height: 28))
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.title = "  \(tool.label)"
        btn.font = NSFont.systemFont(ofSize: 12)
        btn.contentTintColor = .white
        btn.alignment = .left
        btn.tag = AnnotationToolType.allCases.firstIndex(of: tool)!
        btn.target = self
        btn.action = #selector(toolSelected(_:))
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6

        // Add shortcut hint
        let shortcutLabel = NSTextField(labelWithString: tool.shortcut)
        shortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        shortcutLabel.textColor = NSColor(white: 0.35, alpha: 1)
        shortcutLabel.frame = NSRect(x: 144, y: 6, width: 16, height: 14)
        btn.addSubview(shortcutLabel)

        return btn
    }

    private func makeColorButton(color: NSColor, x: CGFloat) -> NSButton {
        let btn = NSButton(frame: NSRect(x: x, y: 4, width: 18, height: 18))
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.title = ""
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 9
        btn.layer?.backgroundColor = color.cgColor
        btn.target = self
        btn.action = #selector(colorSelected(_:))
        return btn
    }

    private func makeStrokeButton(width: CGFloat, x: CGFloat) -> NSButton {
        let btn = NSButton(frame: NSRect(x: x, y: 2, width: 26, height: 26))
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.title = ""
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 4
        btn.tag = Int(width)
        btn.target = self
        btn.action = #selector(strokeSelected(_:))

        // Draw a circle sized by width
        let dot = NSView(frame: NSRect(
            x: 13 - min(width + 1, 8),
            y: 13 - min(width + 1, 8),
            width: min(width + 1, 8) * 2,
            height: min(width + 1, 8) * 2
        ))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = min(width + 1, 8)
        dot.layer?.backgroundColor = annotationView.activeColor.cgColor
        btn.addSubview(dot)
        strokeDots[width] = dot

        return btn
    }

    private func makeActionButton(title: String, x: CGFloat, y: CGFloat, color: NSColor, action: Selector) -> NSButton {
        let btn = NSButton(frame: NSRect(x: x, y: y, width: 80, height: 30))
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.title = title
        btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        btn.contentTintColor = color
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        btn.layer?.backgroundColor = color.withAlphaComponent(0.15).cgColor
        btn.target = self
        btn.action = action
        return btn
    }

    private func makeSmallAction(title: String, x: CGFloat, y: CGFloat, action: Selector) -> NSButton {
        let btn = NSButton(frame: NSRect(x: x, y: y, width: 72, height: 30))
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.title = title
        btn.font = NSFont.systemFont(ofSize: 11)
        btn.contentTintColor = NSColor(white: 0.6, alpha: 1)
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        btn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
        btn.target = self
        btn.action = action
        return btn
    }

    private func makeLabel(_ text: String, size: CGFloat, color: NSColor, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.sizeToFit()
        return label
    }

    private func makeDivider(y: CGFloat, width: CGFloat) -> NSView {
        let div = NSView(frame: NSRect(x: 12, y: y, width: width - 24, height: 1))
        div.wantsLayer = true
        div.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
        return div
    }

    // MARK: - Actions

    @objc private func toolSelected(_ sender: NSButton) {
        let tool = AnnotationToolType.allCases[sender.tag]
        annotationView.activeTool = tool
        updateToolSelection()
        makeFirstResponder(annotationView)
    }

    @objc private func colorSelected(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0 && idx < defaultColors.count else { return }
        annotationView.activeColor = defaultColors[idx]
        refreshStrokeDotColors()
        updateColorSelection()
        makeFirstResponder(annotationView)
    }

    private var activeColorIndex: Int? {
        defaultColors.firstIndex(where: { $0 == annotationView.activeColor })
    }

    private func refreshStrokeDotColors() {
        for (_, dot) in strokeDots {
            dot.layer?.backgroundColor = annotationView.activeColor.cgColor
        }
    }

    @objc private func strokeSelected(_ sender: NSButton) {
        annotationView.activeStrokeWidth = CGFloat(sender.tag)
        updateStrokeSelection()
        makeFirstResponder(annotationView)
    }

    @objc private func handleCopy() {
        guard let image = annotationView.exportImage() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])

        // Green flash feedback like CleanShot
        if let content = contentView {
            let flash = NSView(frame: content.bounds)
            flash.wantsLayer = true
            flash.layer?.backgroundColor = NSColor(red: 0.2, green: 0.83, blue: 0.6, alpha: 0.15).cgColor
            content.addSubview(flash)
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                flash.animator().alphaValue = 0
            }, completionHandler: {
                flash.removeFromSuperview()
            })
        }
    }

    @objc private func saveAnnotatedImage() {
        guard let image = annotationView.exportImage() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = screenshotFilename()
        panel.canCreateDirectories = true

        panel.beginSheetModal(for: self) { response in
            guard response == .OK, let url = panel.url,
                  let png = image.pngData() else { return }
            do {
                try png.write(to: url)
            } catch {
                print("Save failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func handleUndo() {
        annotationView.undo()
        makeFirstResponder(annotationView)
    }

    @objc private func handleClear() {
        annotationView.clearAll()
        makeFirstResponder(annotationView)
    }

    // MARK: - UI Updates

    private func updateToolSelection() {
        for (tool, btn) in toolButtons {
            if tool == annotationView.activeTool {
                btn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.12).cgColor
                btn.contentTintColor = .white
            } else {
                btn.layer?.backgroundColor = nil
                btn.contentTintColor = NSColor(white: 0.6, alpha: 1)
            }
        }
    }

    private func updateColorSelection() {
        let selectedIdx = activeColorIndex
        for (idx, btn) in colorButtons {
            let isSelected = (idx == selectedIdx)
            btn.layer?.borderWidth = isSelected ? 2 : 0
            btn.layer?.borderColor = NSColor.white.cgColor
        }
    }

    private func updateStrokeSelection() {
        for (width, btn) in strokeButtons {
            let isSelected = width == annotationView.activeStrokeWidth
            btn.layer?.backgroundColor = isSelected
                ? NSColor(white: 1, alpha: 0.12).cgColor
                : nil
        }
    }
}
