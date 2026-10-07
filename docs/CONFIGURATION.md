# Configuration Reference

`ack05d` reads its configuration from `$XDG_CONFIG_HOME/ack05d/config.json` or `~/.config/ack05d/config.json`. The daemon hot-reloads the file automatically within ~1.5s whenever changes are saved.

---

## Complete Example (`config.json`)

Here is an example containing every supported configuration property:

```json
{
  "overlay": {
    "command": "~/.local/bin/hud",
    "textSize": 22,
    "padding": 20,
    "position": {
      "x": 50,
      "y": 18
    },
    "durationMs": 800
  },
  "connectingLabel": "ACK05 connecting…",
  "connectedLabel": "ACK05 ready",
  "disconnectedLabel": "ACK05 disconnected",
  "quietReconnectSeconds": 180,
  "buttons": {
    "BTN_1": {
      "type": "shell",
      "command": "open -a Safari",
      "label": "Safari"
    },
    "BTN_2": {
      "type": "shell",
      "command": "open -a Notes",
      "label": "Notes",
      "silent": false
    },
    "BTN_3": {
      "type": "keystroke",
      "keystroke": "shift+cmd+4",
      "label": "Screenshot"
    },
    "BTN_4": {
      "type": "keystroke",
      "keystroke": "shift",
      "label": "Shift"
    },
    "BTN_5": {
      "type": "mediaKey",
      "key": "play_pause",
      "label": "Play/Pause"
    },
    "BTN_6": {
      "type": "mediaKey",
      "key": "mute",
      "label": "Mute"
    },
    "BTN_7": {
      "type": "battery",
      "label": "Remote Battery"
    },
    "BTN_8": {
      "type": "shell",
      "command": "/usr/local/bin/my-custom-toggle",
      "silent": true
    },
    "BTN_9": {
      "type": "none"
    },
    "BTN_10": {
      "type": "keystroke",
      "keystroke": "cmd+c",
      "label": "Copy"
    },
    "DIAL": {
      "type": "wheelModeCycle",
      "label": "Next Wheel Mode"
    }
  },
  "wheelModes": [
    {
      "name": "volume",
      "cw": {
        "type": "mediaKey",
        "key": "volume_up"
      },
      "ccw": {
        "type": "mediaKey",
        "key": "volume_down"
      }
    },
    {
      "name": "brightness",
      "cw": {
        "type": "mediaKey",
        "key": "brightness_up"
      },
      "ccw": {
        "type": "mediaKey",
        "key": "brightness_down"
      }
    },
    {
      "name": "zoom",
      "cw": {
        "type": "keystroke",
        "keystroke": "cmd+="
      },
      "ccw": {
        "type": "keystroke",
        "keystroke": "cmd+-"
      }
    },
    {
      "name": "track_scrub",
      "cw": {
        "type": "mediaKey",
        "key": "next"
      },
      "ccw": {
        "type": "mediaKey",
        "key": "previous"
      }
    }
  ]
}
```

---

## Top-Level Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `overlay` | Object | `null` | Structured configuration for HUD notifications (see below). |
| `connectingLabel` | String | `"ACK05 connecting…"` | Text flashed in overlay while Bluetooth connection/handshake is running. Set to `""` to suppress. |
| `connectedLabel` | String | `"ACK05 ready"` | Text flashed in overlay (along with battery level) once the remote is ready. Set to `""` to suppress. |
| `disconnectedLabel` | String | `""` (silent) | Text flashed when connection drops. Set to `""` to suppress. |
| `quietReconnectSeconds` | Number | `180` | Suppresses connecting/ready/disconnected overlays if remote disconnected less than this many seconds ago (prevents spam at range boundaries). |
| `buttons` | Object | `{}` | Map of button name (`BTN_1`–`BTN_10`, `DIAL`) to an `Action` object. |
| `wheelModes` | Array | `[]` | List of `WheelMode` objects cycled by `wheelModeCycle`. |

---

## `overlay` Object Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `command` | String | `null` | Executable path for overlay renderer (e.g. `~/.local/bin/hud`). |
| `textSize` | Number | `22` | Font size of overlay label in points. |
| `padding` | Number | `20` | Uniform padding (in points) around text (applied equally to top, bottom, left, and right). |
| `position` | Object | `{ "x": 50, "y": 18 }` | Placement coordinates as percentages (0–100) relative to usable screen area (`visibleFrame`). Excludes menu bar and Dock regardless of Dock position, orientation, and size. |
| `position.x` | Number | `50` | Horizontal percentage (0 = left, 50 = center, 100 = right). |
| `position.y` | Number | `18` | Vertical percentage (0 = bottom, 100 = top). |
| `durationMs` | Number | `800` | How long the overlay remains visible in milliseconds before fading out. |

---

## Button Names

Run `ack05d --identify` to see which physical buttons correspond to these names on your device:
- `BTN_1` through `BTN_10`
- `DIAL` (the physical dial center button)

---

## Action Types and Fields

Each entry in `buttons` or in `wheelModes[n].cw` / `wheelModes[n].ccw` is an action:

| `type` | Description | Required Fields | Optional Fields |
|---|---|---|---|
| `shell` | Run a shell command via `/bin/sh -c` | `command` (e.g. `"open -a Safari"`) | `label`, `silent` |
| `keystroke` | Post a key chord or hold a modifier | `keystroke` (e.g. `"cmd+="`, `"shift"`) | `label`, `silent` |
| `mediaKey` | Post a macOS system media key | `key` (see below) | `label`, `silent` |
| `battery` | Show current remote battery percentage | — | `label` (defaults to `"battery"`) |
| `wheelModeCycle` | Advance to the next wheel mode | — | `label` (defaults to mode name) |
| `none` | Explicitly unbind button | — | — |

### Action Common Fields:
- `label`: Label text displayed in overlay.
- `silent`: Set `true` to suppress the daemon's HUD overlay (e.g., when the invoked shell script or media key handles its own UI).

### Supported `mediaKey` values:
- `volume_up`
- `volume_down`
- `mute`
- `brightness_up`
- `brightness_down`
- `play_pause`
- `next`
- `previous`

### Keystroke Specification Syntax:
- **Modifiers**: `cmd`, `opt` / `alt`, `shift`, `ctrl` (and right variants `rcmd`, `ropt`, `rshift`, `rctrl`).
- **Chords**: `+` separated, e.g. `cmd+c`, `shift+cmd+4`, `cmd+=`, `cmd++`.
- **Special keys**: `space`, `return`, `tab`, `escape`, `delete`, `up`, `down`, `left`, `right`, `f1`–`f12`, `home`, `end`, `pageup`, `pagedown`, etc.

