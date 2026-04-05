import AppKit

enum AppIconAsset {
    private static let resourceName = "MouseIcon"

    static let applicationImage: NSImage? = {
        guard let resourceURL = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
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
