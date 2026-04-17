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

    private func captureFullScreen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }

            // Always attempt the capture — CGPreflightScreenCaptureAccess can return
            // stale results. The capture itself will return wallpaper-only if not granted,
            // but at least it works immediately after the user grants permission.
            guard let image = self.captureManager.captureFullScreen() else {
                print("Capture returned nil")
                self.promptScreenRecording()
                return
            }
            self.showOverlay(image: image)
        }
    }

    private func captureArea() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }

            guard let fullImage = self.captureManager.captureFullScreen() else {
                self.promptScreenRecording()
                return
            }

            self.selectionWindow = SelectionWindow(
                screenshot: fullImage,
                onSelected: { [weak self] croppedImage in
                    self?.selectionWindow?.orderOut(nil)
                    self?.selectionWindow = nil
                    // Defer to the next runloop tick so the selection window is
                    // fully torn down before the overlay panel orders front —
                    // otherwise the overlay's slide-up animation can fire while
                    // the selection window still owns the screen, leaving no
                    // visible overlay.
                    DispatchQueue.main.async {
                        self?.showOverlay(image: croppedImage)
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

    private func showOverlay(image: NSImage) {
        overlayAutoCloseWork?.cancel()
        overlayWindow?.close()
        overlayWindow = QuickOverlayWindow(
            image: image,
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
        overlayWindow?.orderFront(nil)
        overlayWindow?.animateIn()

        let work = DispatchWorkItem { [weak self] in
            self?.dismissOverlay()
        }
        overlayAutoCloseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
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
        statusBar.flashIcon()
    }

    private func quickSaveToDesktop(image: NSImage) {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let url = desktop.appendingPathComponent(screenshotFilename())

        guard let png = image.pngData() else { return }
        do {
            try png.write(to: url)
            statusBar.flashIcon()
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
