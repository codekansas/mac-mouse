import AppKit

StartupStderrSilencer.activateIfNeeded()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
