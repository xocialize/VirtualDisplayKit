// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VirtualDisplayKit",
    platforms: [
        .macOS(.v13) // Requires macOS 13+ for ScreenCaptureKit features
    ],
    products: [
        .library(
            name: "VirtualDisplayKit",
            targets: ["VirtualDisplayKit"]
        ),
    ],
    dependencies: [],
    targets: [
        // C target for the private CGVirtualDisplay headers
        .target(
            name: "CVirtualDisplayPrivate",
            dependencies: [],
            publicHeadersPath: "include"
        ),
        // Main Swift library target
        .target(
            name: "VirtualDisplayKit",
            dependencies: ["CVirtualDisplayPrivate"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "VirtualDisplayKitTests",
            dependencies: ["VirtualDisplayKit"]
        ),
    ]
)
