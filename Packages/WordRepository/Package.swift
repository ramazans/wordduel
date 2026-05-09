// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WordRepository",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(name: "WordRepository", targets: ["WordRepository"])
    ],
    targets: [
        .target(
            name: "WordRepository",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WordRepositoryTests",
            dependencies: ["WordRepository"]
        )
    ]
)
