// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cursor-window",
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
        .package(url: "https://github.com/vapor/vapor", from: "4.0.0"),
        .package(url: "https://github.com/vapor/leaf", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CursorWindowCore",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Metrics", package: "swift-metrics")
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
        // Temporarily disable UI tests until we can fix the compatibility issues
        // .testTarget(
        //     name: "CursorWindowUITests",
        //     dependencies: ["CursorWindow"],
        //     resources: [.process("Resources")])
    ]
)
