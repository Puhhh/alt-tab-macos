// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AltTabMacOS",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AltTabMacOS",
            path: "Sources/AltTabMacOS"
        )
    ]
)
