# macOS Permissions & Accessibility Guide

This document explains how macOS permissions work for `ack05d`, how cross-device modifier injection works, and how to resolve or permanently prevent permission issues across rebuilds.

---

## Background: Why `ack05d` Needs Permissions

`ack05d` needs special system privileges for actions that synthesize or modify inputs:
- **`keystroke`**: Synthesizing key chords (e.g. `cmd+=`, `shift+cmd+4`) or holding modifier keys (Shift, Option, Command, Control).
- **`mediaKey`**: Injecting native volume, brightness, or media playback HUD events.
- **Cross-device modifier injection**: When you hold a modifier on the ACK05 remote and type on your native MacBook keyboard, `ack05d` uses a system **Event Tap** (`CGEventTap`) to intercept physical keystrokes in flight and merge the held modifier (e.g. Shift + 1 = `!`).

Launching apps via `shell`, overlay alerts, and reading wheel rotation require no special permissions.

---

## macOS Settings Location

Depending on your macOS version:
- **macOS 13 – 15 (Ventura, Sonoma, Sequoia)**: **System Settings → Privacy & Security → Accessibility**.
- **macOS 27+ ("Golden Gate")**: **System Settings → Privacy & Security → Device Control and Data Access**.

In this list, **ACK05 Remote Community Driver** must be enabled (toggle switch ON).

---

## The "Stale Hash" Gotcha (Ad-Hoc Signing)

When you build `ack05d` using `./install.sh` without a persistent signing certificate:
1. The app is signed **ad-hoc** (`codesign -s -`).
2. macOS identifies ad-hoc signed apps strictly by their **cryptographic binary hash (`cdhash`)**.
3. Every time you recompile or update the code, a new binary with a **new hash** is generated.
4. **The Gotcha**: In System Settings, the toggle will still appear **ON** (because the bundle name matches), but macOS internally checks the binary hash at runtime. Because the hash changed, macOS silently revokes access, and `~/Library/Logs/ack05d.log` reports:
   ```text
   ack05d: permissions: axTrusted=false, listenAccess=false, postAccess=false
   ```

---

## Permanent Solution: Local Code-Signing Certificate (Recommended)

To make your permissions survive future rebuilds and updates without ever breaking:

1. In the terminal, run:
   ```sh
   ./make-signing-cert.sh
   ```
   *(It creates a local self-signed certificate named `ack05d-signing` and asks for your `sudo` password once to add it to your system keychain trust).*
2. Re-run `./install.sh`. `install.sh` automatically detects the certificate and signs with it.
3. Grant access in System Settings one final time.

From then on, macOS identifies the driver by certificate rather than binary hash. **Future rebuilds will never break your permissions again.**

---

## Quick Fix: Resetting Permissions if Keystrokes Stop Working

If you rebuild without a certificate and keystrokes or modifiers stop working:

1. Reset the cached permission for `ack05d`:
   ```sh
   tccutil reset All io.github.livenl.ack05d
   ```
2. Open **System Settings → Privacy & Security → Device Control and Data Access** (or **Accessibility**).
3. If **ACK05 Remote Community Driver** is still listed, remove it (click `-` or right-click to delete).
4. Click **`+`**, select `/Users/Vitalii/Applications/ACK05 Remote Community Driver.app`, and turn the toggle **ON**.

---

## Useful Diagnostic Commands

Test accessibility permissions directly (with live auto-detection polling if missing):
```sh
./.build/release/ack05d --check-accessibility
```

Check the live daemon logs:
```sh
tail -f ~/Library/Logs/ack05d.log
```
Healthy startup with permissions granted:
```text
ack05d: loaded config from ~/.config/ack05d/config.json
ack05d: successfully installed system event tap for cross-device modifiers!
ack05d: connected
ack05d: remote ready (NN%)
```

Restart the background daemon:
```sh
launchctl kickstart -k gui/$(id -u)/io.github.livenl.ack05d
```
