import AppKit
import LocalShotLib

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // Menu bar only, no Dock icon

let delegate = AppDelegate()
app.delegate = delegate

signal(SIGINT) { _ in
    print("\nStopping LocalShot...")
    exit(0)
}

app.run()
