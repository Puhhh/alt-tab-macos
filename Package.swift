// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AltTabWindows",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AltTabWindows",
            path: "Sources/AltTabWindows"
        )
    ]
)