import AppKit

enum MenuBarIcon {
    private static let pointSize: CGFloat = 18

    static func load() -> NSImage? {
        if let bundled = bundledImage() {
            return sized(bundled)
        }
        if let dev = devPathImage() {
            return sized(dev)
        }
        return fallbackSymbol()
    }

    private static func bundledImage() -> NSImage? {
        let names = ["menubar-icon@2x", "menubar-icon"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        if let url = Bundle.main.url(forResource: "menubar-icon", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    private static func devPathImage() -> NSImage? {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/project/personal/deskline/Sources/Resources")
        let candidates = [
            base.appendingPathComponent("menubar-icon@2x.png"),
            base.appendingPathComponent("menubar-icon.png"),
            base.appendingPathComponent("menubar-icon.svg"),
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    private static func sized(_ image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: pointSize, height: pointSize)
        copy.isTemplate = false
        return copy
    }

    private static func fallbackSymbol() -> NSImage? {
        guard let img = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Deskline") else {
            return nil
        }
        img.size = NSSize(width: pointSize, height: pointSize)
        return img
    }
}
