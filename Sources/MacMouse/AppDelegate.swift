import AppKit
import Combine
import MacMouseCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launchedAtLogin = CommandLine.arguments.contains(LaunchAtLoginController.launchArgument)
    private let model = AppModel()
    private var cancellables: Set<AnyCancellable> = []
    private var statusItem: NSStatusItem?
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            StartupStderrSilencer.restoreIfNeeded()
        }
        configureApplicationIcon()
        configureMainMenu()
        bindStatusItemVisibility()

        if shouldOpenWindowOnLaunch {
            showWindow()
        } else {
            applyBackgroundActivationPolicyIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard windowController?.window?.isVisible != true else {
            return
        }

        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    @objc
    private func openWindow(_ sender: Any?) {
        showWindow()
    }

    @objc
    private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func configureApplicationIcon() {
        guard let applicationImage = AppIconAsset.applicationImage else {
            return
        }

        NSApp.applicationIconImage = applicationImage
    }

    private func showWindow() {
        if windowController == nil {
            let controller = MainWindowController(model: model)
            controller.window?.delegate = self
            windowController = controller
        }

        model.setConfigurationPresented(true)
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var shouldOpenWindowOnLaunch: Bool {
        !launchedAtLogin
    }

    private func applyBackgroundActivationPolicyIfNeeded() {
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open MacMouse",
            action: #selector(openWindow(_:)),
            keyEquivalent: ","
        )
        openItem.target = self
        appMenu.addItem(openItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit MacMouse",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func bindStatusItemVisibility() {
        model.$showsMenuBarIcon
            .removeDuplicates()
            .sink { [weak self] isVisible in
                self?.setStatusItemVisible(isVisible)
            }
            .store(in: &cancellables)
    }

    private func setStatusItemVisible(_ isVisible: Bool) {
        if isVisible {
            configureStatusItemIfNeeded()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func configureStatusItemIfNeeded() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.toolTip = "MacMouse"
            button.imageScaling = .scaleProportionallyDown

            if let statusItemImage = AppIconAsset.statusItemImage {
                button.image = statusItemImage
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.title = "🐭"
            }
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open MacMouse",
            action: #selector(openWindow(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp(_:)),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow == windowController?.window else {
            return
        }

        model.setConfigurationPresented(false)
        applyBackgroundActivationPolicyIfNeeded()
    }
}
