import AppKit
import LocalShotLib

setvbuf(stdout, nil, _IOLBF, 0)
setvbuf(stderr, nil, _IOLBF, 0)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

// Use a Dispatch signal source on the main queue so Ctrl+C routes through
// NSApp.terminate() — this lets StatusBarController and HotkeyManager run
// their deinits and remove the status bar icon + event monitors cleanly.
// Calling exit() from a raw signal handler skips all of that.
signal(SIGINT, SIG_IGN)
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSource.setEventHandler {
    print("\nStopping LocalShot...")
    NSApp.terminate(nil)
}
sigintSource.resume()

app.run()
