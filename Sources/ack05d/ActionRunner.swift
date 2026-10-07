import Foundation
import ApplicationServices

/// Executes configured actions and owns the wheel-mode cursor. All shell work is
/// detached and non-blocking so a slow command never stalls the BLE run loop.
final class ActionRunner {
    private let config: Config
    private let debug: Bool
    private var wheelIndex = 0
    private var activeKeyStrokes: [Button: KeyStroke] = [:]
    private var warned: Set<String> = []

    /// Supplies the current battery level for the `battery` action (set by main from
    /// the transport). Returns nil until a heartbeat has been seen.
    var batteryProvider: (() -> Int?)?

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
        run(action, defaultLabel: button.rawValue, holdFor: button)
    }

    func handleRelease(_ button: Button) {
        if let ks = activeKeyStrokes.removeValue(forKey: button) {
            if debug { log("posting up for \(button.rawValue)") }
            ks.postUp()
        }
    }

    func handleWheel(_ direction: WheelDirection) {
        guard let mode = currentWheelMode else { return }
        run(direction == .cw ? mode.cw : mode.ccw, defaultLabel: mode.name, holdFor: nil)
    }

    /// Releases any held keys or modifiers (called on disconnect, reconnect, or reload).
    func resetAllHeld() {
        // Clear first so the event tap no longer decorates the key-up events.
        let held = activeKeyStrokes
        activeKeyStrokes.removeAll()
        for (_, ks) in held { ks.postUp() }
    }

    /// Combined modifier flags of all currently held buttons.
    var currentModifierFlags: CGEventFlags {
        activeKeyStrokes.values.reduce(into: CGEventFlags()) { $0.formUnion($1.heldFlags) }
    }

    /// Show a standalone overlay message (connection status, etc.).
    func announce(_ label: String, _ seconds: Double = 0.8) {
        overlay(label, seconds)
    }

    /// `holdFor` is the physical button for button actions (keystrokes stay down until it is
    /// released) and nil for wheel ticks (keystrokes are tapped).
    private func run(_ action: Config.Action, defaultLabel: String, holdFor button: Button?) {
        switch action.type {
        case .none:
            break
        case .shell:
            if let cmd = action.command { shell(cmd) }
            if action.silent != true { overlay(action.label ?? defaultLabel) }
        case .mediaKey:
            if let name = action.key {
                if let mk = MediaKey(rawValue: name) { mk.post() }
                else { warnOnce("unknown mediaKey \"\(name)\" — see README for valid keys") }
            }
            if let label = action.label { overlay(label) }
        case .keystroke:
            if let spec = action.keystroke {
                if let ks = KeyStroke(spec) {
                    if let button {
                        ks.postDown()
                        activeKeyStrokes[button] = ks
                        if debug { log("held \(button.rawValue) (\(spec)), activeModifiers=\(currentModifierFlags.rawValue)") }
                    } else if ks.isModifierOnly {
                        warnOnce("keystroke \"\(spec)\" is modifier-only and has no effect on a wheel tick")
                    } else {
                        ks.postTap()
                    }
                } else {
                    warnOnce("unknown keystroke \"\(spec)\" — unsupported key name")
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

    private func overlay(_ label: String, _ seconds: Double? = nil) {
        guard let cmd = config.overlay?.command, !cmd.isEmpty else { return }

        var args: [String] = [shellQuote(label)]
        if let s = seconds {
            args.append("--duration-ms \(Int(s * 1000))")
        } else if let ms = config.overlay?.durationMs {
            args.append("--duration-ms \(Int(ms))")
        }
        if let size = config.overlay?.textSize {
            args.append("--text-size \(size)")
        }
        if let pad = config.overlay?.padding {
            args.append("--padding \(pad)")
        }
        if let x = config.overlay?.position?.x {
            args.append("--x-percent \(x)")
        }
        if let y = config.overlay?.position?.y {
            args.append("--y-percent \(y)")
        }

        shell("\(cmd) \(args.joined(separator: " "))")
    }

    /// Config mistakes repeat on every press or wheel tick; report each once per config load.
    private func warnOnce(_ s: String) {
        if warned.insert(s).inserted { log(s) }
    }

    private func shell(_ command: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", command]
        do { try p.run() } catch { log("run failed: \(error)") }
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
