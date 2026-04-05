import Foundation

struct SystemScrollSettings {
    private enum Constants {
        static let wheelScalingKey = "com.apple.scrollwheel.scaling"
        static let fallbackMultiplier = 1.0
        static let minMultiplier = 0.45
        static let maxMultiplier = 2.4
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func speedMultiplier() -> Double {
        guard let scaling = currentWheelScaling(), scaling > 0 else {
            return Constants.fallbackMultiplier
        }

        // macOS stores wheel speed as an internal scalar rather than in the
        // same units as our synthetic pixel events, so apply a gentler curve.
        let adjustedMultiplier = sqrt(scaling)
        return min(max(adjustedMultiplier, Constants.minMultiplier), Constants.maxMultiplier)
    }

    private func currentWheelScaling() -> Double? {
        guard let globalDomain = defaults.persistentDomain(forName: UserDefaults.globalDomain),
              let value = globalDomain[Constants.wheelScalingKey] else {
            return nil
        }

        return decodeDouble(value)
    }

    private func decodeDouble(_ value: Any) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        case let string as NSString:
            return Double(String(string))
        default:
            return nil
        }
    }
}
