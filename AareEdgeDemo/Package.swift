// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AareEdgeDemo",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AareEdgeDemo",
            targets: ["AareEdgeDemo"]
        ),
    ],
    dependencies: [
        .package(path: "../AareEdgeSDK")
    ],
    targets: [
        .executableTarget(
            name: "AareEdgeDemo",
            dependencies: ["AareEdgeSDK"],
            path: "AareEdgeDemo"
        ),
    ]
)
