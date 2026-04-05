import AppKit
import Combine
import MacMouseCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var model = AppModel(
        shouldHandleEvent: { [weak self] type, event in
            self?.shouldHandleGlobalEvent(type: type, event: event) ?? true
        }
    )
    private var cancellables: Set<AnyCancellable> = []
    private var statusItem: NSStatusItem?
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()
        bindStatusItemVisibility()
        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc
    private func openWindow(_ sender: Any?) {
        showWindow()
    }

    @objc
    private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func showWindow() {
        if windowController == nil {
            let controller = MainWindowController(model: model)
            controller.window?.delegate = self
            windowController = controller
        }

        NSApp.setActivationPolicy(.regular)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func shouldHandleGlobalEvent(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .otherMouseDown || type == .otherMouseUp else {
            return true
        }

        guard let window = windowController?.window, window.isVisible,
              let contentView = window.contentView else {
            return true
        }

        let screenPoint = NSPoint(x: event.location.x, y: event.location.y)
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let contentPoint = contentView.convert(windowPoint, from: nil)
        guard let hitView = contentView.hitTest(contentPoint) else {
            return true
        }

        return hitView is MouseCaptureNSView == false
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

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🐭"
        item.button?.toolTip = "MacMouse"

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

        NSApp.setActivationPolicy(.accessory)
    }
}
