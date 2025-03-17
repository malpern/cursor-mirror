// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CursorWindow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CursorWindowCore",
            targets: ["CursorWindowCore"]),
        .executable(
            name: "CursorWindow",
            targets: ["CursorWindow"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.4"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.2.4"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.1"),
        .package(url: "https://github.com/swift-server/swift-prometheus.git", from: "2.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CursorWindowCore",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "SwiftPrometheus", package: "swift-prometheus"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]),
        .executableTarget(
            name: "CursorWindow",
            dependencies: ["CursorWindowCore"]),
        .testTarget(
            name: "CursorWindowCoreTests",
            dependencies: [
                "CursorWindowCore",
                .product(name: "XCTVapor", package: "vapor")
            ]),
        .testTarget(
            name: "CursorWindowTests",
            dependencies: ["CursorWindow"]),
        .testTarget(
            name: "CursorWindowUITests",
            dependencies: ["CursorWindow"],
            resources: [.process("Resources")])
    ]
)
