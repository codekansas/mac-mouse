import CoreGraphics
import Foundation

public enum MouseAction: String, CaseIterable, Identifiable, Sendable {
    case missionControl
    case moveLeftSpace
    case moveRightSpace

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .missionControl:
            "Mission Control"
        case .moveLeftSpace:
            "Move Left a Space"
        case .moveRightSpace:
            "Move Right a Space"
        }
    }

    var keyCode: CGKeyCode {
        switch self {
        case .missionControl:
            126
        case .moveLeftSpace:
            123
        case .moveRightSpace:
            124
        }
    }

    var modifierFlags: CGEventFlags {
        [.maskControl]
    }
}
