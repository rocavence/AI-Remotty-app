// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Remotty",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Remotty", path: "Sources/Remotty"),
    ],
    swiftLanguageModes: [.v5]
)
