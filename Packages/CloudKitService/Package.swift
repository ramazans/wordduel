// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CloudKitService",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CloudKitService", targets: ["CloudKitService"])
    ],
    dependencies: [
        .package(path: "../CoreModels")
    ],
    targets: [
        .target(
            name: "CloudKitService",
            dependencies: ["CoreModels"]
        ),
        .testTarget(
            name: "CloudKitServiceTests",
            dependencies: ["CloudKitService"]
        )
    ]
)
