import AppKit

public class StatusBarController {
    private let statusItem: NSStatusItem
    private let onCaptureFullScreen: () -> Void
    private let onCaptureArea: () -> Void
    private let onOpenEditor: () -> Void
    private let onQuit: () -> Void

    public init(
        onCaptureFullScreen: @escaping () -> Void,
        onCaptureArea: @escaping () -> Void,
        onOpenEditor: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onCaptureFullScreen = onCaptureFullScreen
        self.onCaptureArea = onCaptureArea
        self.onOpenEditor = onOpenEditor
        self.onQuit = onQuit

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = Self.drawIcon()
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let fullItem = NSMenuItem(title: "Capture Full Screen", action: #selector(handleFullScreen), keyEquivalent: "")
        fullItem.target = self
        fullItem.keyEquivalentModifierMask = [.command, .shift]
        fullItem.keyEquivalent = "1"
        menu.addItem(fullItem)

        let areaItem = NSMenuItem(title: "Capture Area", action: #selector(handleArea), keyEquivalent: "")
        areaItem.target = self
        areaItem.keyEquivalentModifierMask = [.command, .shift]
        areaItem.keyEquivalent = "2"
        menu.addItem(areaItem)

        menu.addItem(NSMenuItem.separator())

        let editorItem = NSMenuItem(title: "Open Editor", action: #selector(handleOpenEditor), keyEquivalent: "")
        editorItem.target = self
        menu.addItem(editorItem)

        menu.addItem(NSMenuItem.separator())

        let shortcutsHeader = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
        shortcutsHeader.isEnabled = false
        menu.addItem(shortcutsHeader)

        let s1 = NSMenuItem(title: "  Full Screen: Cmd+Shift+1", action: nil, keyEquivalent: "")
        s1.isEnabled = false
        menu.addItem(s1)

        let s2 = NSMenuItem(title: "  Area Select: Cmd+Shift+2", action: nil, keyEquivalent: "")
        s2.isEnabled = false
        menu.addItem(s2)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit LocalShot", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func handleFullScreen() { onCaptureFullScreen() }
    @objc private func handleArea() { onCaptureArea() }
    @objc private func handleOpenEditor() { onOpenEditor() }
    @objc private func handleQuit() { onQuit() }

    /// Brief flash to indicate clipboard copy
    func flashIcon() {
        guard let button = statusItem.button else { return }
        let original = button.image
        button.image = Self.drawCheckIcon()
        button.image?.isTemplate = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            button.image = original
        }
    }

    // MARK: - Icon Drawing

    private static func drawIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.4)

            // Viewfinder/crosshair icon
            let inset: CGFloat = 2
            let cornerLen: CGFloat = 4
            let r = rect.insetBy(dx: inset, dy: inset)

            // Top-left corner
            ctx.move(to: CGPoint(x: r.minX, y: r.minY + cornerLen))
            ctx.addLine(to: CGPoint(x: r.minX, y: r.minY + 1))
            ctx.addQuadCurve(to: CGPoint(x: r.minX + 1, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
            ctx.addLine(to: CGPoint(x: r.minX + cornerLen, y: r.minY))

            // Top-right corner
            ctx.move(to: CGPoint(x: r.maxX - cornerLen, y: r.minY))
            ctx.addLine(to: CGPoint(x: r.maxX - 1, y: r.minY))
            ctx.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 1), control: CGPoint(x: r.maxX, y: r.minY))
            ctx.addLine(to: CGPoint(x: r.maxX, y: r.minY + cornerLen))

            // Bottom-right corner
            ctx.move(to: CGPoint(x: r.maxX, y: r.maxY - cornerLen))
            ctx.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 1))
            ctx.addQuadCurve(to: CGPoint(x: r.maxX - 1, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
            ctx.addLine(to: CGPoint(x: r.maxX - cornerLen, y: r.maxY))

            // Bottom-left corner
            ctx.move(to: CGPoint(x: r.minX + cornerLen, y: r.maxY))
            ctx.addLine(to: CGPoint(x: r.minX + 1, y: r.maxY))
            ctx.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 1), control: CGPoint(x: r.minX, y: r.maxY))
            ctx.addLine(to: CGPoint(x: r.minX, y: r.maxY - cornerLen))

            ctx.strokePath()

            // Center crosshair
            let cx = rect.midX
            let cy = rect.midY
            ctx.setLineWidth(1.0)
            ctx.move(to: CGPoint(x: cx - 2.5, y: cy))
            ctx.addLine(to: CGPoint(x: cx + 2.5, y: cy))
            ctx.move(to: CGPoint(x: cx, y: cy - 2.5))
            ctx.addLine(to: CGPoint(x: cx, y: cy + 2.5))
            ctx.strokePath()

            return true
        }
        return image
    }

    private static func drawCheckIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        return NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(2.0)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // Checkmark
            ctx.move(to: CGPoint(x: 4, y: 9))
            ctx.addLine(to: CGPoint(x: 7.5, y: 13))
            ctx.addLine(to: CGPoint(x: 14, y: 5))
            ctx.strokePath()

            return true
        }
    }
}
