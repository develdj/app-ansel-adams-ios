// swift-tools-version:5.9
// Package.swift
// Zone System Master - Instax BLE Integration

import PackageDescription

let package = Package(
    name: "InstaxBLE",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "InstaxBLE",
            targets: ["InstaxBLE"]
        ),
    ],
    dependencies: [
        // Nessuna dipendenza esterna richiesta
    ],
    targets: [
        .target(
            name: "InstaxBLE",
            dependencies: [],
            path: "Sources",
            exclude: ["Info.plist"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "InstaxBLETests",
            dependencies: ["InstaxBLE"],
            path: "Tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
