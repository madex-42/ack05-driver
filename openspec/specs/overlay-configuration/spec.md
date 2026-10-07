# overlay-configuration Specification

## Purpose

Enables customized visual appearance, display duration, dynamic panel expansion for long labels, and bounded screen placement for on-screen HUD notifications triggered by driver actions and status events.

## Requirements

### Requirement: Configurable overlay command and appearance
The driver configuration SHALL support an `overlay` object defining the command executable, typography, padding, duration, and screen position.

#### Scenario: Full overlay configuration provided
- **WHEN** user provides an `overlay` object with command, textSize, padding, position, and durationMs in configuration
- **THEN** the driver decodes and utilizes all specified overlay properties for notifications

#### Scenario: Partial overlay properties provided
- **WHEN** user provides an `overlay` object with only some properties specified
- **THEN** missing properties take documented default values

### Requirement: Configurable overlay text size
The configuration SHALL allow specifying `textSize` for the on-screen overlay. When configured, the overlay renderer SHALL display the notification text using the specified font size in points.

#### Scenario: Custom text size configured
- **WHEN** user configures `textSize` in the overlay configuration
- **THEN** the overlay renders label text using the specified font size in points

#### Scenario: Default text size when omitted
- **WHEN** the overlay configuration omits `textSize`
- **THEN** the overlay renders label text using the default font size (22pt)

### Requirement: Configurable uniform overlay padding
The configuration SHALL allow specifying a single `padding` value representing the margin around the label text. The overlay panel SHALL apply this padding value equally to both horizontal and vertical edges around the text.

#### Scenario: Custom padding specified
- **WHEN** user configures `padding` in the overlay configuration
- **THEN** the overlay panel reserves the specified padding space equally along top, bottom, leading, and trailing edges of the text

#### Scenario: Default padding when omitted
- **WHEN** the overlay configuration omits `padding`
- **THEN** the overlay applies standard default padding (e.g. 20pt) around the text

### Requirement: Dynamic panel sizing and unclipped long labels
The overlay panel and background visual effect container SHALL dynamically expand to accommodate long labels up to the usable screen width boundary without premature clipping or fixed-width truncations.

#### Scenario: Long text label displayed
- **WHEN** a label exceeding 300 points in width is passed to the overlay
- **THEN** the panel and its visual effect view resize proportionally to display the full label text without truncation up to the screen's usable frame

#### Scenario: Label exceeds screen width
- **WHEN** a label is wider than the usable screen width
- **THEN** the overlay panel expands to the maximum usable width and truncates the tail gracefully

### Requirement: Configurable overlay display duration
The configuration SHALL allow specifying `durationMs` defining the overlay display time in milliseconds before fading out.

#### Scenario: Custom duration configured
- **WHEN** user specifies `durationMs` in milliseconds
- **THEN** the overlay remains fully visible for the specified duration before fading out

#### Scenario: Default duration when omitted
- **WHEN** the overlay configuration omits `durationMs`
- **THEN** the overlay uses the default duration of 800 milliseconds

### Requirement: Configurable percentage-based screen positioning
The configuration SHALL allow specifying the on-screen overlay position via a `position` object containing `x` and `y` percentages (0 to 100) relative to the screen's usable area (excluding Dock and main menu).

#### Scenario: Custom percentage coordinates
- **WHEN** user specifies `position: { "x": 50, "y": 18 }`
- **THEN** the overlay centers horizontally at 50% and vertically at 18% of the usable screen frame

#### Scenario: Default position when omitted
- **WHEN** `position` is omitted from configuration
- **THEN** the overlay defaults to horizontally centered (x: 50%) and 18% above the bottom of the usable screen area (y: 18%)

### Requirement: Strict avoidance of Dock and menu bar
The overlay positioning logic SHALL restrict panel coordinates to the display's usable frame (`visibleFrame`), excluding both the main menu bar and the Dock regardless of Dock size, screen edge (bottom, left, or right), or auto-hide state. The overlay panel SHALL be clamped such that no part of the panel extends outside the usable frame or covers the Dock.

#### Scenario: Dock positioned at bottom
- **WHEN** the user's macOS Dock is located at the bottom of the screen and position percentage is near the bottom
- **THEN** the overlay is placed strictly within the visible area above the top boundary of the Dock without intersecting it

#### Scenario: Dock positioned on left or right edge
- **WHEN** the user's macOS Dock is positioned on the left or right screen edge
- **THEN** the overlay horizontal coordinates are clamped within the remaining visible width and do not overlap the Dock

#### Scenario: Panel boundary clamping
- **WHEN** a chosen percentage position or large panel size would cause the panel to extend beyond the usable screen boundaries
- **THEN** the overlay panel frame is clamped entirely within the screen's visible frame

