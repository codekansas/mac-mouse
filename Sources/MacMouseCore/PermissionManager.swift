import AppKit
import ApplicationServices
import Foundation

public struct PermissionStatus: Sendable {
    public let accessibilityEnabled: Bool
    public let listenEnabled: Bool

    public var hasRequiredAccess: Bool {
        accessibilityEnabled && listenEnabled
    }
}

public protocol PermissionControlling {
    func currentStatus() -> PermissionStatus
    func requestRequiredAccess() -> PermissionStatus
    func openPrivacySettings()
}

public struct PermissionManager: PermissionControlling {
    public init() {}

    public func currentStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityEnabled: AXIsProcessTrusted(),
            listenEnabled: CGPreflightListenEventAccess()
        )
    }

    public func requestRequiredAccess() -> PermissionStatus {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestListenEventAccess()
        return currentStatus()
    }

    public func openPrivacySettings() {
        let status = currentStatus()
        let urls: [URL?] = [
            !status.accessibilityEnabled
                ? URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                : nil,
            !status.listenEnabled
                ? URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
                : nil,
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security"),
        ]

        for candidateURL in urls {
            if let candidateURL, NSWorkspace.shared.open(candidateURL) {
                return
            }
        }

        let fallbackURL = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
        NSWorkspace.shared.open(fallbackURL)
    }

    private var prompt: Bool {
        true
    }
}
