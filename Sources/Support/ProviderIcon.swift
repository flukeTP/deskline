import AppKit
import SwiftUI

/// Brand PNGs from Simple Icons (CC0) + Lobe Icons (MIT). Refresh: `./scripts/fetch-provider-icons.sh`
enum ProviderIcon {
    static func nsImage(for provider: AIProvider, size: CGFloat = 14) -> NSImage? {
        guard let base = loadBaseImage(for: provider) else { return nil }
        let copy = base.copy() as? NSImage ?? base
        copy.size = NSSize(width: size, height: size)
        copy.isTemplate = false
        return copy
    }

    static func swiftUI(for provider: AIProvider, size: CGFloat = 14) -> some View {
        Group {
            if let image = nsImage(for: provider, size: size) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: provider.symbolName)
                    .font(.system(size: size - 2, weight: .semibold))
                    .foregroundStyle(HUDTheme.tint(for: provider))
                    .frame(width: size, height: size)
            }
        }
    }

    private static func loadBaseImage(for provider: AIProvider) -> NSImage? {
        let name = provider.rawValue
        let subdirs = ["Providers", nil as String?]
        for sub in subdirs {
            if let sub {
                if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: sub),
                   let image = NSImage(contentsOf: url) {
                    return image
                }
            } else if let url = Bundle.main.url(forResource: name, withExtension: "png"),
                      let image = NSImage(contentsOf: url) {
                return image
            }
        }
        for url in devCandidates(name: name) where FileManager.default.fileExists(atPath: url.path) {
            if let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    private static func devCandidates(name: String) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let repo = home.appendingPathComponent("Documents/project/personal/deskline/Sources/Resources/Providers/\(name).png")
        let relative = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Providers/\(name).png")
        return [repo, relative]
    }
}
