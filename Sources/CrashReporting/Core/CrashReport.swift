#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Structure representing a crash report
public struct CrashReport {
    /// Timestamp when the crash occurred
    public let timestamp: Date
    
    /// Signal that caused the crash (if applicable)
    public let signal: Int32?
    
    /// Optional reason for the crash (for manual reports)
    public let reason: String?
    
    /// Stack trace at the time of crash
    public let stackTrace: StackTrace
    
    /// Thread information at the time of crash
    public let threadInfo: ThreadInfo
    
    /// System information
    public let systemInfo: SystemInfo
    
    /// Application information
    public let applicationInfo: ApplicationInfo
    
    /// Initialize a new crash report
    /// - Parameters:
    ///   - timestamp: Timestamp when the crash occurred
    ///   - signal: Signal that caused the crash (if applicable)
    ///   - reason: Optional reason for the crash
    ///   - stackTrace: Stack trace at the time of crash
    ///   - threadInfo: Thread information at the time of crash
    ///   - systemInfo: System information
    ///   - applicationInfo: Application information
    public init(
        timestamp: Date,
        signal: Int32?,
        reason: String?,
        stackTrace: StackTrace,
        threadInfo: ThreadInfo,
        systemInfo: SystemInfo,
        applicationInfo: ApplicationInfo
    ) {
        self.timestamp = timestamp
        self.signal = signal
        self.reason = reason
        self.stackTrace = stackTrace
        self.threadInfo = threadInfo
        self.systemInfo = systemInfo
        self.applicationInfo = applicationInfo
    }
    
    /// Format the crash report as a string
    /// - Parameter format: Format to use
    /// - Returns: Formatted crash report
    public func formatted(format: CrashReportConfiguration.ReportFormat = .plainText) -> String {
        switch format {
        case .plainText:
            return formattedAsPlainText()
        case .json:
            return formattedAsJSON()
        case .xml:
            return formattedAsXML()
        }
    }
    
    // MARK: - Private Methods
    
    private func formattedAsPlainText() -> String {
        var report = """
        CRASH REPORT
        ============
        
        Date: \(formattedDate())
        
        """
        
        if let signal = signal {
            report += "Signal: \(signal) (\(signalName(for: signal)))\n"
        }
        
        if let reason = reason {
            report += "Reason: \(reason)\n"
        }
        
        report += """
        
        APPLICATION INFORMATION
        =====================
        Name: \(applicationInfo.name)
        Version: \(applicationInfo.version)
        Path: \(applicationInfo.path)
        
        SYSTEM INFORMATION
        =================
        CPU Architecture: \(systemInfo.cpuArchitecture)
        OS Name: \(systemInfo.osName)
        OS Version: \(systemInfo.osVersion)
        Kernel Version: \(systemInfo.kernelVersion)
        
        THREAD INFORMATION
        =================
        Current Thread ID: \(threadInfo.currentThreadID)
        Thread Count: \(threadInfo.threadCount)
        \(threadInfo.additionalInfo)
        
        STACK TRACE
        ==========
        \(stackTrace.frames.enumerated().map { index, frame in
            return "[\(index)] \(frame.symbolName ?? "<unknown symbol>") - \(frame.address)"
        }.joined(separator: "\n"))
        """
        
        return report
    }
    
    private func formattedAsJSON() -> String {
        // Simple JSON formatting for now
        // In a real implementation, use JSONEncoder
        let stackFrames = stackTrace.frames.enumerated().map { index, frame in
            return """
                {
                    "index": \(index),
                    "address": "\(frame.address)",
                    "symbolName": \(frame.symbolName != nil ? "\"\(frame.symbolName!)\"" : "null"),
                    "offset": \(frame.offset != nil ? "\(frame.offset!)" : "null"),
                    "fileName": \(frame.fileName != nil ? "\"\(frame.fileName!)\"" : "null"),
                    "lineNumber": \(frame.lineNumber != nil ? "\(frame.lineNumber!)" : "null")
                }
            """
        }.joined(separator: ",\n        ")
        
        return """
        {
            "timestamp": "\(formattedDate())",
            "signal": \(signal != nil ? "\(signal!)" : "null"),
            "signalName": \(signal != nil ? "\"\(signalName(for: signal!))\"" : "null"),
            "reason": \(reason != nil ? "\"\(reason!)\"" : "null"),
            "applicationInfo": {
                "name": "\(applicationInfo.name)",
                "version": "\(applicationInfo.version)",
                "path": "\(applicationInfo.path)"
            },
            "systemInfo": {
                "cpuArchitecture": "\(systemInfo.cpuArchitecture)",
                "osName": "\(systemInfo.osName)",
                "osVersion": "\(systemInfo.osVersion)",
                "kernelVersion": "\(systemInfo.kernelVersion)"
            },
            "threadInfo": {
                "currentThreadID": \(threadInfo.currentThreadID),
                "threadCount": \(threadInfo.threadCount),
                "additionalInfo": "\(threadInfo.additionalInfo.replacingOccurrences(of: "\"", with: "\\\""))"
            },
            "stackTrace": [
                \(stackFrames)
            ]
        }
        """
    }
    
    private func formattedAsXML() -> String {
        // Simple XML formatting
        let stackFrames = stackTrace.frames.enumerated().map { index, frame in
            return """
                <frame>
                    <index>\(index)</index>
                    <address>\(frame.address)</address>
                    <symbolName>\(frame.symbolName ?? "")</symbolName>
                    <offset>\(frame.offset ?? 0)</offset>
                    <fileName>\(frame.fileName ?? "")</fileName>
                    <lineNumber>\(frame.lineNumber ?? 0)</lineNumber>
                </frame>
            """
        }.joined(separator: "\n        ")
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <crashReport>
            <timestamp>\(formattedDate())</timestamp>
            <signal>\(signal ?? 0)</signal>
            <signalName>\(signal != nil ? signalName(for: signal!) : "")</signalName>
            <reason>\(reason ?? "")</reason>
            <applicationInfo>
                <name>\(applicationInfo.name)</name>
                <version>\(applicationInfo.version)</version>
                <path>\(applicationInfo.path)</path>
            </applicationInfo>
            <systemInfo>
                <cpuArchitecture>\(systemInfo.cpuArchitecture)</cpuArchitecture>
                <osName>\(systemInfo.osName)</osName>
                <osVersion>\(systemInfo.osVersion)</osVersion>
                <kernelVersion>\(systemInfo.kernelVersion)</kernelVersion>
            </systemInfo>
            <threadInfo>
                <currentThreadID>\(threadInfo.currentThreadID)</currentThreadID>
                <threadCount>\(threadInfo.threadCount)</threadCount>
                <additionalInfo><![CDATA[\(threadInfo.additionalInfo)]]></additionalInfo>
            </threadInfo>
            <stackTrace>
                \(stackFrames)
            </stackTrace>
        </crashReport>
        """
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    private func signalName(for signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT (Abort)"
        case SIGILL: return "SIGILL (Illegal Instruction)"
        case SIGSEGV: return "SIGSEGV (Segmentation Violation)"
        case SIGFPE: return "SIGFPE (Floating Point Exception)"
        case SIGBUS: return "SIGBUS (Bus Error)"
        case SIGPIPE: return "SIGPIPE (Broken Pipe)"
        default: return "Signal \(signal)"
        }
    }
}
