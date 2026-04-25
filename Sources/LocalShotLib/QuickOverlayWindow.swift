import AppKit

/// Small floating thumbnail shown in the corner after a capture, with quick action buttons.
/// Positioned bottom-right like CleanShot X. Draggable. Click thumbnail to annotate.
public class QuickOverlayWindow: NSPanel {
    private var onAnnotateAction: (() -> Void)?
    private var onCloseAction: (() -> Void)?
    /// Called when the mouse enters (true) or exits (false) the overlay.
    /// AppDelegate uses this to pause the auto-close countdown.
    public var onHoverChanged: ((Bool) -> Void)?

    public init(
        image: NSImage,
        screen: NSScreen,
        onCopy: @escaping () -> Void,
        onAnnotate: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onAnnotateAction = onAnnotate
        self.onCloseAction = onClose

        let thumbW: CGFloat = 300
        let imgAspect = image.size.height / max(image.size.width, 1)
        let thumbH = thumbW * min(imgAspect, 0.75)
        let barH: CGFloat = 44
        let totalH = thumbH + barH
        let padding: CGFloat = 16

        let frame = NSRect(
            x: screen.visibleFrame.maxX - thumbW - padding,
            y: screen.visibleFrame.minY + padding,
            width: thumbW,
            height: totalH
        )

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.hidesOnDeactivate = false

        let container = HoverTrackingView(frame: NSRect(x: 0, y: 0, width: thumbW, height: totalH))
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.96).cgColor
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor
        container.onMouseEntered = { [weak self] in self?.onHoverChanged?(true) }
        container.onMouseExited = { [weak self] in self?.onHoverChanged?(false) }

        // Shadow is drawn by NSWindow (hasShadow = true) — no NSShadow on the
        // container, since masksToBounds clips it and it would never render.

        // Thumbnail image — clicking opens editor
        let imageView = ClickableImageView(frame: NSRect(x: 0, y: barH, width: thumbW, height: thumbH))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.onClick = onAnnotate
        container.addSubview(imageView)

        // Action bar
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: thumbW, height: barH))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor

        let buttonSpacing: CGFloat = 6
        let buttonH: CGFloat = 30
        let buttonY: CGFloat = (barH - buttonH) / 2
        var btnX: CGFloat = 8

        let copyBtn = makeButton(title: "Copy", x: btnX, y: buttonY, width: 60, height: buttonH) { onCopy() }
        bar.addSubview(copyBtn)
        btnX += 60 + buttonSpacing

        let annotateBtn = makeButton(title: "Annotate", x: btnX, y: buttonY, width: 72, height: buttonH) { onAnnotate() }
        bar.addSubview(annotateBtn)
        btnX += 72 + buttonSpacing

        let saveBtn = makeButton(title: "Save", x: btnX, y: buttonY, width: 54, height: buttonH) { onSave() }
        bar.addSubview(saveBtn)

        // Close button (right side)
        let closeBtn = makeButton(title: "\u{2715}", x: thumbW - 34, y: buttonY, width: 28, height: buttonH) { onClose() }
        closeBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        closeBtn.contentTintColor = NSColor(white: 0.45, alpha: 1)
        closeBtn.layer?.backgroundColor = NSColor.clear.cgColor
        bar.addSubview(closeBtn)

        container.addSubview(bar)
        self.contentView = container

        // Start transparent; caller orders front, then animateIn() fades + slides up.
        self.alphaValue = 0
    }

    /// Fade + slide-up once the window is on screen. Call AFTER orderFront.
    public func animateIn() {
        let finalFrame = self.frame
        var startFrame = finalFrame
        startFrame.origin.y -= 20
        // display:false avoids a visible flash at the offset position before
        // the animator takes over.
        self.setFrame(startFrame, display: false)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
            self.animator().setFrame(finalFrame, display: true)
        }
    }


    override public func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCloseAction?()
        } else {
            super.keyDown(with: event)
        }
    }

    private func makeButton(title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, action: @escaping () -> Void) -> NSButton {
        let btn = ActionButton(title: title, action: action)
        btn.frame = NSRect(x: x, y: y, width: width, height: height)
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        btn.contentTintColor = .white
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        btn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        return btn
    }
}

/// NSImageView that fires a closure on click and starts a drag-and-drop
/// session with a PNG file URL when the user drags it out — drop the
/// thumbnail into any app that accepts image / file drops (Claude Code,
/// Slack, Messages, Finder, mail composers, etc).
///
/// Disambiguates click vs drag by a 4pt movement threshold. `mouseDown`
/// stashes the start point; `mouseDragged` past the threshold begins the
/// drag session; `mouseUp` only fires the onClick handler if no drag was
/// started.
///
/// Overrides `acceptsFirstMouse` because the host panel is `.nonactivatingPanel`
/// and never becomes key — without this, clicks on the thumbnail are swallowed
/// by the window instead of reaching `mouseDown`.
private class ClickableImageView: NSImageView, NSDraggingSource {
    var onClick: (() -> Void)?
    private var mouseDownLocation: NSPoint = .zero
    private var dragStarted = false
    private let dragThreshold: CGFloat = 4

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        dragStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted else { return }
        let dx = event.locationInWindow.x - mouseDownLocation.x
        let dy = event.locationInWindow.y - mouseDownLocation.y
        guard hypot(dx, dy) > dragThreshold else { return }
        beginDrag(with: event)
        dragStarted = true
    }

    override func mouseUp(with event: NSEvent) {
        if !dragStarted { onClick?() }
        dragStarted = false
    }

    private func beginDrag(with event: NSEvent) {
        guard let image = self.image,
              let url = writePNGToTemp(image) else { return }

        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)

        let dragItem = NSDraggingItem(pasteboardWriter: item)
        // Show the thumbnail itself as the drag preview, anchored at the
        // current cursor, scaled to the view's bounds so the image-under-
        // cursor visual is consistent with what the user clicked.
        dragItem.setDraggingFrame(bounds, contents: image)

        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    /// Write the captured image to a PNG in NSTemporaryDirectory and return
    /// its file URL. macOS cleans the temp dir on its own schedule, so we
    /// don't track or delete the file ourselves.
    private func writePNGToTemp(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let filename = "LocalShot \(formatter.string(from: Date())).png"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        do {
            try png.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        // Copy semantics — the source file in /tmp stays put after the drop.
        .copy
    }
}

/// Simple NSButton subclass that fires a closure
private class ActionButton: NSButton {
    private var handler: (() -> Void)?

    convenience init(title: String, action handler: @escaping () -> Void) {
        self.init(frame: .zero)
        self.title = title
        self.handler = handler
        self.target = self
        self.action = #selector(fire)
    }

    @objc private func fire() {
        handler?()
    }
}

/// NSView that emits mouse enter/exit callbacks via an auto-sized tracking area.
private class HoverTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
