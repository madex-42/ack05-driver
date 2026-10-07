# Design

## Context

See `proposal.md` for motivation.
Currently:
1. `Config.swift` contains `overlay: OverlayConfig?` supporting `command`, `textSize`, `padding`, `position`, and `durationMs`.
2. `overlay/hud.swift` creates an `NSPanel` with an `NSVisualEffectView` (`blur`). However, `blur` was previously initialized to a fixed 300x64 frame. When the panel width expands dynamically for longer strings, the inner blur container must resize to match `panel.contentView?.bounds` so text is not visually clipped at 300 points.

## Goals / Non-Goals

**Goals:**
- Provide a clean JSON configuration schema in `config.json` under an `overlay` object.
- Guarantee that positioning uses `NSScreen.visibleFrame` (which excludes the macOS Dock and menu bar regardless of Dock position, orientation, or size) and strictly clamp the panel boundaries so it never overlaps the Dock.
- Support wide and long label strings by dynamically sizing `NSPanel`, `NSVisualEffectView`, and `NSTextField` up to `visibleFrame.width - 40`.
- Update `ActionRunner.swift` to invoke `overlay.command` with the configured visual and timing parameters.

**Non-Goals:**
- Multi-line text wrapping (notifications remain concise, single-line with tail truncation if wider than full usable display width).
- Complex custom animations or CSS styles.

## Decisions

### Decision 1: Configuration Schema in `Config.swift`
We support `OverlayConfig` and `PositionConfig` structs:
```swift
struct Config: Decodable {
    var overlay: OverlayConfig?
    // ...
}

struct OverlayConfig: Decodable, Equatable {
    var command: String?
    var textSize: Double?
    var padding: Double?
    var position: PositionConfig?
    var durationMs: Double?

    struct PositionConfig: Decodable, Equatable {
        var x: Double? // 0-100 percentage
        var y: Double? // 0-100 percentage
    }
}
```

### Decision 2: Visual Effect View Auto-resizing and Frame Sync
In `HUDServer`:
- Configure `blur.autoresizingMask = [.width, .height]`.
- Explicitly set `blur.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)` inside `show()`.
- Set `panel.contentView = blur`.
- Compute `naturalTextWidth` using `(text as NSString).size(withAttributes: [.font: font])`.
- Allow `panelWidth` to grow up to `v.width - 40` (the full usable screen width minus a safe margin).

### Decision 3: Dock-Safe Clamping
In `HUDServer`:
- `v = screen.visibleFrame` natively excludes Dock and menu bar.
- `targetX = v.minX + (v.width - panelWidth) * (xPercent / 100.0)`
- `targetY = v.minY + (v.height - panelHeight) * (yPercent / 100.0)`
- `clampedX = min(max(targetX, v.minX), max(v.minX, v.maxX - panelWidth))`
- `clampedY = min(max(targetY, v.minY), max(v.minY, v.maxY - panelHeight))`

## Risks / Trade-offs

- **[Risk] Extremely long text exceeding screen width** → Tail truncation (`lineBreakMode = .byTruncatingTail`) takes effect only when the string exceeds `v.width - 40`, ensuring maximum readability on any display.
