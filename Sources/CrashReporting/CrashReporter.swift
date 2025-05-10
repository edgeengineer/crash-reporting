#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SystemPackage

/// Main class for crash reporting functionality
public final class CrashReporter: @unchecked Sendable {
    /// Singleton instance
    public static let shared = CrashReporter()
    
    // MARK: - Properties
    
    /// Configuration for the crash reporter
    private var configuration: CrashReportConfiguration
    
    /// Signal handler manager
    private let signalHandler: SignalHandlerProtocol
    
    /// Stack trace generator
    private let stackTraceGenerator: StackTraceGeneratorProtocol
    
    /// System information collector
    private let systemInfoCollector: SystemInfoCollectorProtocol
    
    /// Thread information collector
    private let threadInfoCollector: ThreadInfoCollectorProtocol
    
    /// Application information
    private var appInfo: ApplicationInfo
    
    /// Report writer
    public var reportWriter: CrashReportWriterProtocol
    
    /// Directory where crash reports will be stored
    private var crashReportDirectory: URL?
    
    /// Flag indicating if signal handlers are installed
    private var handlersInstalled = false
    
    // MARK: - Initialization
    
    private init() {
        self.configuration = CrashReportConfiguration()
        
        #if os(macOS)
        self.signalHandler = MacOSSignalHandler()
        self.stackTraceGenerator = MacOSStackTraceGenerator()
        self.systemInfoCollector = MacOSSystemInfoCollector()
        self.threadInfoCollector = MacOSThreadInfoCollector()
        #elseif os(Linux)
        self.signalHandler = LinuxSignalHandler()
        self.stackTraceGenerator = LinuxStackTraceGenerator()
        self.systemInfoCollector = LinuxSystemInfoCollector()
        self.threadInfoCollector = LinuxThreadInfoCollector()
        #else
        #error("Unsupported platform")
        #endif
        
        self.appInfo = ApplicationInfo(
            name: ProcessInfo.processInfo.processName,
            version: "Unknown",
            path: CommandLine.arguments.first ?? "Unknown"
        )
        
        self.reportWriter = FileReportWriter()
    }
    
    // MARK: - Public Methods
    
    /// Configure the crash reporter
    /// - Parameters:
    ///   - applicationName: Name of the application
    ///   - applicationVersion: Version of the application
    ///   - applicationPath: Path to the application executable
    ///   - crashReportDirectory: Directory where crash reports will be stored
    public func configure(
        applicationName: String,
        applicationVersion: String,
        applicationPath: String? = nil,
        crashReportDirectory: URL? = nil
    ) {
        self.appInfo = ApplicationInfo(
            name: applicationName,
            version: applicationVersion,
            path: applicationPath ?? CommandLine.arguments.first ?? "Unknown"
        )
        
        if let crashReportDirectory = crashReportDirectory {
            self.crashReportDirectory = crashReportDirectory
            
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(
                at: crashReportDirectory,
                withIntermediateDirectories: true
            )
        } else {
            // Default to temporary directory
            self.crashReportDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("CrashReports", isDirectory: true)
            
            try? FileManager.default.createDirectory(
                at: self.crashReportDirectory!,
                withIntermediateDirectories: true
            )
        }
        
        // Configure the report writer
        if let reportWriter = self.reportWriter as? FileReportWriter {
            reportWriter.setDirectory(self.crashReportDirectory!)
        }
    }
    
    /// Set configuration options for the crash reporter
    /// - Parameter configuration: Configuration options
    public func setConfiguration(_ configuration: CrashReportConfiguration) {
        self.configuration = configuration
    }
    
    /// Set a custom report writer
    /// - Parameter writer: The report writer to use
    public func setReportWriter(_ writer: CrashReportWriterProtocol) {
        self.reportWriter = writer
        
        if let fileWriter = writer as? FileReportWriter,
           let directory = self.crashReportDirectory {
            fileWriter.setDirectory(directory)
        }
    }
    
    /// Install signal handlers to automatically catch crashes
    public func installHandlers() {
        guard !handlersInstalled else { return }
        
        signalHandler.registerSignalHandlers { [weak self] signal in
            guard let self = self else { return }
            self.handleCrash(signal: signal)
        }
        
        handlersInstalled = true
    }
    
    /// Uninstall signal handlers (call before application exit)
    public func uninstallHandlers() {
        guard handlersInstalled else { return }
        
        signalHandler.unregisterSignalHandlers()
        handlersInstalled = false
    }
    
