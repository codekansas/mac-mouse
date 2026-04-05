import Foundation

public final class ButtonAssignmentStore {
    public static let defaultStorageKey = "buttonAssignments"

    private let defaults: UserDefaults
    private let storageKey: String
    private var assignments: [MouseAction: Int]

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = ButtonAssignmentStore.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        assignments = Self.loadAssignments(defaults: defaults, storageKey: storageKey)
    }

    public var currentAssignments: [MouseAction: Int] {
        assignments
    }

    public func button(for action: MouseAction) -> Int? {
        assignments[action]
    }

    public func action(for button: Int) -> MouseAction? {
        assignments.first { _, candidateButton in
            candidateButton == button
        }?.key
    }

    @discardableResult
    public func assign(button: Int, to action: MouseAction) -> Bool {
        guard button > 1 else {
            return false
        }

        for candidate in MouseAction.allCases where candidate != action {
            if assignments[candidate] == button {
                assignments.removeValue(forKey: candidate)
            }
        }

        assignments[action] = button
        persist()
        return true
    }

    @discardableResult
    public func clear(_ action: MouseAction) -> Bool {
        let removed = assignments.removeValue(forKey: action) != nil
        if removed {
            persist()
        }
        return removed
    }

    private func persist() {
        let rawAssignments = Dictionary(
            uniqueKeysWithValues: assignments.map { action, button in
                (action.rawValue, button)
            }
        )
        defaults.set(rawAssignments, forKey: storageKey)
    }

    private static func loadAssignments(
        defaults: UserDefaults,
        storageKey: String
    ) -> [MouseAction: Int] {
        guard let rawAssignments = defaults.dictionary(forKey: storageKey) as? [String: Int] else {
            return [:]
        }

        var loadedAssignments: [MouseAction: Int] = [:]
        for (rawAction, button) in rawAssignments {
            guard let action = MouseAction(rawValue: rawAction), button > 1 else {
                continue
            }
            loadedAssignments[action] = button
        }

        return loadedAssignments
    }
}
