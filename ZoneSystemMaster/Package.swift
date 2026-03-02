// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZoneSystemMaster",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17)
    ],
    products: [
        .library(
            name: "ZoneSystemMaster",
            targets: ["ZoneSystemMaster"]
        ),
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        .target(
            name: "ZoneSystemMaster",
            dependencies: [],
            resources: [
                .process("Shaders")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ZoneSystemMasterTests",
            dependencies: ["ZoneSystemMaster"]
        ),
    ]
)
