import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// Global hotkey listener backed by a CGEventTap so we can CONSUME the
/// matching keyDown — without that, pressing Cmd+Shift+S in Xcode would both
/// fire our screenshot AND pop Xcode's "Save As" dialog.
///
/// Requires the Input Monitoring TCC permission (see `NSInputMonitoringUsageDescription`).
public class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onFullScreen: (() -> Void)?
    private var onAreaSelect: (() -> Void)?
    private var lastFireTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.5

    public init() {}

    public func start(
        onFullScreen: @escaping () -> Void,
        onAreaSelect: @escaping () -> Void
    ) {
        self.onFullScreen = onFullScreen
        self.onAreaSelect = onAreaSelect

        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,      // active: may consume/modify events
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("HotkeyManager: could not create event tap. Grant LocalShot Input Monitoring in System Settings > Privacy & Security.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Kernel can disable the tap under load or after a permission change.
        // Re-enable and pass the event through.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let flags = event.flags
        let required: CGEventFlags = [.maskCommand, .maskShift]
        let disallowed: CGEventFlags = [.maskControl, .maskAlternate]
        guard flags.contains(required), flags.intersection(disallowed).isEmpty else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        // Only our two hotkey keycodes are interesting; everything else passes.
        guard keyCode == 0 || keyCode == 1 else {
            return Unmanaged.passUnretained(event)
        }

        // Drop auto-repeat so holding the hotkey doesn't stack captures.
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if isRepeat { return nil }

        // Debounce rapid-fire presses.
        let now = ProcessInfo.processInfo.systemUptime
        guard (now - lastFireTime) >= debounceInterval else { return nil }
        lastFireTime = now

        if keyCode == 1 {
            DispatchQueue.main.async { [weak self] in self?.onFullScreen?() }
        } else {
            DispatchQueue.main.async { [weak self] in self?.onAreaSelect?() }
        }
        return nil // consume — event does NOT reach the focused app
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}
