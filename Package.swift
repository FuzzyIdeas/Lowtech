// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lowtech",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Lowtech",
            targets: ["Lowtech"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/sindresorhus/Defaults", from: "6.2.1"),
        .package(url: "https://github.com/mxcl/Path.swift", from: "1.4.0"),
        .package(url: "https://github.com/apple/swift-atomics", from: "1.0.2"),
        .package(url: "https://github.com/crossroadlabs/Regex", branch: "master"),
        .package(url: "https://github.com/alin23/FuzzyFind", branch: "main"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin", branch: "main"),
        .package(url: "https://github.com/alin23/Magnet", branch: "dev"),
        .package(url: "https://github.com/Clipy/Sauce", from: "2.2.0"),
        .package(url: "https://github.com/twostraws/VisualEffects", from: "1.0.3"),
        .package(url: "https://github.com/eonil/FSEvents", from: "0.1.7"),
        .package(url: "https://github.com/yannickl/DynamicColor", from: "5.0.1"),
        .package(url: "https://github.com/diniska/swiftui-system-colors", from: "1.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Lowtech",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Path", package: "Path.swift"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "Regex", package: "Regex"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin", condition: .when(platforms: [.macOS])),
                .product(name: "Magnet", package: "Magnet", condition: .when(platforms: [.macOS])),
                .product(name: "Sauce", package: "Sauce", condition: .when(platforms: [.macOS])),
                .product(name: "VisualEffects", package: "VisualEffects", condition: .when(platforms: [.macOS])),
                .product(name: "EonilFSEvents", package: "FSEvents", condition: .when(platforms: [.macOS])),
                .product(name: "DynamicColor", package: "DynamicColor"),
                .product(name: "FuzzyFind", package: "FuzzyFind"),
                .product(name: "SystemColors", package: "swiftui-system-colors"),
            ]
        ),
        .testTarget(
            name: "LowtechTests",
            dependencies: ["Lowtech"]
        ),
    ]
)
