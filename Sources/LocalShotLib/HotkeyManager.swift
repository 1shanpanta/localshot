import AppKit
import Carbon.HIToolbox

public class HotkeyManager {
    private var globalMonitor: Any?

    public init() {}

    public func start(
        onFullScreen: @escaping () -> Void,
        onAreaSelect: @escaping () -> Void
    ) {
        let mask: NSEvent.EventTypeMask = [.keyDown]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCmd = flags.contains(.command)
            let isShift = flags.contains(.shift)

            guard isCmd && isShift else { return }

            // Cmd+Shift+1 -> keyCode 18 (1)
            // Cmd+Shift+2 -> keyCode 19 (2)
            switch event.keyCode {
            case 18: // 1
                onFullScreen()
            case 19: // 2
                onAreaSelect()
            default:
                break
            }
        }
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
