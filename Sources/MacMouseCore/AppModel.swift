import AppKit
import Combine
import Foundation

public final class AppModel: NSObject, ObservableObject {
    public static let showMenuBarIconKey = "showMenuBarIcon"

    @Published public private(set) var assignments: [MouseAction: Int]
    @Published public private(set) var permissionStatus: PermissionStatus
    @Published public private(set) var runsOnStartup: Bool
    @Published public private(set) var canConfigureRunOnStartup: Bool
    @Published public var showsMenuBarIcon: Bool
    @Published public var captureTarget: MouseAction?

    private let defaults: UserDefaults
    private let launchAtLoginController: LaunchAtLoginControlling
    private let permissionManager: PermissionControlling
    private let store: ButtonAssignmentStore
    private let performer: ShortcutPerforming
    private var permissionTimer: Timer?
    private var runOnStartupErrorMessage: String?
    private var shouldHandleGlobalEvents = true
    private lazy var monitor = GlobalMouseMonitor(
        store: store,
        performer: performer,
        shouldHandleEvents: { [weak self] in
            self?.shouldHandleGlobalEvents ?? true
        }
    )

    public init(
        defaults: UserDefaults = .standard,
        launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController(),
        permissionManager: PermissionControlling = PermissionManager(),
        store: ButtonAssignmentStore = ButtonAssignmentStore(),
        performer: ShortcutPerforming = ShortcutPerformer()
    ) {
        self.defaults = defaults
        self.launchAtLoginController = launchAtLoginController
        self.permissionManager = permissionManager
        self.store = store
        self.performer = performer
        assignments = store.currentAssignments
        permissionStatus = permissionManager.currentStatus()
        let launchAtLoginStatus = launchAtLoginController.currentStatus()
        runsOnStartup = launchAtLoginStatus.isEnabled
        canConfigureRunOnStartup = launchAtLoginStatus.isAvailable
        if defaults.object(forKey: Self.showMenuBarIconKey) == nil {
            showsMenuBarIcon = true
        } else {
            showsMenuBarIcon = defaults.bool(forKey: Self.showMenuBarIconKey)
        }

        super.init()
        refreshRunOnStartupState()
        startPermissionPolling()
        refreshPermissionState()
    }

    deinit {
        permissionTimer?.invalidate()
        monitor.stop()
    }

    public func refreshPermissionState() {
        let status = permissionManager.currentStatus()
        permissionStatus = status

        if status.hasRequiredAccess {
            _ = monitor.start()
        } else {
            monitor.stop()
        }
    }

    @discardableResult
    public func requestRequiredAccess() -> Bool {
        let status = permissionManager.requestRequiredAccess()
        permissionStatus = status
        refreshPermissionState()
        return status.hasRequiredAccess
    }

    public func openPrivacySettings() {
        permissionManager.openPrivacySettings()
    }

    public func refreshRunOnStartupState() {
        do {
            applyRunOnStartupStatus(try launchAtLoginController.syncRegistrationIfNeeded(), errorMessage: nil)
        } catch {
            applyRunOnStartupStatus(
                launchAtLoginController.currentStatus(),
                errorMessage: error.localizedDescription
            )
        }
    }

    public func beginCapture(for action: MouseAction) {
        captureTarget = action
    }

    public func setConfigurationPresented(_ isPresented: Bool) {
        shouldHandleGlobalEvents = !isPresented
    }

    public func setShowsMenuBarIcon(_ showsMenuBarIcon: Bool) {
        self.showsMenuBarIcon = showsMenuBarIcon
        defaults.set(showsMenuBarIcon, forKey: Self.showMenuBarIconKey)
    }

    public func setRunsOnStartup(_ runsOnStartup: Bool) {
        do {
            applyRunOnStartupStatus(
                try launchAtLoginController.setEnabled(runsOnStartup),
                errorMessage: nil
            )
        } catch {
            applyRunOnStartupStatus(
                launchAtLoginController.currentStatus(),
                errorMessage: error.localizedDescription
            )
        }
    }

    public func clearAssignment(for action: MouseAction) {
        if store.clear(action) {
            assignments = store.currentAssignments
        }

        if captureTarget == action {
            captureTarget = nil
        }
    }

    public func assignCapturedButton(_ button: Int, to action: MouseAction) {
        guard store.assign(button: button, to: action) else {
            return
        }

        assignments = store.currentAssignments
        captureTarget = nil
    }

    public func isCapturing(_ action: MouseAction) -> Bool {
        captureTarget == action
    }

    public func buttonLabel(for action: MouseAction) -> String {
        if captureTarget == action {
            return "Press a button"
        }

        guard let button = assignments[action] else {
            return "Assign"
        }

        return buttonName(for: button)
    }

    public var helperText: String {
        if captureTarget != nil {
            return "Primary and secondary clicks are ignored."
        }

        return "Scroll smoothing stays active while MacMouse runs."
    }

    public var runOnStartupNote: String? {
        if let runOnStartupErrorMessage {
            return runOnStartupErrorMessage
        }

        if !canConfigureRunOnStartup && !runsOnStartup {
            return "Run on Startup is available only from an installed MacMouse.app."
        }

        if runsOnStartup && !showsMenuBarIcon {
            return "MacMouse stays hidden at login when the menu bar icon is off. Open MacMouse.app again to show this window."
        }

        return nil
    }

    private func buttonName(for button: Int) -> String {
        if button == 2 {
            return "Middle Button"
        }

        return "Button \(button)"
    }

    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(
            timeInterval: 0.8,
            target: self,
            selector: #selector(pollPermissions),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(permissionTimer!, forMode: .common)
        permissionTimer?.tolerance = 0.2
    }

    @objc
    private func pollPermissions() {
        refreshPermissionState()
    }

    private func applyRunOnStartupStatus(
        _ status: LaunchAtLoginStatus,
        errorMessage: String?
    ) {
        runsOnStartup = status.isEnabled
        canConfigureRunOnStartup = status.isAvailable
        runOnStartupErrorMessage = errorMessage
    }
}
