import Foundation
import CoreGraphics

/// Synthesises a key chord (e.g. "cmd+=", "shift+cmd+4") or modifier keys (e.g. "shift", "option")
/// as CGEvents. Needs the daemon to be Accessibility-trusted, same as MediaKey.
struct KeyStroke {
    struct Modifier: Equatable {
        let code: CGKeyCode
        let flag: CGEventFlags
    }

    enum Kind {
        case modifier([Modifier])
        case key(code: CGKeyCode, flags: CGEventFlags)
    }

    let kind: Kind

    /// Parse "shift", "cmd", "cmd+=", "shift+cmd+4", "cmd++" style strings.
    /// Modifiers: cmd/command, opt/alt/option, ctrl/control, shift (and left/right variants).
    /// If only modifiers are given, it represents a modifier hold/release. If a regular key is
    /// included, it represents that key with the specified modifier chord.
    /// Returns nil on an unknown or malformed spec.
    init?(_ spec: String) {
        guard let tokens = Self.tokenize(spec) else { return nil }

        var modifiers: [Modifier] = []
        var flags: CGEventFlags = []
        var keyToken: String?

        for t in tokens {
            if let mod = Self.modifierMap[t] {
                modifiers.append(mod)
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
        } else if !modifiers.isEmpty {
            self.kind = .modifier(modifiers)
        } else {
            return nil
        }
    }

    /// Splits on `+`, treating a trailing `+` ("cmd++", "+") as the plus key itself.
    /// A dangling single `+` ("shift+") is malformed.
    static func tokenize(_ spec: String) -> [String]? {
        var body = spec.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return nil }
        if body == "+" { return ["+"] }

        var plusKey = false
        if body.hasSuffix("++") {
            body.removeLast(2)
            plusKey = true
        } else if body.hasSuffix("+") {
            return nil
        }

        var tokens = body.split(separator: "+", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        if tokens.contains(where: \.isEmpty) { return nil }
        if plusKey { tokens.append("+") }
        return tokens
    }

    var isModifierOnly: Bool {
        if case .modifier = kind { return true }
        return false
    }

    /// Flags contributed while this stroke is held (modifier-only strokes; chords are momentary).
    var heldFlags: CGEventFlags {
        guard case .modifier(let mods) = kind else { return [] }
        return mods.reduce(into: CGEventFlags()) { $0.insert($1.flag) }
    }

    func postDown() {
        let src = CGEventSource(stateID: .hidSystemState)
        switch kind {
        case .modifier(let mods):
            var flags: CGEventFlags = []
            for mod in mods {
                flags.insert(mod.flag)
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: mod.code, keyDown: true) else { continue }
                e.flags.formUnion(flags)
                e.post(tap: .cghidEventTap)
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
        case .modifier(let mods):
            for mod in mods.reversed() {
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: mod.code, keyDown: false) else { continue }
                e.flags.remove(mod.flag)
                e.post(tap: .cghidEventTap)
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

    // caps lock and fn are intentionally unsupported: key code 57 toggles caps lock rather than
    // holding it, and a synthetic fn has no useful effect.
    private static let modifierMap: [String: Modifier] = {
        let cmdL = Modifier(code: 55, flag: .maskCommand), cmdR = Modifier(code: 54, flag: .maskCommand)
        let shiftL = Modifier(code: 56, flag: .maskShift), shiftR = Modifier(code: 60, flag: .maskShift)
        let optL = Modifier(code: 58, flag: .maskAlternate), optR = Modifier(code: 61, flag: .maskAlternate)
        let ctrlL = Modifier(code: 59, flag: .maskControl), ctrlR = Modifier(code: 62, flag: .maskControl)
        return [
            "cmd": cmdL, "command": cmdL, "lcmd": cmdL, "cmd_left": cmdL,
            "rcmd": cmdR, "cmd_right": cmdR,
            "shift": shiftL, "lshift": shiftL, "shift_left": shiftL,
            "rshift": shiftR, "shift_right": shiftR,
            "opt": optL, "option": optL, "alt": optL, "lopt": optL, "option_left": optL, "alt_left": optL,
            "ropt": optR, "option_right": optR, "alt_right": optR,
            "ctrl": ctrlL, "control": ctrlL, "lctrl": ctrlL, "control_left": ctrlL,
            "rctrl": ctrlR, "control_right": ctrlR,
        ]
    }()

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
}
