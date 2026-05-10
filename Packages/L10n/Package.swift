// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "L10n",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "L10n", targets: ["L10n"])
    ],
    targets: [
        .target(name: "L10n"),
        .testTarget(name: "L10nTests", dependencies: ["L10n"])
    ]
)
