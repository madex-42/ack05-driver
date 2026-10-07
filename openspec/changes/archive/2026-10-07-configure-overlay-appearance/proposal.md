# Proposal

## Why

Currently, `ack05d` provides optional HUD feedback by invoking an external command (`hud`), but the overlay appearance, duration, positioning, and container sizing had fixed limits inside `overlay/hud.swift` (hardcoded dimensions, fixed placement, and visual effect views clipping long labels). Users cannot customize text size, padding around the text, display duration, or overlay placement across displays, and long labels were prematurely truncated. Furthermore, when the macOS Dock or menu bar changes size or position, the overlay positioning should strictly respect the usable screen area (excluding Dock and main menu, regardless of Dock position) and must not overlay the Dock regardless of its size and position.

Configuring these visual options directly under an `overlay` section in `config.json` and allowing the overlay container to dynamically expand for long labels gives users precise control over overlay presentation while keeping the remote responsive and readable.

## What Changes

- Add a structured `overlay` configuration object in `config.json`:
  ```json
  {
    "overlay": {
      "command": "~/.local/bin/hud",
      "textSize": 22,
      "padding": 20,
      "position": { "x": 50, "y": 18 },
      "durationMs": 800
    }
  }
  ```
  - `command`: Path to overlay command (e.g. `~/.local/bin/hud`).
  - `textSize`: Font size for label text in points.
  - `padding`: Uniform margin around the text (applied to both vertical and horizontal padding).
  - `position`: Object with `x` and `y` percentages (0–100) relative to usable screen area (excluding Dock and main menu).
  - `durationMs`: Duration to display the overlay in milliseconds.
- Update `ack05d` driver:
  - Add `OverlayConfig` to `Sources/ack05d/Config.swift`.
  - Update `ActionRunner.swift` to invoke `overlay.command` with configured parameters (`textSize`, `padding`, `x`, `y`, `durationMs`).
- Update `overlay/hud.swift`:
  - Support command-line arguments and IPC message payloads specifying text size, padding, position percentages, and duration in milliseconds.
  - Calculate dynamic panel and container dimensions fitting the label with uniform padding, properly expanding the visual effect view so long labels are not prematurely clipped or truncated.
  - Compute overlay coordinates strictly within `NSScreen.visibleFrame` (excluding Dock and main menu), clamping the panel to guarantee it never overlaps the Dock regardless of Dock position (bottom, left, right) and size.

## Capabilities

### New Capabilities
- `overlay-configuration`: Configuration and rendering controls for the HUD overlay, including text typography, content padding, display duration, dynamic panel expansion for long labels, and position percentages bounded by the display's usable frame.

### Modified Capabilities
<!-- None: Initial capability in project specs. -->

## Impact

- `Sources/ack05d/Config.swift`: Schema updated with `overlay` object definition.
- `Sources/ack05d/ActionRunner.swift`: Overlay invocation passing configured parameters to the overlay command.
- `overlay/hud.swift`: CLI parsing, IPC communication, dynamic panel and container sizing for long labels, and boundary-clamped positioning relative to `visibleFrame`.
- Documentation (`README.md`, `config.example.json`, `docs/CONFIGURATION.md`).
