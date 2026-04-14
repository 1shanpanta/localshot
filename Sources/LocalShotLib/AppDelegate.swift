import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private var captureManager: ScreenCaptureManager!
    private var editorWindow: AnnotationWindow?
    private var selectionWindow: SelectionWindow?
    private var overlayWindow: QuickOverlayWindow?

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

        print("LocalShot running. Use Cmd+Shift+1 (fullscreen) or Cmd+Shift+2 (area).")
    }

    // MARK: - Capture Actions

    private func captureFullScreen() {
        // Small delay to let menu close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            guard let image = self.captureManager.captureFullScreen() else {
                print("Screen capture failed")
                return
            }
            self.showOverlay(image: image)
        }
    }

    private func captureArea() {
        // First capture full screen, then show selection overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            guard let fullImage = self.captureManager.captureFullScreen() else {
                print("Screen capture failed")
                return
            }

            self.selectionWindow = SelectionWindow(
                screenshot: fullImage,
                onSelected: { [weak self] croppedImage in
                    self?.selectionWindow?.close()
                    self?.selectionWindow = nil
                    self?.showOverlay(image: croppedImage)
                },
                onCancelled: { [weak self] in
                    self?.selectionWindow?.close()
                    self?.selectionWindow = nil
                }
            )
            self.selectionWindow?.makeKeyAndOrderFront(nil)
        }
    }

    private func showOverlay(image: NSImage) {
        overlayWindow?.close()
        overlayWindow = QuickOverlayWindow(
            image: image,
            onCopy: { [weak self] in
                self?.copyToClipboard(image: image)
                self?.overlayWindow?.close()
                self?.overlayWindow = nil
            },
            onAnnotate: { [weak self] in
                self?.overlayWindow?.close()
                self?.overlayWindow = nil
                self?.openEditor(with: image)
            },
            onSave: { [weak self] in
                self?.saveImage(image: image)
                self?.overlayWindow?.close()
                self?.overlayWindow = nil
            },
            onClose: { [weak self] in
                self?.overlayWindow?.close()
                self?.overlayWindow = nil
            }
        )
        overlayWindow?.orderFront(nil)

        // Auto-close after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.overlayWindow?.close()
            self?.overlayWindow = nil
        }
    }

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
        // Nothing to show without an image
        captureFullScreen()
    }

    // MARK: - Clipboard & Save

    private func copyToClipboard(image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
        statusBar.flashIcon()
    }

    private func saveImage(image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "localshot-\(Int(Date().timeIntervalSince1970)).png"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: url)
        }
    }
}
