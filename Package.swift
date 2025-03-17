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
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.76.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.2.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CursorWindowCore",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf")
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]),
        .executableTarget(
            name: "CursorWindow",
            dependencies: ["CursorWindowCore"],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]),
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
