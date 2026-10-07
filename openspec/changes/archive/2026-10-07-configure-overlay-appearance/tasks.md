# Tasks

## 1. Config Model and ActionRunner Updates

- [x] 1.1 Add `OverlayConfig` and `PositionConfig` structs to `Sources/ack05d/Config.swift` with properties for `command`, `textSize`, uniform `padding`, `position: { x, y }`, and `durationMs`.
- [x] 1.2 Update `ActionRunner.swift` overlay execution to read from `config.overlay` and pass formatted arguments (`--duration-ms`, `--text-size`, `--padding`, `--x-percent`, `--y-percent`) to the configured overlay command.
- [x] 1.3 Add unit tests in `Tests/ack05dTests/` verifying decoding of the `overlay` object configuration with custom values and default fallbacks.

## 2. Overlay Helper CLI and IPC Updates

- [x] 2.1 Update `overlay/hud.swift` argument parsing to support `--text-size`, `--padding`, `--duration-ms`, `--x-percent`, and `--y-percent`.
- [x] 2.2 Update `overlay/hud.swift` client-server IPC encoding and decoding to transmit a structured JSON payload containing text, `durationMs`, `textSize`, uniform `padding`, `xPercent`, and `yPercent`.

## 3. Dynamic Sizing and Dock-Safe Screen Positioning

- [x] 3.1 Update `HUDServer` in `overlay/hud.swift` to dynamically compute panel and label dimensions from font metrics and uniform padding.
- [x] 3.2 Implement position calculation using `NSScreen.visibleFrame` with percentage coordinates and strict boundary clamping, ensuring the panel is completely contained within `visibleFrame` without intersecting the Dock or menu bar.
- [x] 3.3 Fix `NSVisualEffectView` bounds and autoresizing in `HUDServer` so that long labels expand up to usable screen width without truncation or clipping.
- [x] 3.4 Verify manual invocation of `hud` with long strings and different position percentages confirming wide rendering and no overlap with the Dock.

## 4. Documentation and Build Verification

- [x] 4.1 Update `config.example.json` and `README.md` to show the new `overlay` configuration schema and document all available options.
- [x] 4.2 Verify project builds with `swift build -c release` and tests pass.
