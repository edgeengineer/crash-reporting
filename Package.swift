// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CrashReporting",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CrashReporting",
            targets: ["CrashReporting"]),
        .executable(
            name: "CrashTester",
            targets: ["CrashTester"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system.git", from: "1.4.0")
    ],
    targets: [
        // Main library target
        .target(
            name: "CrashReporting",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        // Test executable for crash testing
        .executableTarget(
            name: "CrashTester",
            dependencies: ["CrashReporting"]
        ),
        // Test target
        .testTarget(
            name: "CrashReportingTests",
            dependencies: [
                "CrashReporting"
            ]
        ),
    ]
)
