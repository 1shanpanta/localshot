import AppKit

public class StatusBarController {
    private let statusItem: NSStatusItem
    private let onCaptureFullScreen: () -> Void
    private let onCaptureArea: () -> Void
    private let onOpenEditor: () -> Void
    private let onQuit: () -> Void
    private let defaultIcon: NSImage
    private var flashToken: UInt64 = 0

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

        // Build the template icon once and mark it template BEFORE assigning.
        let icon = Self.drawIcon()
        icon.isTemplate = true
        self.defaultIcon = icon

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = icon

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let fullItem = NSMenuItem(title: "Capture Full Screen", action: #selector(handleFullScreen), keyEquivalent: "s")
        fullItem.target = self
        fullItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(fullItem)

        let areaItem = NSMenuItem(title: "Capture Area", action: #selector(handleArea), keyEquivalent: "a")
        areaItem.target = self
        areaItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(areaItem)

        menu.addItem(NSMenuItem.separator())

        // No keyEquivalent: Cmd+Q only works while the menu is open for an
        // accessory app (no main menu owns it globally), so showing ⌘Q would
        // mislead the user into thinking it fires when another app is focused.
        let quitItem = NSMenuItem(title: "Quit LocalShot", action: #selector(handleQuit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func handleFullScreen() { onCaptureFullScreen() }
    @objc private func handleArea() { onCaptureArea() }
    @objc private func handleQuit() { onQuit() }

    /// Brief flash to indicate clipboard copy. Token-guarded so that rapid
    /// back-to-back flashes correctly restore the real icon instead of
    /// leaving the checkmark or restoring to a stale snapshot.
    func flashIcon() {
        flashToken &+= 1
        let myToken = flashToken
        let check = Self.drawCheckIcon()
        check.isTemplate = true
        statusItem.button?.image = check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, self.flashToken == myToken else { return }
            self.statusItem.button?.image = self.defaultIcon
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
