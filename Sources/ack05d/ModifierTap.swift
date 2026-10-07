import Foundation
import ApplicationServices

/// Owns the system event tap that merges modifiers held on the remote into input from
/// other devices (hold Shift on the remote, type on the Mac keyboard).
final class ModifierTap {
    /// Modifier flags currently held via the remote.
    var flagsProvider: (() -> CGEventFlags)?

    private var port: CFMachPort?

    private static let eventTypes: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged,
        .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .scrollWheel,
    ]

    var isInstalled: Bool { port != nil }

    /// Attempt to install the tap. Returns true if installed or already active.
    @discardableResult
    func install() -> Bool {
        guard port == nil else { return true }

        let mask = Self.eventTypes.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<ModifierTap>.fromOpaque(refcon).takeUnretainedValue()
                return tap.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        port = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log("event tap installed (cross-device modifiers active)")
        return true
    }

    /// The event is returned unretained: the tap callback does not own it.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if let flags = flagsProvider?(), !flags.isEmpty {
            event.flags.formUnion(flags)
        }
        return Unmanaged.passUnretained(event)
    }
}
