## About the Project

ack05d is a userspace macOS driver (Swift, SwiftPM, no dependencies) for the XPPen ACK05 shortcut remote over Bluetooth LE.

### Layout
- `Sources/ack05d/main.swift` — entry point only; `Daemon.swift` wires transport, decoder, runner, config hot-reload and the event tap.
- `Transport.swift` (CoreBluetooth) → `FrameDecoder.swift` (frames → press/release/wheel/battery events) → `ActionRunner.swift` (config actions; holds keystrokes while a button is down).
- `KeyStroke.swift` (spec parser + CGEvent posting), `MediaKey.swift`, `ModifierTap.swift` (event tap merging remote-held modifiers into other input), `LiveDetection.swift` (polls permissions until event tap is granted), `Log.swift` (single logging path).
- `overlay/hud.swift` is a separate standalone helper, not part of the package.

### Build and test
- `swift build -c release`
- `swift test` — needs full Xcode (XCTest). With only Command Line Tools: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.
- `./install.sh` builds, signs, installs the login agent.

### Gotchas
- Always release held keys (`ActionRunner.resetAllHeld()`) and reset `FrameDecoder` when the link drops, reconnects, config reloads, or the process exits.
- Ad-hoc signed rebuilds invalidate the Accessibility grant; see `docs/PERMISSIONS.md`.
- Log through `log(_:)`; don't write to stderr directly.
