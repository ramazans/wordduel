// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreModels",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"])
    ],
    targets: [
        .target(name: "CoreModels"),
        .testTarget(name: "CoreModelsTests", dependencies: ["CoreModels"])
    ]
)
