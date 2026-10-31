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
            name: "LowtechIndie",
            targets: ["LowtechIndie"]
        ),
        .library(
            name: "LowtechPro",
            targets: ["LowtechPro"]
        ),
        .library(
            name: "LowtechProSentry",
            targets: ["LowtechProSentry"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.0"),
        .package(url: "https://github.com/apple/swift-atomics", from: "1.0.2"),
        .package(url: "https://github.com/FuzzyIdeas/LaunchAtLogin", from: "1.2.0"),
        .package(url: "https://github.com/alin23/Magnet", from: "4.2.0"),
        .package(url: "https://github.com/Clipy/Sauce", from: "2.5.2"),
        .package(url: "https://github.com/yannickl/DynamicColor", from: "5.0.1"),
        .package(url: "https://github.com/diniska/swiftui-system-colors", from: "1.1.0"),

        .package(url: "https://github.com/alin23/PaddleSPM", from: "4.5.5"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.2.0"),
    ],
    targets: [
        .target(
            name: "Lowtech",
            dependencies: [
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Defaults", package: "Defaults"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin"),
                .product(name: "Magnet", package: "Magnet"),
                .product(name: "Sauce", package: "Sauce"),
                .product(name: "DynamicColor", package: "DynamicColor"),
                .product(name: "SystemColors", package: "swiftui-system-colors"),
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
            ]
        ),
        .target(
            name: "LowtechProSentry",
            dependencies: [
                "Lowtech",
                "Sentry",
            ],
            // Replaces sentry-cocoa's SentryCppHelper, an empty target that only links libc++
            linkerSettings: [.linkedLibrary("c++")]
        ),
        // macOS-only slice of sentry-cocoa's static Sentry.xcframework, built by Scripts/slim-sentry.sh.
        // Depending on sentry-cocoa directly makes SwiftPM download all 7 of its xcframeworks
        // for every platform, about 2.9 GB per DerivedData folder.
        .binaryTarget(
            name: "Sentry",
            url: "https://files.lowtechguys.com/Sentry-macOS-9.31.0.xcframework.zip",
            checksum: "1cacfe4f61d75c8e6ead621ec267c1c267788cce095568cbb02a2a65d10a3ade"
        ),
    ]
)
