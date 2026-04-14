import AppKit

/// Small floating thumbnail shown in the corner after a capture, with quick action buttons
public class QuickOverlayWindow: NSPanel {
    public init(
        image: NSImage,
        onCopy: @escaping () -> Void,
        onAnnotate: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        let thumbW: CGFloat = 280
        let imgAspect = image.size.height / max(image.size.width, 1)
        let thumbH = thumbW * min(imgAspect, 0.75)
        let barH: CGFloat = 40
        let totalH = thumbH + barH
        let padding: CGFloat = 20

        let screen = NSScreen.main ?? NSScreen.screens[0]
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

        let container = NSView(frame: NSRect(x: 0, y: 0, width: thumbW, height: totalH))
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.95).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(white: 1, alpha: 0.1).cgColor

        // Thumbnail image
        let imageView = NSImageView(frame: NSRect(x: 0, y: barH, width: thumbW, height: thumbH))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        container.addSubview(imageView)

        // Action bar
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: thumbW, height: barH))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor

        var btnX: CGFloat = 8

        let copyBtn = makeButton(title: "Copy", x: btnX) { onCopy() }
        bar.addSubview(copyBtn)
        btnX += 68

        let annotateBtn = makeButton(title: "Annotate", x: btnX) { onAnnotate() }
        bar.addSubview(annotateBtn)
        btnX += 78

        let saveBtn = makeButton(title: "Save", x: btnX) { onSave() }
        bar.addSubview(saveBtn)

        // Close button (right side)
        let closeBtn = makeButton(title: "\u{2715}", x: thumbW - 32) { onClose() }
        closeBtn.frame.size.width = 26
        closeBtn.font = NSFont.systemFont(ofSize: 11)
        closeBtn.contentTintColor = NSColor(white: 0.4, alpha: 1)
        bar.addSubview(closeBtn)

        container.addSubview(bar)
        self.contentView = container

        // Fade-in animation
        self.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            self.animator().alphaValue = 1
        }
    }

    private func makeButton(title: String, x: CGFloat, action: @escaping () -> Void) -> NSButton {
        let btn = ActionButton(title: title, action: action)
        btn.frame = NSRect(x: x, y: 6, width: 64, height: 28)
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        btn.contentTintColor = .white
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        btn.layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        return btn
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
