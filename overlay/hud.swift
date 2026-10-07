import AppKit

// hud — a single, reusable heads-up overlay.
//
//   hud "text" [options...]
//   hud "text" [seconds] [options...]
//
// Options:
//   --duration-ms <ms>     display duration in milliseconds (default 800)
//   --text-size <points>   font size in points (default 22)
//   --padding <points>     uniform padding around text (default 20)
//   --x-percent <0..100>   horizontal position % in visible area (default 50, centered)
//   --y-percent <0..100>   vertical position % in visible area (default 18)
//
// The first call starts a background server that owns ONE panel; every later call
// sends options to that server over a CFMessagePort.

let PORT_NAME = "io.github.livenl.hud" as CFString

struct HUDMessage: Codable {
    var text: String
    var durationMs: Double = 800
    var textSize: Double = 22
    var padding: Double = 20
    var xPercent: Double = 50
    var yPercent: Double = 18
}

func encode(_ message: HUDMessage) -> Data {
    (try? JSONEncoder().encode(message)) ?? Data()
}

func decode(_ data: Data) -> HUDMessage {
    if let msg = try? JSONDecoder().decode(HUDMessage.self, from: data) {
        return msg
    }
    // Fallback for legacy format: "\(seconds)\n\(text)"
    let s = String(data: data, encoding: .utf8) ?? ""
    let parts = s.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
    let seconds = Double(parts.first ?? "0.8") ?? 0.8
    let text = parts.count > 1 ? String(parts[1]) : ""
    return HUDMessage(text: text, durationMs: seconds * 1000)
}

// MARK: - Server (owns the single panel)

final class HUDServer {
    private let panel: NSPanel
    private let blur: NSVisualEffectView
    private let label: NSTextField
    private var fade: DispatchWorkItem?

    init() {
        label = NSTextField(labelWithString: "")
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.cell?.usesSingleLineMode = true

        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 64),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 64))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.masksToBounds = true
        blur.autoresizingMask = [.width, .height]

        blur.addSubview(label)
        panel.contentView = blur
    }

    func show(_ msg: HUDMessage) {
        let fontSize = CGFloat(max(10, msg.textSize))
        let pad = CGFloat(max(4, msg.padding))
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)

        label.font = font
        label.stringValue = msg.text

        // Target active screen under mouse pointer
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first else { return }
        let v = screen.visibleFrame // Excludes macOS Dock and menu bar regardless of dock position

        // Measure text size accurately using font attributes
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (msg.text as NSString).size(withAttributes: attributes)

        let lineH = ceil(font.ascender - font.descender + font.leading) + 4
        let naturalTextWidth = ceil(textSize.width) + 8

        // Maximum available panel bounds within visible frame
        let maxPanelWidth = max(100, v.width - 40)
        let maxPanelHeight = max(40, v.height - 40)

        let panelHeight = min(lineH + pad * 2, maxPanelHeight)
        let naturalPanelWidth = naturalTextWidth + pad * 2
        let minPanelWidth: CGFloat = 160
        let panelWidth = min(max(naturalPanelWidth, minPanelWidth), maxPanelWidth)

        // Ensure blur view fills the whole panel
        blur.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        // Update corner radius proportionally to panel height
        blur.layer?.cornerRadius = min(16, panelHeight / 2)

        // Frame label inside blur with uniform padding
        let labelWidth = max(10, panelWidth - pad * 2)
        label.frame = NSRect(x: pad, y: (panelHeight - lineH) / 2, width: labelWidth, height: lineH)

        // Percentage positioning: 0% = minX/minY, 100% = maxX/maxY (aligned against panel edges)
        let xPct = CGFloat(max(0, min(100, msg.xPercent))) / 100.0
        let yPct = CGFloat(max(0, min(100, msg.yPercent))) / 100.0

        let targetX = v.minX + (v.width - panelWidth) * xPct
        let targetY = v.minY + (v.height - panelHeight) * yPct

        // Strict clamp to NSScreen.visibleFrame so the panel NEVER overlaps the Dock or menu bar
        let clampedX = min(max(targetX, v.minX), max(v.minX, v.maxX - panelWidth))
        let clampedY = min(max(targetY, v.minY), max(v.minY, v.maxY - panelHeight))

        panel.setFrame(NSRect(x: clampedX, y: clampedY, width: panelWidth, height: panelHeight), display: true)

        if panel.alphaValue < 1 {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
        } else {
            panel.orderFrontRegardless()
        }

        // Reset auto-hide timer
        fade?.cancel()
        let work = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.18; self?.panel.animator().alphaValue = 0 },
                                                 completionHandler: { self?.panel.orderOut(nil) })
        }
        fade = work
        let durationSeconds = max(0.1, msg.durationMs / 1000.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds, execute: work)
    }
}

