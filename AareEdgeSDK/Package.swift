// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AareEdgeSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AareEdgeSDK",
            targets: ["AareEdgeSDK"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AareEdgeSDK",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AareEdgeSDKTests",
            dependencies: ["AareEdgeSDK"]),
    ]
)
