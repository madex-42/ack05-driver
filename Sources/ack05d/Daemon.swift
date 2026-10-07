import Foundation
import ApplicationServices

/// Command-line / environment options.
struct Options {
    let identify: Bool
    let checkAccessibility: Bool
    let debug: Bool
    let configURL: URL
    /// Optional shell command used in identify mode to show each event name on screen.
    let identifyOverlay: String?

    init(arguments: [String], environment: [String: String]) {
        identify = arguments.contains("--identify")
        checkAccessibility = arguments.contains("--check-accessibility")
        debug = arguments.contains("--debug") || environment["ACK05D_DEBUG"] != nil
        identifyOverlay = environment["ACK05D_IDENTIFY_OVERLAY"]
        if let i = arguments.firstIndex(of: "--config"), i + 1 < arguments.count {
            configURL = URL(fileURLWithPath: arguments[i + 1])
        } else {
            configURL = Config.defaultURL
        }
    }
}

/// Wires the transport, decoder, action runner, config hot-reload and event tap together.
final class Daemon {
    private let options: Options
    private let transport = Transport()
    private let modifierTap = ModifierTap()
    private let liveDetection: LiveDetection
    private var decoder = FrameDecoder()
    private var runner: ActionRunner?
    private var lastLoggedBattery: Int?

    private var connectingLabel = "ACK05 connecting…"
    private var connectedLabel = "ACK05 ready"
    private var disconnectedLabel = ""
    private var quietReconnectSeconds: Double = 180
    /// Last moment the remote was in contact (ready or dropped). A reconnect within
    /// quietReconnectSeconds of this is range-flapping, not a fresh session: no overlays.
    private var lastContact: Date?

    private var signalSources: [DispatchSourceSignal] = []
    private var configTimer: Timer?

    init(options: Options) {
        self.options = options
        self.liveDetection = LiveDetection(tap: modifierTap)
    }

    func run() -> Never {
        installSignalHandlers()
        modifierTap.flagsProvider = { [weak self] in self?.runner?.currentModifierFlags ?? [] }

        if options.checkAccessibility {
            liveDetection.start {
                log("accessibility check passed.")
                exit(0)
            }
            RunLoop.main.run()
            exit(0)
        }

        if options.identify {
            log("identify mode — press buttons; nothing is executed")
            liveDetection.logPermissions()
        } else {
            loadConfig()
            startConfigWatcher()
            liveDetection.start()
        }

        wireTransport()
        transport.start()
        RunLoop.main.run()
        exit(0)
    }

    // MARK: - Lifecycle

    /// Guarantee no modifier key is left held on exit.
    private func installSignalHandlers() {
        for sig in [SIGINT, SIGTERM] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                self?.runner?.resetAllHeld()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: - Config

    private func loadConfig() {
        do {
            let config = try Config.load(from: options.configURL)
            let r = ActionRunner(config: config, debug: options.debug)
            r.batteryProvider = { [weak self] in self?.transport.currentBattery }
            runner?.resetAllHeld()
            runner = r
            connectingLabel = config.connectingLabel ?? "ACK05 connecting…"
            connectedLabel = config.connectedLabel ?? "ACK05 ready"
            disconnectedLabel = config.disconnectedLabel ?? ""
            quietReconnectSeconds = config.quietReconnectSeconds ?? 180
            log("loaded config from \(options.configURL.path)")
        } catch {
            if runner == nil {
                log("could not load config (\(error)). Running in identify mode instead.")
            } else {
                log("config reload failed (\(error)); keeping the previous config")
            }
        }
    }

    /// Watch the config's mtime and hot-reload on change, so edits apply without a restart.
    private func startConfigWatcher() {
        let path = options.configURL.path
        func mtime() -> Date? {
            try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
        }
        var last = mtime()
        configTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            let now = mtime()
            if let now, now != last {
                last = now
                log("config changed, reloading")
                self?.loadConfig()
            }
        }
    }

    // MARK: - Transport

    private func quietReconnect() -> Bool {
        guard let t = lastContact else { return false }
        return Date().timeIntervalSince(t) < quietReconnectSeconds
    }

    /// Forget held buttons both in the runner (release keys) and the decoder (so the first
    /// press after a reconnect is seen as a press, not as an already-held button).
    private func resetInputState() {
        runner?.resetAllHeld()
        decoder = FrameDecoder()
    }

    private func wireTransport() {
        let identifyMode = options.identify
        transport.onStatus = { log($0) }
        transport.onConnecting = { [weak self] in
            // Long duration so it stays up during the handshake; onReady replaces it.
            guard let self, !identifyMode, !self.connectingLabel.isEmpty, !self.quietReconnect() else { return }
            self.runner?.announce(self.connectingLabel, 12)
        }
        transport.onReady = { [weak self] battery in
            guard let self else { return }
            self.resetInputState()
            let quiet = self.quietReconnect()
            log("remote ready\(battery.map { " (\($0)%)" } ?? "")\(quiet ? " (quiet reconnect, no overlay)" : "")")
            self.lastContact = Date()
            guard !identifyMode, !self.connectedLabel.isEmpty, !quiet else { return }
            let suffix = battery.map { "  ·  \($0)%" } ?? ""
            self.runner?.announce(self.connectedLabel + suffix, 1.5)
        }
        transport.onLost = { [weak self] in
            guard let self else { return }
            self.resetInputState()
            let quiet = self.quietReconnect()
            self.lastContact = Date()
            if !identifyMode, !self.disconnectedLabel.isEmpty, !quiet { self.runner?.announce(self.disconnectedLabel) }
        }
        transport.onFrame = { [weak self] data in
            self?.handleFrame(data)
        }
    }

    private func handleFrame(_ data: Data) {
        for event in decoder.decode(data) {
            switch event {
            case .press(let button):
                if options.identify || runner == nil {
                    log("PRESS \(button.rawValue)")
                    showIdentify(button.rawValue)
                } else {
                    if options.debug { log("PRESS \(button.rawValue)") }
                    runner?.handlePress(button)
                }
            case .release(let button):
                if options.debug { log("RELEASE \(button.rawValue)") }
                if !options.identify { runner?.handleRelease(button) }
            case .wheel(let direction):
                if options.identify || runner == nil {
                    log(direction.rawValue)
                    showIdentify(direction.rawValue)
                } else {
                    if options.debug { log("wheel \(direction.rawValue) mode=\(runner?.currentWheelMode?.name ?? "-")") }
                    runner?.handleWheel(direction)
                }
            case .battery(let percent, let charging):
                // Heartbeats arrive every ~15s; only log when the level actually changes
                // (or under --debug) so the log doesn't grow by hundreds of KB a day.
                if options.debug || percent != lastLoggedBattery {
                    lastLoggedBattery = percent
                    log("battery \(percent)%\(charging ? " (charging)" : "")")
                }
            case .reconnect:
                resetInputState()
                log("device reconnect")
            }
        }
    }

    /// In identify mode, surface the pressed button's name on screen too, so it can be
    /// mapped to a physical key without watching stderr. Best-effort; silent if absent.
    private func showIdentify(_ label: String) {
        guard let cmd = options.identifyOverlay else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "\(cmd) '\(label)' 1.2"]
        try? p.run()
    }
}
