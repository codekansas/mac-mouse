import AppKit

@MainActor
enum AppIconAsset {
    private static let resourceName = "MouseIcon"
    private static let resourceBundleName = "MacMouse_MacMouse.bundle"

    private static var executableDirectoryURL: URL {
        URL(fileURLWithPath: CommandLine.arguments[0], isDirectory: false)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
    }

    private static var resourceURL: URL? {
        if let resourceURL = Bundle.main.url(forResource: resourceName, withExtension: "png") {
            return resourceURL
        }

        let bundleURLs = [
            Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName),
            executableDirectoryURL.appendingPathComponent(resourceBundleName),
        ].compactMap { $0 }

        for bundleURL in bundleURLs {
            guard let bundle = Bundle(url: bundleURL) else {
                continue
            }

            if let resourceURL = bundle.url(forResource: resourceName, withExtension: "png") {
                return resourceURL
            }
        }

        return nil
    }

    static let applicationImage: NSImage? = {
        guard let resourceURL else {
            return nil
        }

        return NSImage(contentsOf: resourceURL)
    }()

    static var statusItemImage: NSImage? {
        guard let image = applicationImage?.copy() as? NSImage else {
            return nil
        }

        image.isTemplate = false
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
