// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lowtech",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Lowtech",
            targets: ["Lowtech"]
        ),
        .library(
            name: "LowtechAppStore",
            targets: ["LowtechAppStore"]
        ),
        .library(
            name: "LowtechIndie",
            targets: ["LowtechIndie"]
        ),
        .library(
            name: "LowtechPro",
            targets: ["LowtechPro"]
        ),
        .library(
            name: "LowtechSetapp",
            targets: ["LowtechSetapp"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/sindresorhus/Defaults", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-atomics", from: "1.0.2"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.0.0"),
        .package(url: "https://github.com/alin23/Magnet", from: "4.0.1"),
        .package(url: "https://github.com/Clipy/Sauce", from: "2.2.0"),
        .package(url: "https://github.com/eonil/FSEvents", from: "0.1.7"),
        .package(url: "https://github.com/yannickl/DynamicColor", from: "5.0.1"),
        .package(url: "https://github.com/diniska/swiftui-system-colors", from: "1.1.0"),
        .package(url: "https://github.com/malcommac/SwiftDate", from: "7.0.0"),
        .package(url: "https://github.com/alin23/AppReceiptValidator.git", from: "1.1.4"),

        .package(url: "https://github.com/alin23/PaddleSPM", from: "4.4.2"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.2.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.9.3"),
        .package(url: "https://github.com/MacPaw/Setapp-framework", from: "4.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Lowtech",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "Magnet", package: "Magnet"),
                .product(name: "Sauce", package: "Sauce"),
                .product(name: "EonilFSEvents", package: "FSEvents"),
                .product(name: "DynamicColor", package: "DynamicColor"),
                .product(name: "SystemColors", package: "swiftui-system-colors"),
            ]
        ),
        .target(
            name: "LowtechAppStore",
            dependencies: [
                "Lowtech",
                .product(name: "SwiftDate", package: "SwiftDate"),
                .product(name: "AppReceiptValidator", package: "AppReceiptValidator"),
            ],
            exclude: ["Numbers.swift.secret"]

        ),
        .target(
            name: "LowtechSetapp",
            dependencies: [
                "Lowtech",
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "Setapp", package: "Setapp-framework"),
            ]
        ),
        .target(
            name: "LowtechIndie",
            dependencies: [
                "Lowtech",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .target(
            name: "LowtechPro",
            dependencies: [
                "LowtechIndie",
                .product(name: "Paddle", package: "PaddleSPM"),
                .product(name: "Sentry", package: "sentry-cocoa"),
            ]
        ),
    ]
)