func runServer(initial: HUDMessage?) {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let server = HUDServer()

    let callback: CFMessagePortCallBack = { _, _, data, _ in
        if let data = data as Data? {
            let msg = decode(data)
            DispatchQueue.main.async { serverRef?.show(msg) }
        }
        return nil
    }
    serverRef = server
    guard let local = CFMessagePortCreateLocal(nil, PORT_NAME, callback, nil, nil) else {
        // another server already owns the name; just forward and exit
        if let initial = initial { _ = sendToServer(initial) }
        return
    }
    let src = CFMessagePortCreateRunLoopSource(nil, local, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
    if let initial = initial { server.show(initial) }
    app.run()
}

// A global the C callback can reach.
var serverRef: HUDServer?

// MARK: - Client

func sendToServer(_ message: HUDMessage) -> Bool {
    guard let remote = CFMessagePortCreateRemote(nil, PORT_NAME) else { return false }
    let data = encode(message) as CFData
    let result = CFMessagePortSendRequest(remote, 0, data, 1.0, 1.0, nil, nil)
    return result == kCFMessagePortSuccess
}

// MARK: - Entry

let rawArgs = CommandLine.arguments

if rawArgs.contains("--server") {
    runServer(initial: nil)
} else if rawArgs.count < 2 || rawArgs[1] == "-h" || rawArgs[1] == "--help" {
    FileHandle.standardError.write(Data("""
    usage: hud "text" [options...]
           hud "text" [seconds] [options...]

    Options:
      --duration-ms <ms>     display duration in milliseconds (default: 800)
      --text-size <points>   font size in points (default: 22)
      --padding <points>     uniform padding around text (default: 20)
      --x-percent <0..100>   horizontal position % in visible area (default: 50)
      --y-percent <0..100>   vertical position % in visible area (default: 18)

    Shows a transient on-screen overlay. Repeated calls refresh the same panel.
    A background server (hud --server) is started automatically on first use.

    """.utf8))
    exit(rawArgs.count < 2 ? 1 : 0)
} else {
    var text = ""
    var durationMs: Double?
    var textSize: Double?
    var padding: Double?
    var xPercent: Double?
    var yPercent: Double?

    var i = 1
    // First non-flag argument is text
    if i < rawArgs.count && !rawArgs[i].hasPrefix("--") {
        text = rawArgs[i]
        i += 1
    }

    // Optional second non-flag argument is duration in seconds (legacy positional)
    if i < rawArgs.count && !rawArgs[i].hasPrefix("--") {
        if let sec = Double(rawArgs[i]) {
            durationMs = sec * 1000.0
            i += 1
        }
    }

    while i < rawArgs.count {
        let arg = rawArgs[i]
        func nextVal() -> String? {
            if i + 1 < rawArgs.count {
                i += 1
                return rawArgs[i]
            }
            return nil
        }

        switch arg {
        case "--text":
            if let v = nextVal() { text = v }
        case "--duration-ms":
            if let v = nextVal(), let d = Double(v) { durationMs = d }
        case "--text-size":
            if let v = nextVal(), let s = Double(v) { textSize = s }
        case "--padding":
            if let v = nextVal(), let p = Double(v) { padding = p }
        case "--x-percent":
            if let v = nextVal(), let x = Double(v) { xPercent = x }
        case "--y-percent":
            if let v = nextVal(), let y = Double(v) { yPercent = y }
        default:
            break
        }
        i += 1
    }

    var message = HUDMessage(text: text)
    if let durationMs { message.durationMs = durationMs }
    if let textSize { message.textSize = textSize }
    if let padding { message.padding = padding }
    if let xPercent { message.xPercent = xPercent }
    if let yPercent { message.yPercent = yPercent }

    if sendToServer(message) {
        // delivered to running server
    } else {
        // launch background server and forward
        let p = Process()
        p.executableURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0])
        p.arguments = ["--server"]
        try? p.run()
        usleep(350_000)
        _ = sendToServer(message)
    }
}
