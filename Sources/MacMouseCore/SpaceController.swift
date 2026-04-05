import CoreGraphics
import Darwin
import Foundation

final class SpaceController: @unchecked Sendable {
    private typealias cgsSymbolicHotKey = UInt32
    private typealias cgsModifierFlags = UInt32
    private typealias cgsError = Int32
    private typealias cgsGetSymbolicHotKeyValueFn = @convention(c) (
        cgsSymbolicHotKey,
        UnsafeMutablePointer<UInt16>?,
        UnsafeMutablePointer<UInt16>?,
        UnsafeMutablePointer<cgsModifierFlags>?
    ) -> cgsError
    private typealias cgsSetSymbolicHotKeyValueFn = @convention(c) (
        cgsSymbolicHotKey,
        UInt16,
        UInt16,
        cgsModifierFlags
    ) -> cgsError
    private typealias cgsIsSymbolicHotKeyEnabledFn = @convention(c) (cgsSymbolicHotKey) -> Bool
    private typealias cgsSetSymbolicHotKeyEnabledFn = @convention(c) (cgsSymbolicHotKey, Bool) -> cgsError

    private struct ShortcutBinding {
        let keyCode: CGKeyCode
        let flags: CGEventFlags
    }

    private struct Symbols {
        let handle: UnsafeMutableRawPointer
        let getSymbolicHotKeyValue: cgsGetSymbolicHotKeyValueFn
        let setSymbolicHotKeyValue: cgsSetSymbolicHotKeyValueFn
        let isSymbolicHotKeyEnabled: cgsIsSymbolicHotKeyEnabledFn
        let setSymbolicHotKeyEnabled: cgsSetSymbolicHotKeyEnabledFn
    }

    private enum Constants {
        static let skyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        static let moveLeftSpaceHotKeyID: cgsSymbolicHotKey = 79
        static let moveRightSpaceHotKeyID: cgsSymbolicHotKey = 81
        static let nullKeyEquivalent = UInt16.max
        static let invalidKeyCode = UInt16.max
        static let hiddenKeyCodeBase: UInt16 = 400
        static let success: cgsError = 0
        static let hiddenFlags: cgsModifierFlags = (1 << 21) | (1 << 23)
    }

    static let shared = SpaceController()

    private let symbols: Symbols?

    private init() {
        guard
            let handle = dlopen(Constants.skyLightPath, RTLD_NOW),
            let getValueSymbol = dlsym(handle, "CGSGetSymbolicHotKeyValue"),
            let setValueSymbol = dlsym(handle, "CGSSetSymbolicHotKeyValue"),
            let isEnabledSymbol = dlsym(handle, "CGSIsSymbolicHotKeyEnabled"),
            let setEnabledSymbol = dlsym(handle, "CGSSetSymbolicHotKeyEnabled")
        else {
            symbols = nil
            return
        }

        symbols = Symbols(
            handle: handle,
            getSymbolicHotKeyValue: unsafeBitCast(
                getValueSymbol,
                to: cgsGetSymbolicHotKeyValueFn.self
            ),
            setSymbolicHotKeyValue: unsafeBitCast(
                setValueSymbol,
                to: cgsSetSymbolicHotKeyValueFn.self
            ),
            isSymbolicHotKeyEnabled: unsafeBitCast(
                isEnabledSymbol,
                to: cgsIsSymbolicHotKeyEnabledFn.self
            ),
            setSymbolicHotKeyEnabled: unsafeBitCast(
                setEnabledSymbol,
                to: cgsSetSymbolicHotKeyEnabledFn.self
            )
        )
    }

    // Follow mac-mouse-fix's approach: target the system's CGSSymbolicHotKey
    // IDs for "Move left/right a Space" instead of selecting a desktop or
    // falling back to plain Ctrl-arrow injection. If the user has no keyboard
    // shortcut configured for the symbolic hotkey, create an unreachable hidden
    // binding and trigger that.
    func moveSpace(offset: Int) -> Bool {
        let hotKeyID: cgsSymbolicHotKey
        switch offset {
        case -1:
            hotKeyID = Constants.moveLeftSpaceHotKeyID
        case 1:
            hotKeyID = Constants.moveRightSpaceHotKeyID
        default:
            return false
        }

        return postSymbolicHotKey(hotKeyID)
    }

    private func postSymbolicHotKey(_ hotKeyID: cgsSymbolicHotKey) -> Bool {
        guard let symbols else {
            return false
        }

        if let binding = configuredBinding(for: hotKeyID, symbols: symbols) {
            return postKeyboardShortcut(binding)
        }

        guard
            ensureHiddenBinding(for: hotKeyID, symbols: symbols),
            let binding = hiddenBinding(for: hotKeyID)
        else {
            return false
        }

        return postKeyboardShortcut(binding)
    }

    private func configuredBinding(
        for hotKeyID: cgsSymbolicHotKey,
        symbols: Symbols
    ) -> ShortcutBinding? {
        guard symbols.isSymbolicHotKeyEnabled(hotKeyID) else {
            return nil
        }

        var keyEquivalent = Constants.nullKeyEquivalent
        var keyCode = Constants.invalidKeyCode
        var modifiers: cgsModifierFlags = 0
        let result = symbols.getSymbolicHotKeyValue(
            hotKeyID,
            &keyEquivalent,
            &keyCode,
            &modifiers
        )

        guard result == Constants.success, keyCode != Constants.invalidKeyCode else {
            return nil
        }

        return ShortcutBinding(
            keyCode: CGKeyCode(keyCode),
            flags: CGEventFlags(rawValue: UInt64(modifiers))
        )
    }

    private func ensureHiddenBinding(
        for hotKeyID: cgsSymbolicHotKey,
        symbols: Symbols
    ) -> Bool {
        let enableResult = symbols.setSymbolicHotKeyEnabled(hotKeyID, true)
        guard enableResult == Constants.success else {
            return false
        }

        guard let binding = hiddenBinding(for: hotKeyID) else {
            return false
        }

        let result = symbols.setSymbolicHotKeyValue(
            hotKeyID,
            Constants.nullKeyEquivalent,
            UInt16(binding.keyCode),
            Constants.hiddenFlags
        )
        return result == Constants.success
    }

    private func hiddenBinding(for hotKeyID: cgsSymbolicHotKey) -> ShortcutBinding? {
        let keyCodeValue = Int(hotKeyID) + Int(Constants.hiddenKeyCodeBase)
        guard let keyCode = UInt16(exactly: keyCodeValue) else {
            return nil
        }

        return ShortcutBinding(
            keyCode: CGKeyCode(keyCode),
            flags: CGEventFlags(rawValue: UInt64(Constants.hiddenFlags))
        )
    }

    private func postKeyboardShortcut(_ binding: ShortcutBinding) -> Bool {
        guard
            let keyDown = CGEvent(
                keyboardEventSource: nil,
                virtualKey: binding.keyCode,
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: nil,
                virtualKey: binding.keyCode,
                keyDown: false
            )
        else {
            return false
        }

        let originalModifierFlags = keyDown.flags
        keyDown.flags = binding.flags
        keyUp.flags = originalModifierFlags
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        return true
    }
}
