import CoreGraphics
import Foundation

public protocol ShortcutPerforming {
    func perform(_ action: MouseAction)
}

public struct ShortcutPerformer: ShortcutPerforming {
    public init() {}

    public func perform(_ action: MouseAction) {
        switch action {
        case .missionControl:
            if !showMissionControl() {
                sendShortcut(keyCode: action.keyCode, flags: action.modifierFlags)
            }

        case .moveLeftSpace:
            _ = SpaceController.shared.moveSpace(offset: -1)

        case .moveRightSpace:
            _ = SpaceController.shared.moveSpace(offset: 1)
        }
    }

    private func showMissionControl() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", "com.apple.exposelauncher"]

        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }

    // Fallback path when the direct system integration is unavailable.
    private func sendShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyCode,
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: keyCode,
                keyDown: false
            )
        else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
