import Foundation

public struct LaunchAtLoginStatus: Equatable, Sendable {
    public let isEnabled: Bool
    public let isAvailable: Bool

    public init(isEnabled: Bool, isAvailable: Bool) {
        self.isEnabled = isEnabled
        self.isAvailable = isAvailable
    }
}

public enum LaunchAtLoginError: LocalizedError {
    case appBundleRequired
    case unableToCreateLaunchAgent
    case unableToWriteLaunchAgent
    case unableToRemoveLaunchAgent

    public var errorDescription: String? {
        switch self {
        case .appBundleRequired:
            "Run on Startup is available only when MacMouse is launched from MacMouse.app."
        case .unableToCreateLaunchAgent:
            "MacMouse couldn't create its login item configuration."
        case .unableToWriteLaunchAgent:
            "MacMouse couldn't save its Run on Startup setting."
        case .unableToRemoveLaunchAgent:
            "MacMouse couldn't remove its Run on Startup setting."
        }
    }
}

public protocol LaunchAtLoginControlling {
    func currentStatus() -> LaunchAtLoginStatus
    func syncRegistrationIfNeeded() throws -> LaunchAtLoginStatus
    func setEnabled(_ isEnabled: Bool) throws -> LaunchAtLoginStatus
}

public final class LaunchAtLoginController: LaunchAtLoginControlling {
    public static let launchArgument = "--launch-at-login"

    private let fileManager: FileManager
    private let launchAgentDirectoryURL: URL
    private let bundleURLProvider: () -> URL
    private let executableURLProvider: () -> URL?
    private let bundleIdentifierProvider: () -> String?

    public init(
        fileManager: FileManager = .default,
        launchAgentDirectoryURL: URL? = nil,
        bundleURLProvider: @escaping () -> URL = { Bundle.main.bundleURL },
        executableURLProvider: @escaping () -> URL? = { Bundle.main.executableURL },
        bundleIdentifierProvider: @escaping () -> String? = { Bundle.main.bundleIdentifier }
    ) {
        self.fileManager = fileManager
        self.launchAgentDirectoryURL = launchAgentDirectoryURL
            ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        self.bundleURLProvider = bundleURLProvider
        self.executableURLProvider = executableURLProvider
        self.bundleIdentifierProvider = bundleIdentifierProvider
    }

    public func currentStatus() -> LaunchAtLoginStatus {
        LaunchAtLoginStatus(
            isEnabled: fileManager.fileExists(atPath: launchAgentURL.path),
            isAvailable: bundledExecutableURL != nil
        )
    }

    public func syncRegistrationIfNeeded() throws -> LaunchAtLoginStatus {
        let status = currentStatus()
        guard status.isEnabled, status.isAvailable else {
            return status
        }

        return try setEnabled(true)
    }

    public func setEnabled(_ isEnabled: Bool) throws -> LaunchAtLoginStatus {
        if isEnabled {
            try writeLaunchAgent()
        } else {
            try removeLaunchAgent()
        }

        return currentStatus()
    }

    private var bundledExecutableURL: URL? {
        let bundleURL = bundleURLProvider().resolvingSymlinksInPath()
        guard bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
              let executableURL = executableURLProvider()?.resolvingSymlinksInPath(),
              executableURL.path.hasPrefix(bundleURL.path + "/") else {
            return nil
        }

        return executableURL
    }

    private var launchAgentLabel: String {
        bundleIdentifierProvider() ?? "com.macmouse.app"
    }

    private var launchAgentURL: URL {
        launchAgentDirectoryURL.appendingPathComponent("\(launchAgentLabel).plist")
    }

    private func writeLaunchAgent() throws {
        guard let executableURL = bundledExecutableURL else {
            throw LaunchAtLoginError.appBundleRequired
        }

        let propertyList: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [executableURL.path, Self.launchArgument],
            "RunAtLoad": true,
        ]

        let data: Data
        do {
            data = try PropertyListSerialization.data(
                fromPropertyList: propertyList,
                format: .xml,
                options: 0
            )
        } catch {
            throw LaunchAtLoginError.unableToWriteLaunchAgent
        }

        do {
            try fileManager.createDirectory(
                at: launchAgentDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw LaunchAtLoginError.unableToCreateLaunchAgent
        }

        do {
            try data.write(to: launchAgentURL, options: .atomic)
        } catch {
            throw LaunchAtLoginError.unableToWriteLaunchAgent
        }
    }

    private func removeLaunchAgent() throws {
        guard fileManager.fileExists(atPath: launchAgentURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: launchAgentURL)
        } catch {
            throw LaunchAtLoginError.unableToRemoveLaunchAgent
        }
    }
}
