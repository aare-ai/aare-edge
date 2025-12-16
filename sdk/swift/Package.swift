// swift-tools-version: 5.9
// Aare Edge SDK - On-Device HIPAA PHI Verification

import PackageDescription

let package = Package(
    name: "AareEdge",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AareEdge",
            targets: ["AareEdge"]
        ),
    ],
    dependencies: [
        // MLX for on-device inference (Apple Silicon)
        // .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "AareEdge",
            dependencies: [],
            path: "Sources/AareEdge",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AareEdgeTests",
            dependencies: ["AareEdge"],
            path: "Tests/AareEdgeTests"
        ),
    ]
)
