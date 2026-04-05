import MacMouseCore
import XCTest

final class ButtonAssignmentStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: ButtonAssignmentStore!

    override func setUp() {
        super.setUp()
        suiteName = "MacMouseTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = ButtonAssignmentStore(defaults: defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }

        suiteName = nil
        defaults = nil
        store = nil
        super.tearDown()
    }

    func testAssignIgnoresPrimaryAndSecondaryButtons() {
        XCTAssertFalse(store.assign(button: 0, to: .missionControl))
        XCTAssertFalse(store.assign(button: 1, to: .missionControl))
        XCTAssertNil(store.button(for: .missionControl))
    }

    func testAssignMovesSharedButtonToNewestAction() {
        XCTAssertTrue(store.assign(button: 4, to: .missionControl))
        XCTAssertTrue(store.assign(button: 4, to: .moveLeftSpace))

        XCTAssertNil(store.button(for: .missionControl))
        XCTAssertEqual(store.button(for: .moveLeftSpace), 4)
    }

    func testClearRemovesStoredAssignment() {
        XCTAssertTrue(store.assign(button: 2, to: .moveRightSpace))
        XCTAssertTrue(store.clear(.moveRightSpace))
        XCTAssertNil(store.button(for: .moveRightSpace))
    }

    func testInitNormalizesInvalidAndDuplicateAssignments() {
        defaults.set(
            [
                "missionControl": 4,
                "moveLeftSpace": 4,
                "moveRightSpace": 1,
                "unknownAction": 7,
            ],
            forKey: ButtonAssignmentStore.defaultStorageKey
        )

        store = ButtonAssignmentStore(defaults: defaults)

        XCTAssertEqual(store.button(for: .missionControl), 4)
        XCTAssertNil(store.button(for: .moveLeftSpace))
        XCTAssertNil(store.button(for: .moveRightSpace))

        let persistedAssignments = defaults.dictionary(
            forKey: ButtonAssignmentStore.defaultStorageKey
        ) as? [String: Int]
        XCTAssertEqual(persistedAssignments, ["missionControl": 4])
    }
}
