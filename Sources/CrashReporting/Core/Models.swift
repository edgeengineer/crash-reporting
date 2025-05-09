#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: - Stack Trace Models

/// Represents a stack trace with frames
public struct StackTrace {
    /// Individual frames in the stack trace
    public let frames: [StackFrame]
    
    /// Initialize a new stack trace
    /// - Parameter frames: Stack frames
    public init(frames: [StackFrame]) {
        self.frames = frames
    }
}

/// Represents a single frame in a stack trace
public struct StackFrame {
    /// Memory address of the frame
    public let address: String
    
    /// Symbol name (function name), if available
    public let symbolName: String?
    
    /// Offset from the symbol start, if available
    public let offset: Int?
    
    /// Source file name, if available
    public let fileName: String?
    
    /// Source line number, if available
    public let lineNumber: Int?
    
    /// Initialize a new stack frame
    /// - Parameters:
    ///   - address: Memory address of the frame
    ///   - symbolName: Symbol name (function name), if available
    ///   - offset: Offset from the symbol start, if available
    ///   - fileName: Source file name, if available
    ///   - lineNumber: Source line number, if available
    public init(
        address: String,
        symbolName: String? = nil,
        offset: Int? = nil,
        fileName: String? = nil,
        lineNumber: Int? = nil
    ) {
        self.address = address
        self.symbolName = symbolName
        self.offset = offset
        self.fileName = fileName
        self.lineNumber = lineNumber
    }
}

// MARK: - System Information Model

/// Represents system information
public struct SystemInfo {
    /// CPU architecture
    public let cpuArchitecture: String
    
    /// Operating system name
    public let osName: String
    
    /// Operating system version
    public let osVersion: String
    
    /// Kernel version
    public let kernelVersion: String
    
    /// Additional system information as key-value pairs
    public let additionalInfo: [String: String]
    
    /// Initialize system information
    /// - Parameters:
    ///   - cpuArchitecture: CPU architecture
    ///   - osName: Operating system name
    ///   - osVersion: Operating system version
    ///   - kernelVersion: Kernel version
    ///   - additionalInfo: Additional system information
    public init(
        cpuArchitecture: String,
        osName: String,
        osVersion: String,
        kernelVersion: String,
        additionalInfo: [String: String] = [:]
    ) {
        self.cpuArchitecture = cpuArchitecture
        self.osName = osName
        self.osVersion = osVersion
        self.kernelVersion = kernelVersion
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Thread Information Model

/// Represents thread information
public struct ThreadInfo {
    /// Current thread identifier
    public let currentThreadID: UInt64
    
    /// Total number of threads
    public let threadCount: Int
    
    /// Additional thread information as a string
    public let additionalInfo: String
    
    /// Initialize thread information
    /// - Parameters:
    ///   - currentThreadID: Current thread identifier
    ///   - threadCount: Total number of threads
    ///   - additionalInfo: Additional thread information
    public init(
        currentThreadID: UInt64,
        threadCount: Int,
        additionalInfo: String = ""
    ) {
        self.currentThreadID = currentThreadID
        self.threadCount = threadCount
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Application Information Model

/// Represents application information
public struct ApplicationInfo {
    /// Application name
    public let name: String
    
    /// Application version
    public let version: String
    
    /// Path to the application executable
    public let path: String
    
    /// Initialize application information
    /// - Parameters:
    ///   - name: Application name
    ///   - version: Application version
    ///   - path: Path to the application executable
    public init(
        name: String,
        version: String,
        path: String
    ) {
        self.name = name
        self.version = version
        self.path = path
    }
}
