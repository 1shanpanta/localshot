import AppKit
import Carbon.HIToolbox

public class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    /// Timestamp of the last accepted hotkey firing. Used to drop auto-repeat
    /// keyDowns so holding Cmd+Shift+S doesn't stack up dozens of captures.
    private var lastFireTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.5

    public init() {}

    public func start(
        onFullScreen: @escaping () -> Void,
        onAreaSelect: @escaping () -> Void
    ) {
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }

        let mask: NSEvent.EventTypeMask = [.keyDown]

        let handle: (NSEvent) -> Bool = { [weak self] event in
            guard let self = self else { return false }
            // Ignore synthetic auto-repeat keyDowns entirely.
            if event.isARepeat { return false }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let required: NSEvent.ModifierFlags = [.command, .shift]
            guard flags.intersection([.command, .option, .control, .shift]) == required else { return false }

            // Extra debounce on top of isARepeat for hammered presses.
            let now = ProcessInfo.processInfo.systemUptime
            guard (now - self.lastFireTime) >= self.debounceInterval else { return true }

            switch event.keyCode {
            case 1:
                self.lastFireTime = now
                onFullScreen()
                return true
            case 0:
                self.lastFireTime = now
                onAreaSelect()
                return true
            default:
                return false
            }
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            _ = handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            handle(event) ? nil : event
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
