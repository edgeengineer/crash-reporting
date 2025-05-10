#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Protocol for signal handler implementations
public protocol SignalHandlerProtocol {
    /// Register signal handlers with a callback
    /// - Parameter callback: Callback to invoke when a signal is received
    func registerSignalHandlers(callback: @escaping (Int32) -> Void)
    
    /// Unregister signal handlers
    func unregisterSignalHandlers()
    
    /// Raise a signal
    /// - Parameter signal: Signal to raise
    func raiseSignal(_ signal: Int32)
}

/// Protocol for stack trace generator implementations
public protocol StackTraceGeneratorProtocol {
    /// Generate a stack trace
    /// - Returns: Stack trace
    func generateStackTrace() -> StackTrace

    /// Generate a stack trace from an array of raw addresses.
    /// This is typically used for post-crash symbolication.
    /// - Parameter addresses: An array of raw frame pointer addresses.
    /// - Returns: Stack trace with symbolized frames where possible.
    func generateStackTrace(fromRawAddresses addresses: [UnsafeMutableRawPointer?]) -> StackTrace
}

/// Protocol for system information collector implementations
public protocol SystemInfoCollectorProtocol {
    /// Collect system information
    /// - Returns: System information
    func collectSystemInfo() -> SystemInfo
}

/// Protocol for thread information collector implementations
public protocol ThreadInfoCollectorProtocol {
    /// Collect thread information
    /// - Returns: Thread information
    func collectThreadInfo() -> ThreadInfo
}

/// Protocol for crash report writer implementations
public protocol CrashReportWriterProtocol {
    /// Write a crash report
    /// - Parameter report: Crash report to write
    /// - Returns: URL where the report was written, if successful
    func write(report: CrashReport) -> URL?
}
