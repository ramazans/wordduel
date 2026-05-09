// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuthService",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "AuthService", targets: ["AuthService"])
    ],
    dependencies: [
        .package(path: "../CoreModels")
    ],
    targets: [
        .target(
            name: "AuthService",
            dependencies: ["CoreModels"]
        ),
        .testTarget(
            name: "AuthServiceTests",
            dependencies: ["AuthService"]
        )
    ]
)
