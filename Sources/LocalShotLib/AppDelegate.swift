import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private var captureManager: ScreenCaptureManager!
    private var editorWindow: AnnotationWindow?
    private var selectionWindow: SelectionWindow?
    private var overlayWindow: QuickOverlayWindow?
    private var overlayAutoCloseWork: DispatchWorkItem?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        captureManager = ScreenCaptureManager()
        hotkeyManager = HotkeyManager()

        statusBar = StatusBarController(
            onCaptureFullScreen: { [weak self] in self?.captureFullScreen() },
            onCaptureArea: { [weak self] in self?.captureArea() },
            onOpenEditor: { [weak self] in self?.openEditorEmpty() },
            onQuit: { NSApp.terminate(nil) }
        )

        hotkeyManager.start(
            onFullScreen: { [weak self] in
                DispatchQueue.main.async { self?.captureFullScreen() }
            },
            onAreaSelect: { [weak self] in
                DispatchQueue.main.async { self?.captureArea() }
            }
        )

        print("LocalShot running. Cmd+Shift+S (fullscreen), Cmd+Shift+A (area).")

        // Trigger the system prompt on first launch. If later the user tries to
        // capture and it still returns nil, captureFullScreen/captureArea will
        // call promptScreenRecording() to guide them to System Settings.
        if !CGPreflightScreenCaptureAccess() {
            print("Screen Recording: NOT granted — requesting")
            CGRequestScreenCaptureAccess()
        } else {
            print("Screen Recording: granted")
        }
    }

    // MARK: - Permission

    /// Tracks whether we've already shown the guidance alert this session so
    /// we don't pop it on every hotkey press while the user is in settings.
    private var screenRecordingPromptShown = false

    /// Check Screen Recording TCC. If not granted, triggers the system prompt
    /// and shows our own guidance dialog. Returns true if already granted.
    @discardableResult
    private func ensureScreenRecordingOrPrompt() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }

        // Triggers the system prompt the first time, no-op afterwards.
        CGRequestScreenCaptureAccess()

        // Show our own alert once per session — it explains the relaunch step
        // that macOS's prompt glosses over.
        if !screenRecordingPromptShown {
            screenRecordingPromptShown = true
            promptScreenRecording()
        }
        return false
    }

    private func promptScreenRecording() {
        // Temporarily become a regular app so we can show an alert
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
            LocalShot needs Screen Recording to capture windows — otherwise it only sees the wallpaper.

            1. Click "Open Settings" below.
            2. Enable LocalShot under Screen Recording. If it's already listed but toggled off (or present from an older build), remove it first, then relaunch LocalShot and re-grant.
            3. Quit LocalShot from the menu bar and reopen it. macOS only applies newly-granted Screen Recording permission on app restart.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Quit LocalShot")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        NSApp.setActivationPolicy(.accessory)

        switch response {
        case .alertFirstButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            NSApp.terminate(nil)
        default:
            break
        }
    }

    // MARK: - Capture

    /// The screen the user is currently on (mouse cursor's screen).
    /// Falls back to NSScreen.main, then to the first connected screen.
    private func activeScreen() -> NSScreen {
        let mouseLoc = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func captureFullScreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            // Gate captures on the TCC permission so we don't silently save a
            // wallpaper-only image. If permission is missing we explicitly
            // guide the user instead of proceeding.
            guard self.ensureScreenRecordingOrPrompt() else { return }
            let screen = self.activeScreen()

            guard let image = self.captureManager.captureScreen(screen) else {
                print("Capture returned nil")
                self.promptScreenRecording()
                return
            }
            self.showOverlay(image: image, on: screen)
        }
    }

    private func captureArea() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            guard self.ensureScreenRecordingOrPrompt() else { return }
            let screen = self.activeScreen()

            guard let fullImage = self.captureManager.captureScreen(screen) else {
                self.promptScreenRecording()
                return
            }

            self.selectionWindow = SelectionWindow(
                screenshot: fullImage,
                screen: screen,
                onSelected: { [weak self] croppedImage in
                    self?.selectionWindow?.orderOut(nil)
                    self?.selectionWindow = nil
                    // Defer to the next runloop tick so the selection window is
                    // fully torn down before the overlay panel orders front —
                    // otherwise the overlay's slide-up animation can fire while
                    // the selection window still owns the screen, leaving no
                    // visible overlay.
                    DispatchQueue.main.async {
                        self?.showOverlay(image: croppedImage, on: screen)
                    }
                },
                onCancelled: { [weak self] in
                    self?.selectionWindow?.close()
                    self?.selectionWindow = nil
                }
            )
            self.selectionWindow?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Overlay

    private func showOverlay(image: NSImage, on screen: NSScreen) {
        overlayAutoCloseWork?.cancel()
        overlayWindow?.close()
        overlayWindow = QuickOverlayWindow(
            image: image,
            screen: screen,
            onCopy: { [weak self] in
                self?.copyToClipboard(image: image)
                self?.dismissOverlay()
            },
            onAnnotate: { [weak self] in
                self?.openEditor(with: image)
                self?.dismissOverlay()
            },
            onSave: { [weak self] in
                self?.quickSaveToDesktop(image: image)
                self?.dismissOverlay()
            },
            onClose: { [weak self] in
                self?.dismissOverlay()
            }
        )
        overlayWindow?.onHoverChanged = { [weak self] hovering in
            self?.handleOverlayHover(hovering: hovering)
        }
        overlayWindow?.orderFront(nil)
        overlayWindow?.animateIn()

        scheduleOverlayAutoClose()
    }

    private func scheduleOverlayAutoClose() {
        overlayAutoCloseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.dismissOverlay()
        }
        overlayAutoCloseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func handleOverlayHover(hovering: Bool) {
        if hovering {
            // Pause the auto-close timer while the cursor is over the overlay.
            overlayAutoCloseWork?.cancel()
            overlayAutoCloseWork = nil
        } else {
            // On mouse exit, restart the countdown so the user still gets an
            // auto-dismiss if they walked away without clicking anything.
            scheduleOverlayAutoClose()
        }
    }

    private func dismissOverlay() {
        overlayAutoCloseWork?.cancel()
        overlayAutoCloseWork = nil
        overlayWindow?.close()
        overlayWindow = nil
    }

    // MARK: - Editor

    private func openEditor(with image: NSImage) {
        if let existing = editorWindow, existing.isVisible {
            if existing.hasUnsavedAnnotations {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                let alert = NSAlert()
                alert.messageText = "Discard annotations?"
                alert.informativeText = "The current editor has unsaved annotations. Opening a new capture will discard them."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Discard")
                alert.addButton(withTitle: "Cancel")
                let response = alert.runModal()
                NSApp.setActivationPolicy(.accessory)

                if response != .alertFirstButtonReturn {
                    existing.makeKeyAndOrderFront(nil)
                    return
                }
            }
            existing.close()
        }
        editorWindow = AnnotationWindow(image: image)
        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openEditorEmpty() {
        if let existing = editorWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        captureFullScreen()
    }

    // MARK: - Clipboard & Save

    private func copyToClipboard(image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
        statusBar.flashCopied()
    }

    private func quickSaveToDesktop(image: NSImage) {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let url = desktop.appendingPathComponent(screenshotFilename())

        guard let png = image.pngData() else { return }
        do {
            try png.write(to: url)
            statusBar.flashSaved()
        } catch {
            print("Save failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Shared Helpers

func screenshotFilename() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    return "LocalShot \(formatter.string(from: Date())).png"
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
