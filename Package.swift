// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CrashReporting",
    platforms: [
        .macOS(.v13),
        // Add Linux support if not already present for platform versions
        // .linux(.v5_6) // Example
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
        .package(url: "https://github.com/apple/swift-system.git", from: "1.4.0"),
        // .package(url: "https://github.com/apple/swift-testing.git", from: "0.3.0") // Still removed
    ],
    targets: [
        .target(
            name: "CSignalHelpers",
            dependencies: [],
            path: "Sources/CSignalHelpers",
            publicHeadersPath: "include" // Ensures CSignalHelpers.h is found by Swift targets
        ),
        .target(
            name: "CrashReporting",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                "CSignalHelpers" // Depend on the C target
            ],
            path: "Sources/CrashReporting", // Assuming CrashReporting Swift files are directly in here
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "CrashTester",
            dependencies: ["CrashReporting"],
            path: "Sources/CrashTester"
        ),
        .testTarget(
            name: "CrashReportingTests",
            dependencies: ["CrashReporting"],
            path: "Tests/CrashReportingTests"
        ),
    ]
)
