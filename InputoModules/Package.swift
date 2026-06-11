// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "InputoModules",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "InputoCore", targets: ["InputoCore"]),
        .library(name: "InputoMacPlatform", targets: ["InputoMacPlatform"]),
        .library(name: "InputoComposerFeature", targets: ["InputoComposerFeature"])
    ],
    targets: [
        .target(
            name: "InputoCore",
            path: "Sources/InputoCore"
        ),
        .target(
            name: "InputoMacPlatform",
            dependencies: ["InputoCore"],
            path: "Sources/InputoMacPlatform"
        ),
        .target(
            name: "InputoComposerFeature",
            dependencies: [
                "InputoCore",
                "InputoMacPlatform"
            ],
            path: "Sources/InputoComposerFeature"
        ),
        .testTarget(
            name: "InputoCoreTests",
            dependencies: ["InputoCore"],
            path: "Tests/InputoCoreTests"
        ),
        .testTarget(
            name: "InputoComposerFeatureTests",
            dependencies: [
                "InputoCore",
                "InputoMacPlatform",
                "InputoComposerFeature"
            ],
            path: "Tests/InputoComposerFeatureTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
