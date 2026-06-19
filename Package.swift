// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Deskline",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Deskline",
            path: "Sources"
        )
    ]
)
