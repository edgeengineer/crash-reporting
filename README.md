# Crash Reporting

> **⚠️ IMPORTANT:** This repository is under active development and is not ready for production use. APIs may change without notice.

[![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![macOS](https://img.shields.io/github/actions/workflow/status/apache-edge/crash-reporting/swift.yml?branch=main&label=macOS)](https://github.com/apache-edge/crash-reporting/actions/workflows/swift.yml)
[![Linux](https://img.shields.io/github/actions/workflow/status/apache-edge/crash-reporting/swift.yml?branch=main&label=Linux)](https://github.com/apache-edge/crash-reporting/actions/workflows/swift.yml)
[![Documentation](https://img.shields.io/badge/Documentation-DocC-blue)](https://apache-edge.github.io/crash-reporting/documentation/crash-reporting/)

## Overview

This is a Cross Platform Swift 6.1 and higher library for crash reporting. It support macOS and Linux. Windows support is planned but not supported currently.

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/apache-edge/crash-reporting.git", from: "0.0.1"),
]
```

Then add the following to your `Package.swift` file:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["CrashReporting"]),
]
```

## Features

- Writes crash reports to a file with the following information:
    - Date and time of the crash
    - Stack trace
    - Thread information
    - System information
        - CPU architecture
        - OS Name
        - OS version
        - Kernel version
    - Application information
        - Application name
        - Application version
        - Application path
- Specify a file path to store the crash report

## Usage

### Basic Usage

```swift
import CrashReporting

// Configure at application startup
CrashReporter.shared.configure(
    applicationName: "MyApp",
    applicationVersion: "1.0.0",
    crashReportDirectory: URL(fileURLWithPath: "/path/to/crashes")
)

// Install signal handlers
CrashReporter.shared.installHandlers()

// When application exits
defer {
    CrashReporter.shared.uninstallHandlers()
}
```

### Advanced Configuration

```swift
import CrashReporting

// Create and configure custom options
let config = CrashReportConfiguration()
config.format = .json
config.detailLevel = .extended
config.maxReports = 5
config.includeSymbolication = true

// Apply configuration
CrashReporter.shared.setConfiguration(config)

// Configure the crash reporter
CrashReporter.shared.configure(
    applicationName: "MyApp",
    applicationVersion: "1.0.0",
    crashReportDirectory: URL(fileURLWithPath: "/path/to/crashes")
)

// Install signal handlers
CrashReporter.shared.installHandlers()
```

### Manual Crash Reports

You can also generate crash reports manually without an actual crash:

```swift
// Generate a crash report with a custom reason
let reportURL = CrashReporter.shared.writeCrashReport(reason: "Manual crash report")
print("Crash report written to: \(reportURL?.path ?? "unknown")")
```

### Simulating Signals

For testing purposes, you can simulate a signal without actually crashing:

```swift
// Simulate a segmentation fault
let reportURL = CrashReporter.shared.simulateSignal(SIGSEGV)
print("Crash report written to: \(reportURL?.path ?? "unknown")")
```

## Testing

The library includes a `CrashTester` executable that can be used to test crash reporting functionality:

```bash
# Run with a specific crash type
./.build/debug/CrashTester segfault /path/to/crash/reports

# Available crash types
# - segfault (or sigsegv)
# - abort (or sigabrt)
# - divide-by-zero (or sigfpe)
# - illegal-instruction (or sigill)
# - bus-error (or sigbus)
# - manual (generates a report without crashing)
```

## API Reference

### CrashReporter

The main class for crash reporting functionality.

```swift
public class CrashReporter {
    /// Singleton instance
    public static let shared: CrashReporter
    
    /// Configure the crash reporter
    public func configure(
        applicationName: String,
        applicationVersion: String,
        applicationPath: String? = nil,
        crashReportDirectory: URL? = nil
    )
    
    /// Set configuration options
    public func setConfiguration(_ configuration: CrashReportConfiguration)
    
    /// Set a custom report writer
    public func setReportWriter(_ writer: CrashReportWriterProtocol)
    
    /// Install signal handlers
    public func installHandlers()
    
    /// Uninstall signal handlers
    public func uninstallHandlers()
    
    /// Manually write a crash report
    @discardableResult
    public func writeCrashReport(reason: String? = nil) -> URL?
    
    /// Simulate a signal for testing
    @discardableResult
    public func simulateSignal(_ signal: Int32) -> URL?
}
```

### CrashReportConfiguration

Configuration options for crash reporting.

```swift
public struct CrashReportConfiguration {
    /// Report format (plainText, json, xml)
    public var format: ReportFormat
    
    /// Detail level (minimal, standard, extended)
    public var detailLevel: DetailLevel
    
    /// Maximum number of crash reports to keep
    public var maxReports: Int
    
    /// Whether to include symbolication when available
    public var includeSymbolication: Bool
}
```

## Platform Support

- **macOS**: Fully supported
- **Linux**: Fully supported
- **Windows**: Planned for future releases

## License

Apache License 2.0
