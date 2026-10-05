import Foundation
import ApplicationServices

/// Manages macOS Accessibility and Event Tap access for cross-device modifier injection,
/// including live permission auto-detection when running under diagnostic flags.
final class AccessibilityDetector {
    static let shared = AccessibilityDetector()

    var modifierFlagsProvider: (() -> CGEventFlags)?
    var onLog: ((String) -> Void)?

    private(set) var eventTapPort: CFMachPort?
    private var checkTimer: Timer?

    private func logMessage(_ s: String) {
        if let onLog = onLog {
            onLog(s)
        } else {
            FileHandle.standardError.write(Data("ack05d: \(s)\n".utf8))
        }
    }

    /// Attempt to install the system event tap. Returns true if installed or already active.
    @discardableResult
    func installEventTap() -> Bool {
        guard eventTapPort == nil else { return true }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                (1 << CGEventType.keyUp.rawValue) |
                                (1 << CGEventType.leftMouseDown.rawValue) |
                                (1 << CGEventType.leftMouseUp.rawValue) |
                                (1 << CGEventType.rightMouseDown.rawValue) |
                                (1 << CGEventType.rightMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = AccessibilityDetector.shared.eventTapPort {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return nil
                }
                if let flags = AccessibilityDetector.shared.modifierFlagsProvider?(), !flags.isEmpty {
                    event.flags.formUnion(flags)
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            return false
        }

        eventTapPort = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logMessage("successfully installed system event tap for cross-device modifiers!")
        return true
    }

    /// Check and log current accessibility and event access status.
    func logPermissions() {
        let axTrusted = AXIsProcessTrusted()
        let listen = CGPreflightListenEventAccess()
        let post = CGPreflightPostEventAccess()
        logMessage("permissions: axTrusted=\(axTrusted), listenAccess=\(listen), postAccess=\(post)")
    }

    /// Live auto-detection: checks permissions, attempts installation,
    /// and polls periodically if permission has not been granted yet.
    func startLiveDetection(onSuccess: (() -> Void)? = nil) {
        logPermissions()

        if installEventTap() {
            onSuccess?()
            return
        }

        logMessage("event tap creation failed on startup; polling for permission...")
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.installEventTap() {
                logMessage("event tap successfully installed on retry!")
                timer.invalidate()
                self.checkTimer = nil
                onSuccess?()
            }
        }
    }

    func stopLiveDetection() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}
