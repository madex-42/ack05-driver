import Foundation
import ApplicationServices

/// Executes configured actions and owns the wheel-mode cursor. All shell work is
/// detached and non-blocking so a slow command never stalls the BLE run loop.
final class ActionRunner {
    private let config: Config
    private let debug: Bool
    private var wheelIndex = 0
    private var activeKeyStrokes: [Button: KeyStroke] = [:]

    /// Supplies the current battery level for the `battery` action (set by main from
    /// the transport). Returns nil until a heartbeat has been seen.
    var batteryProvider: (() -> Int?)?
    var onLog: ((String) -> Void)?

    init(config: Config, debug: Bool = false) {
        self.config = config
        self.debug = debug
    }

    var currentWheelMode: Config.WheelMode? {
        config.wheelModes.isEmpty ? nil : config.wheelModes[wheelIndex]
    }

    func handlePress(_ button: Button) {
        guard let action = config.buttons[button.rawValue] else { return }
        // Clean up any stale unreleased press for this button before starting a new one
        if let previous = activeKeyStrokes.removeValue(forKey: button) {
            previous.postUp()
        }
        runButton(action, button: button, defaultLabel: button.rawValue)
    }

    func handleRelease(_ button: Button) {
        if let ks = activeKeyStrokes.removeValue(forKey: button) {
            if debug { logMessage("posting up for \(button.rawValue)") }
            ks.postUp()
        }
    }

    func handleWheel(_ direction: WheelDirection) {
        guard let mode = currentWheelMode else { return }
        runWheel(direction == .cw ? mode.cw : mode.ccw, defaultLabel: mode.name)
    }

    /// Releases any held keys or modifiers (called on disconnect, reconnect, or reload).
    func resetAllHeld() {
        for (_, ks) in activeKeyStrokes {
            ks.postUp()
        }
        activeKeyStrokes.removeAll()
    }

    /// Combined modifier flags of all currently held buttons.
    var currentModifierFlags: CGEventFlags {
        var flags: CGEventFlags = []
        for (_, ks) in activeKeyStrokes {
            if case .modifier(let keys) = ks.kind {
                for key in keys {
                    if let f = KeyStroke.flagForModifierKey(key) {
                        flags.insert(f)
                    }
                }
            }
        }
        return flags
    }

    /// Show a standalone overlay message (connection status, etc.).
    func announce(_ label: String, _ seconds: Double = 0.8) {
        overlay(label, seconds)
    }

    private func runButton(_ action: Config.Action, button: Button, defaultLabel: String) {
        switch action.type {
        case .none:
            break
        case .shell:
            if let cmd = action.command { shell(cmd) }
            if action.silent != true { overlay(action.label ?? defaultLabel) }
        case .mediaKey:
            if let name = action.key {
                if let mk = MediaKey(rawValue: name) { mk.post() }
                else { warn("unknown mediaKey \"\(name)\" — see README for valid keys") }
            }
            if let label = action.label { overlay(label) }
        case .keystroke:
            if let spec = action.keystroke {
                if let ks = KeyStroke(spec) {
                    ks.postDown()
                    activeKeyStrokes[button] = ks
                    if debug { logMessage("held \(button.rawValue) (\(spec)), activeModifiers=\(currentModifierFlags.rawValue)") }
                } else {
                    warn("unknown keystroke \"\(spec)\" — unsupported key name")
                }
            }
            if let label = action.label { overlay(label) }
        case .battery:
            let name = action.label ?? "battery"
            if let pct = batteryProvider?() { overlay("\(name)  ·  \(pct)%", 1.5) }
            else { overlay("\(name): unknown", 1.5) }
        case .wheelModeCycle:
            guard !config.wheelModes.isEmpty else { return }
            wheelIndex = (wheelIndex + 1) % config.wheelModes.count
            overlay(action.label ?? "wheel: \(config.wheelModes[wheelIndex].name)")
        }
    }

    private func runWheel(_ action: Config.Action, defaultLabel: String) {
        switch action.type {
        case .none:
            break
        case .shell:
            if let cmd = action.command { shell(cmd) }
            if action.silent != true { overlay(action.label ?? defaultLabel) }
        case .mediaKey:
            if let name = action.key {
                if let mk = MediaKey(rawValue: name) { mk.post() }
                else { warn("unknown mediaKey \"\(name)\" — see README for valid keys") }
            }
            if let label = action.label { overlay(label) }
        case .keystroke:
            if let spec = action.keystroke {
                if let ks = KeyStroke(spec) {
                    ks.postTap()
                } else {
                    warn("unknown keystroke \"\(spec)\" — unsupported key name")
                }
            }
            if let label = action.label { overlay(label) }
        case .battery:
            let name = action.label ?? "battery"
            if let pct = batteryProvider?() { overlay("\(name)  ·  \(pct)%", 1.5) }
            else { overlay("\(name): unknown", 1.5) }
        case .wheelModeCycle:
            guard !config.wheelModes.isEmpty else { return }
            wheelIndex = (wheelIndex + 1) % config.wheelModes.count
            overlay(action.label ?? "wheel: \(config.wheelModes[wheelIndex].name)")
        }
    }

    private func overlay(_ label: String, _ seconds: Double = 0.8) {
        guard let cmd = config.overlayCommand else { return }
        shell("\(cmd) \(shellQuote(label)) \(seconds)")
    }

    private func logMessage(_ s: String) {
        if let onLog = onLog {
            onLog(s)
        } else {
            warn(s)
        }
    }

    private func warn(_ s: String) {
        FileHandle.standardError.write(Data("ack05d: \(s)\n".utf8))
    }

    private func shell(_ command: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", command]
        do { try p.run() } catch { FileHandle.standardError.write(Data("ack05d: run failed: \(error)\n".utf8)) }
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