    /// Manually write a crash report (for testing or manually triggered reports)
    /// - Parameter reason: Optional reason for the crash
    /// - Returns: URL where the report was written
    @discardableResult
    public func writeCrashReport(reason: String? = nil) -> URL? {
        let report = generateCrashReport(signal: nil, reason: reason)
        return reportWriter.write(report: report)
    }
    
    /// Simulate a signal for testing purposes
    /// - Parameter signal: The signal to simulate
    /// - Returns: URL where the report was written
    @discardableResult
    public func simulateSignal(_ signal: Int32) -> URL? {
        let report = generateCrashReport(signal: signal, reason: "Simulated signal")
        return reportWriter.write(report: report)
    }

    // New method to process a pending raw crash log
    public func processPendingRawCrashReport() -> URL? {
        guard let reportDir = self.crashReportDirectory, 
              let _ = self.reportWriter as? FileReportWriter else { // Changed fileWriter to _
            print("CrashReporter: Report directory not set or reportWriter is not FileReportWriter (cannot determine rawLogName path component).")
            return nil 
        }
        
        // Access rawCrashLogName - this requires rawCrashLogName to be accessible, e.g. internal or public in FileReportWriter
        // For now, we'll hardcode it here, but ideally FileReportWriter would expose it or a method to get the path.
        // This assumes FileReportWriter.rawCrashLogName is "pending_crash.txt"
        let rawLogName = "pending_crash.txt" 
        let rawReportURL = reportDir.appendingPathComponent(rawLogName)

        guard FileManager.default.fileExists(atPath: rawReportURL.path) else {
            // print("No pending raw crash log found at \(rawReportURL.path)")
            return nil
        }

        do {
            print("CrashReporter: Processing pending raw crash log: \(rawReportURL.path)")
            let content = try String(contentsOf: rawReportURL)
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false) // Keep empty lines if any, for structure

            var parsedSignal: Int32? = nil
            var parsedTimestamp: time_t? = nil
            var parsedThreadID: UInt64? = nil
            var parsedFrames = [UnsafeMutableRawPointer?]()
            var readingFrames = false

            for lineSubstring in lines {
                let line = String(lineSubstring)
                if line.hasPrefix("Signal: ") {
                    if let val = Int32(line.dropFirst("Signal: ".count).trimmingCharacters(in: .whitespaces)) {
                        parsedSignal = val
                    }
                } else if line.hasPrefix("Timestamp: ") { // Matched the simulated format
                    if let val = Int64(line.dropFirst("Timestamp: ".count).trimmingCharacters(in: .whitespaces)) {
                         parsedTimestamp = time_t(val)
                    }
                } else if line.hasPrefix("ThreadID: ") {
                    if let val = UInt64(line.dropFirst("ThreadID: ".count).trimmingCharacters(in: .whitespaces)) {
                        parsedThreadID = val
                    }
                } else if line.hasPrefix("Frames:") { // Matched the simulated format
                    readingFrames = true
                } else if readingFrames && line.hasPrefix("  0x") {
                    let hexString = String(line.trimmingCharacters(in: .whitespaces).dropFirst("0x".count))
                    if let addrVal = UInt(hexString, radix: 16) {
                        parsedFrames.append(UnsafeMutableRawPointer(bitPattern: addrVal))
                    }
                } else if readingFrames && line.hasPrefix("  0x0 (nil)") {
                    parsedFrames.append(nil)
                } else if line.contains("--- End of Raw Report ---") {
                    readingFrames = false // Stop reading frames
                }
            }

            if let sig = parsedSignal { // Signal is the most critical piece of info from the raw log
                let fullReport = generateCrashReport(
                    signal: sig,
                    reason: "Crash (recovered from raw log)",
                    rawTimestamp: parsedTimestamp,
                    rawCrashingThreadID: parsedThreadID,
                    rawStackAddresses: parsedFrames.isEmpty ? nil : parsedFrames
                )
                
                let finalReportURL = self.reportWriter.write(report: fullReport) // Uses the original, full write method
                
                try? FileManager.default.removeItem(at: rawReportURL) // Clean up the raw log
                
                print("CrashReporter: Successfully processed raw log. Full report at: \(finalReportURL?.path ?? "unknown")")
                return finalReportURL
            } else {
                print("CrashReporter: Failed to parse essential data (Signal) from raw log: \(rawReportURL.path). Deleting raw log.")
                try? FileManager.default.removeItem(at: rawReportURL)
                return nil
            }
        } catch {
            print("CrashReporter: Error processing raw crash log at \(rawReportURL.path): \(error). Deleting raw log.")
            try? FileManager.default.removeItem(at: rawReportURL)
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func handleCrash(signal: Int32) {
        // --- Async-Signal-Safe Data Collection --- 
        // 1. Get raw timestamp (async-signal-safe)
        var currentTime: time_t = 0
        time(&currentTime) // time(nil) is generally safe

        // 2. Get raw backtrace (async-signal-safe)
        let maxStackFrames = 128 // Or from configuration
        let addresses = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: maxStackFrames)
        let frameCount = backtrace(addresses, Int32(maxStackFrames))

        // 3. Get crashing thread ID (raw, be cautious with further processing here)
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        let platformThreadID = UInt64(pthread_mach_thread_np(pthread_self())) // mach_port_t is UInt32
        #elseif os(Linux)        
        // On Linux, pthread_t is opaque. For a simple numeric ID for logging:
        // This gets an address-like integer. Not guaranteed unique across processes or runs but unique for a thread in process.
        let rawPthreadT = pthread_self()
        let platformThreadID = UInt64(bitPattern: UnsafeRawPointer(bitPattern: rawPthreadT))
        #else
        let platformThreadID: UInt64 = 0 // Placeholder for unsupported platforms
        #endif

        // Call the new minimal writer method
        if let writer = self.reportWriter as? FileReportWriter { // Or a more generic protocol if you abstract this
            writer.writeMinimal(signal: signal, 
                                timestamp: currentTime, 
                                addresses: addresses, 
                                frameCount: Int(frameCount), 
                                threadID: platformThreadID)
        } else {
            // TODO: What to do if the reportWriter doesn't support minimal writing?
            // For now, nothing, as the primary goal is safety in the handler.
        }

        addresses.deallocate()

        // --- End of Async-Signal-Safe Data Collection ---

        // DO NOT CALL these in a real signal handler for an actual crash:
        // let report = generateCrashReport(signal: signal) // UNSAFE
        // _ = reportWriter.write(report: report) // UNSAFE
        
        // Re-raise the signal to let the default handler run (and terminate the process)
        signalHandler.raiseSignal(signal)
    }
    
