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

/// NSImageView that fires a closure on click
private class ClickableImageView: NSImageView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onClick?()
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
