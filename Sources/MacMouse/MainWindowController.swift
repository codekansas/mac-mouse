import AppKit
import MacMouseCore
import SwiftUI

final class MainWindowController: NSWindowController {
    init(model: AppModel) {
        let rootView = SettingsRootView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)

        window.title = "MacMouse"
        window.styleMask = [.titled, .closable]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.setContentSize(NSSize(width: 420, height: 250))
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.collectionBehavior = [.moveToActiveSpace]

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
