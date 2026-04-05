import Foundation

public final class ButtonAssignmentStore {
    public static let defaultStorageKey = "buttonAssignments"

    private struct LoadResult {
        let assignments: [MouseAction: Int]
        let needsPersistence: Bool
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private var assignments: [MouseAction: Int]

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = ButtonAssignmentStore.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        let loadResult = Self.loadAssignments(defaults: defaults, storageKey: storageKey)
        assignments = loadResult.assignments
        if loadResult.needsPersistence {
            persist()
        }
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
    ) -> LoadResult {
        guard let rawAssignments = defaults.dictionary(forKey: storageKey) else {
            return LoadResult(assignments: [:], needsPersistence: false)
        }

        var loadedAssignments: [MouseAction: Int] = [:]
        var assignedButtons: Set<Int> = []
        var needsPersistence = false

        for action in MouseAction.allCases {
            guard let rawButton = rawAssignments[action.rawValue] else {
                continue
            }

            guard let button = decodeButton(rawButton), button > 1 else {
                needsPersistence = true
                continue
            }

            if !assignedButtons.insert(button).inserted {
                needsPersistence = true
                continue
            }

            loadedAssignments[action] = button
        }

        let expectedKeys = Set(MouseAction.allCases.map(\.rawValue))
        if Set(rawAssignments.keys) != expectedKeys.intersection(rawAssignments.keys) {
            needsPersistence = true
        }

        return LoadResult(
            assignments: loadedAssignments,
            needsPersistence: needsPersistence
        )
    }

    private static func decodeButton(_ rawValue: Any) -> Int? {
        switch rawValue {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }
}
