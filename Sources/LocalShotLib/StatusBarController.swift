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

        // Custom attributed titles so we can render the shortcut as ⌘⇧S
        // (Cmd first, Shift second) instead of macOS's default ⇧⌘S order.
        // Trade-off: no native keyEquivalent, so ⌘⇧S from inside the menu
        // won't trigger the item — but the CGEventTap fires the hotkey
        // globally regardless of menu state.
        let fullItem = NSMenuItem(title: "Capture Full Screen", action: #selector(handleFullScreen), keyEquivalent: "")
        fullItem.target = self
        fullItem.attributedTitle = Self.menuLabel(title: "Capture Full Screen", shortcut: "⌘⇧S")
        menu.addItem(fullItem)

        let areaItem = NSMenuItem(title: "Capture Area", action: #selector(handleArea), keyEquivalent: "")
        areaItem.target = self
        areaItem.attributedTitle = Self.menuLabel(title: "Capture Area", shortcut: "⌘⇧A")
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

    /// Copy (clipboard) — checkmark flash.
    func flashCopied() { flash(icon: Self.drawCheckIcon()) }

    /// Save (to disk) — down-arrow flash so the user can tell copy/save apart.
    func flashSaved() { flash(icon: Self.drawSaveIcon()) }

    /// Back-compat alias (equivalent to flashCopied).
    func flashIcon() { flashCopied() }

    /// Token-guarded flash so rapid back-to-back calls restore the real icon
    /// instead of leaving a stale flash glyph.
    private func flash(icon: NSImage) {
        flashToken &+= 1
        let myToken = flashToken
        icon.isTemplate = true
        statusItem.button?.image = icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, self.flashToken == myToken else { return }
            self.statusItem.button?.image = self.defaultIcon
        }
    }

    /// Build an NSMenuItem title with the shortcut label right-aligned.
    /// Used to control modifier-symbol ordering (⌘⇧ instead of native ⇧⌘).
    private static func menuLabel(title: String, shortcut: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 220, options: [:])]
        paragraph.defaultTabInterval = 220

        let font = NSFont.menuFont(ofSize: 0)
        let attr = NSMutableAttributedString(string: "\(title)\t\(shortcut)")
        attr.addAttributes([
            .font: font,
            .paragraphStyle: paragraph,
            .foregroundColor: NSColor.labelColor
        ], range: NSRange(location: 0, length: attr.length))

        let shortcutRange = (attr.string as NSString).range(of: shortcut)
        if shortcutRange.location != NSNotFound {
            attr.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: shortcutRange)
        }
        return attr
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

    /// Arrow pointing down into a tray — shown after a "Save to Desktop" so
    /// the user can visually distinguish save from a plain copy-to-clipboard.
    private static func drawSaveIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        return NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // Down arrow shaft + head
            ctx.move(to: CGPoint(x: 9, y: 14))
            ctx.addLine(to: CGPoint(x: 9, y: 6))
            ctx.strokePath()

            ctx.move(to: CGPoint(x: 5.5, y: 9))
            ctx.addLine(to: CGPoint(x: 9, y: 5))
            ctx.addLine(to: CGPoint(x: 12.5, y: 9))
            ctx.strokePath()

            // Tray line
            ctx.move(to: CGPoint(x: 3, y: 3))
            ctx.addLine(to: CGPoint(x: 15, y: 3))
            ctx.strokePath()

            return true
        }
    }
}
