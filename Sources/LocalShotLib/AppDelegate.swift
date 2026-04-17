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

    private func promptScreenRecording() {
        // Temporarily become a regular app so we can show an alert
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "LocalShot needs Screen Recording to capture windows (not just wallpaper).\n\n1. Click \"Open Settings\" below\n2. Find LocalShot and toggle it ON\n3. Quit and relaunch LocalShot"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        // Go back to accessory (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
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
            let screen = self.activeScreen()

            // Always attempt the capture — CGPreflightScreenCaptureAccess can
            // return stale results. The capture itself will return wallpaper-
            // only if not granted, but at least it works immediately after the
            // user grants permission.
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
