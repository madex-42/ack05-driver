import Foundation
import ApplicationServices

/// Polls for macOS permissions and installs the event tap once granted,
/// allowing permissions granted after launch to take effect without restarting.
final class LiveDetection {
    private let tap: ModifierTap
    private var pollTimer: Timer?

    init(tap: ModifierTap) {
        self.tap = tap
    }

    /// Log the permission state; the most useful single line for bug reports.
    static func logPermissions() {
        log("permissions: axTrusted=\(AXIsProcessTrusted()), listenAccess=\(CGPreflightListenEventAccess()), postAccess=\(CGPreflightPostEventAccess())")
    }

    func logPermissions() {
        Self.logPermissions()
    }

    /// Installs the tap now, or polls every 2 s until macOS permits it.
    func start(onSuccess: (() -> Void)? = nil) {
        logPermissions()
        if tap.install() {
            onSuccess?()
            return
        }
        log("event tap unavailable (permission missing?); polling until granted…")
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self, self.tap.install() else { return }
            timer.invalidate()
            self.pollTimer = nil
            onSuccess?()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

