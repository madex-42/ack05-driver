import Foundation
import CoreGraphics

/// Synthesises a key chord (e.g. "cmd+=", "shift+cmd+4") or modifier keys (e.g. "shift", "option")
/// as CGEvents. Needs the daemon to be Accessibility-trusted, same as MediaKey.
struct KeyStroke {
    enum Kind {
        case modifier(keys: [CGKeyCode])
        case key(code: CGKeyCode, flags: CGEventFlags)
    }

    let kind: Kind

    /// Parse "shift", "cmd", "cmd+=", "shift+cmd+4" style strings.
    /// Modifiers: cmd/command, opt/alt/option, ctrl/control, shift, capslock, fn (and right-side variants).
    /// If only modifiers are given, it represents modifier hold/release. If a regular key is included,
    /// it represents that key with the specified modifier chord.
    /// Returns nil on an unknown key.
    init?(_ spec: String) {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var rawTokens: [String]
        if trimmed == "+" {
            rawTokens = ["+"]
        } else {
            rawTokens = trimmed.split(separator: "+").map {
                $0.trimmingCharacters(in: .whitespaces).lowercased()
            }
            if trimmed.hasSuffix("+") && !trimmed.hasSuffix("++") {
                rawTokens.append("+")
            }
        }

        var modifierCodes: [CGKeyCode] = []
        var flags: CGEventFlags = []
        var keyToken: String?

        for t in rawTokens {
            if let mod = Self.modifierMap[t] {
                modifierCodes.append(mod.code)
                flags.insert(mod.flag)
            } else if keyToken == nil {
                keyToken = t
            } else {
                return nil
            }
        }

        if let token = keyToken {
            guard let code = Self.keyCodes[token] else { return nil }
            self.kind = .key(code: code, flags: flags)
        } else if !modifierCodes.isEmpty {
            self.kind = .modifier(keys: modifierCodes)
        } else {
            return nil
        }
    }

    func postDown() {
        let src = CGEventSource(stateID: .hidSystemState)
        switch kind {
        case .modifier(let keys):
            for key in keys {
                CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)?.post(tap: .cghidEventTap)
            }
        case .key(let code, let flags):
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true) else { return }
            down.flags.formUnion(flags)
            down.post(tap: .cghidEventTap)
        }
    }

    func postUp() {
        let src = CGEventSource(stateID: .hidSystemState)
        switch kind {
        case .modifier(let keys):
            for key in keys.reversed() {
                CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)?.post(tap: .cghidEventTap)
            }
        case .key(let code, let flags):
            guard let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) else { return }
            up.flags.formUnion(flags)
            up.post(tap: .cghidEventTap)
        }
    }

    func postTap() {
        postDown()
        postUp()
    }

    /// Backwards-compatible alias for instantaneous trigger (e.g. wheel ticks).
    func post() {
        postTap()
    }

    private static let modifierMap: [String: (code: CGKeyCode, flag: CGEventFlags)] = [
        "cmd": (55, .maskCommand),
        "command": (55, .maskCommand),
        "lcmd": (55, .maskCommand),
        "cmd_left": (55, .maskCommand),
        "rcmd": (54, .maskCommand),
        "cmd_right": (54, .maskCommand),

        "shift": (56, .maskShift),
        "lshift": (56, .maskShift),
        "shift_left": (56, .maskShift),
        "rshift": (60, .maskShift),
        "shift_right": (60, .maskShift),

        "opt": (58, .maskAlternate),
        "option": (58, .maskAlternate),
        "alt": (58, .maskAlternate),
        "lopt": (58, .maskAlternate),
        "option_left": (58, .maskAlternate),
        "alt_left": (58, .maskAlternate),
        "ropt": (61, .maskAlternate),
        "option_right": (61, .maskAlternate),
        "alt_right": (61, .maskAlternate),

        "ctrl": (59, .maskControl),
        "control": (59, .maskControl),
        "lctrl": (59, .maskControl),
        "control_left": (59, .maskControl),
        "rctrl": (62, .maskControl),
        "control_right": (62, .maskControl),

        "capslock": (57, .maskAlphaShift),
        "caps_lock": (57, .maskAlphaShift),
        "fn": (63, .maskSecondaryFn),
        "function": (63, .maskSecondaryFn),
    ]

    // ANSI virtual key codes (Carbon kVK_*).
    private static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "equal": 24,
        "9": 25, "7": 26, "-": 27, "minus": 27, "8": 28, "0": 29, "]": 30, "o": 31,
        "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "+": 24, "plus": 24,  // = key; combine with shift for a literal plus

        // Punctuation and symbols
        ".": 47, "period": 47, "dot": 47,
        ",": 43, "comma": 43,
        "/": 44, "slash": 44,
        "\\": 42, "backslash": 42,
        ";": 41, "semicolon": 41,
        "'": 39, "quote": 39,
        "`": 50, "grave": 50, "backquote": 50,

        // Navigation and editing
        "pageup": 116, "pagedown": 121, "home": 115, "end": 119,
        "forwarddelete": 117,

        // Function keys
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    ]

    static func flagForModifierKey(_ code: CGKeyCode) -> CGEventFlags? {
        switch code {
        case 56, 60: return .maskShift
        case 55, 54: return .maskCommand
        case 58, 61: return .maskAlternate
        case 59, 62: return .maskControl
        case 57: return .maskAlphaShift
        case 63: return .maskSecondaryFn
        default: return nil
        }
    }
}