    private func generateCrashReport(
        signal: Int32?,
        reason: String? = nil,
        // New optional parameters for post-processing
        rawTimestamp: time_t? = nil,
        rawCrashingThreadID: UInt64? = nil,
        rawStackAddresses: [UnsafeMutableRawPointer?]? = nil
    ) -> CrashReport {

        let finalTimestamp: Date
        if let rawTs = rawTimestamp {
            finalTimestamp = Date(timeIntervalSince1970: TimeInterval(rawTs))
        } else {
            finalTimestamp = Date() // Live timestamp if no raw one provided
        }

        let finalStackTrace: StackTrace
        if let rawAddrs = rawStackAddresses, !rawAddrs.isEmpty {
            // Call the new protocol method to get a symbolized stack trace from raw addresses
            finalStackTrace = stackTraceGenerator.generateStackTrace(fromRawAddresses: rawAddrs)
        } else {
            // If no raw addresses, generate a live stack trace (e.g., for manual reports or simulated signals)
            finalStackTrace = stackTraceGenerator.generateStackTrace()
        }

        // Use live system info for now. Could be enhanced to parse from raw log if needed.
        let currentSystemInfo = systemInfoCollector.collectSystemInfo()

        // Use live general thread info, but override currentThreadID if raw one is provided.
        var currentThreadInfo = threadInfoCollector.collectThreadInfo()
        if let crashedTID = rawCrashingThreadID {
            currentThreadInfo = ThreadInfo(currentThreadID: crashedTID, 
                                         threadCount: currentThreadInfo.threadCount, // This is live count
                                         additionalInfo: currentThreadInfo.additionalInfo) // This is live info
        }
        
        return CrashReport(
            timestamp: finalTimestamp,
            signal: signal,
            reason: reason,
            stackTrace: finalStackTrace,
            threadInfo: currentThreadInfo,
            systemInfo: currentSystemInfo,
            applicationInfo: appInfo
        )
    }
}
