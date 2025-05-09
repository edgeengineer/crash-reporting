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
    private var reportWriter: CrashReportWriterProtocol
    
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
    
    // MARK: - Private Methods
    
    private func handleCrash(signal: Int32) {
        let report = generateCrashReport(signal: signal)
        _ = reportWriter.write(report: report)
        
        // Re-raise the signal to let the default handler run
        signalHandler.raiseSignal(signal)
    }
    
    private func generateCrashReport(signal: Int32?, reason: String? = nil) -> CrashReport {
        let timestamp = Date()
        let stackTrace = stackTraceGenerator.generateStackTrace()
        let threadInfo = threadInfoCollector.collectThreadInfo()
        let systemInfo = systemInfoCollector.collectSystemInfo()
        
        return CrashReport(
            timestamp: timestamp,
            signal: signal,
            reason: reason,
            stackTrace: stackTrace,
            threadInfo: threadInfo,
            systemInfo: systemInfo,
            applicationInfo: appInfo
        )
    }
}
