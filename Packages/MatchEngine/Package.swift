// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MatchEngine",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MatchEngine", targets: ["MatchEngine"])
    ],
    targets: [
        .target(name: "MatchEngine"),
        .testTarget(name: "MatchEngineTests", dependencies: ["MatchEngine"])
    ]
)
