#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
private let systemWrite: @Sendable (Int32, UnsafeRawPointer?, Int) -> Int = Darwin.write
private let systemOpen: @Sendable (UnsafePointer<CChar>, Int32, mode_t) -> Int32 = Darwin.open
private let systemClose: @Sendable (Int32) -> Int32 = Darwin.close
#elseif os(Linux)
import Glibc
private let systemWrite: @Sendable (Int32, UnsafeRawPointer?, Int) -> Int = Glibc.write
private let systemOpen: @Sendable (UnsafePointer<CChar>, Int32, mode_t) -> Int32 = Glibc.open
private let systemClose: @Sendable (Int32) -> Int32 = Glibc.close
#else
#error("Unsupported platform for FileReportWriter low-level system calls")
#endif

/// Implementation of CrashReportWriterProtocol that writes to a file
public class FileReportWriter: CrashReportWriterProtocol {
    /// Directory where crash reports will be stored
    private var directory: URL
    
    /// File extension for crash reports
    private let fileExtension: String
    
    /// Date formatter for file names
    private let dateFormatter: DateFormatter
    
    private var rawCrashLogFD: Int32? = nil
    private let rawCrashLogName = "pending_crash.txt" // Fixed name for the raw log

    /// Initialize a new file report writer
    /// - Parameters:
    ///   - directory: Directory where crash reports will be stored (defaults to temporary directory)
    ///   - fileExtension: File extension for crash reports (defaults to "crash")
    public init(
        directory: URL? = nil,
        fileExtension: String = "crash"
    ) {
        self.directory = directory ?? FileManager.default.temporaryDirectory
        self.fileExtension = fileExtension
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        setupRawCrashLogFile()
    }
    
    /// Set the directory where crash reports will be stored
    /// - Parameter directory: Directory URL
    public func setDirectory(_ directory: URL) {
        self.directory = directory
        
        // Create directory if it doesn't exist (safe here, not in signal handler)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        setupRawCrashLogFile()
    }

    private func setupRawCrashLogFile() {
        if let existingFD = rawCrashLogFD {
            _ = systemClose(existingFD) // Use systemClose, silence unused result warning
            rawCrashLogFD = nil
        }
        
        let filePath = directory.appendingPathComponent(rawCrashLogName).path
        let fd = systemOpen(filePath, O_RDWR | O_CREAT | O_TRUNC, S_IRWXU) // Use systemOpen
        if fd == -1 {
            self.rawCrashLogFD = nil
        } else {
            self.rawCrashLogFD = fd
        }
    }
    
    // New method for attempting safer (binary for dynamic parts) async-signal-safe writing
    public func writeMinimal(signal: Int32, timestamp: time_t, addresses: UnsafePointer<UnsafeMutableRawPointer?>, frameCount: Int, threadID: UInt64) {
        guard let fd = rawCrashLogFD, fd != -1 else {
            return // Cannot write if FD is not valid
        }

        let testString: StaticString = "TEST_WRITE_FROM_SIGNAL_HANDLER_SIGABRT_ATTEMPT\n" // Changed message
    
        testString.withUTF8Buffer { bufferPtr in
            if let baseAddress = bufferPtr.baseAddress, bufferPtr.count > 0 {
                _ = systemWrite(fd, baseAddress, bufferPtr.count) // Write to rawCrashLogFD
            }
        }
        
        // Try to flush the file descriptor. fsync is async-signal-safe.
        _ = fsync(fd) 
    }
    
    // This method is NOT async-signal-safe. It is for testing the post-processor.
    public func simulatePendingCrashTxt(signal: Int32, timestamp: time_t, threadID: UInt64, frameAddresses: [UnsafeMutableRawPointer?]) throws {
        let filePath = directory.appendingPathComponent(rawCrashLogName) // rawCrashLogName is "pending_crash.txt"
        
        var content = "Signal: \(signal)\n"
        content += "Timestamp: \(Int64(timestamp))\n" // Store as Int64 for easier parsing
        content += "ThreadID: \(threadID)\n"
        
        if !frameAddresses.isEmpty {
            content += "Frames:\n" // Renamed for clarity from "Frames (raw addresses):"
            for addr in frameAddresses {
                if let actualAddr = addr {
                    let ptrValue = UInt(bitPattern: actualAddr)
                    content += "  0x" + String(ptrValue, radix: 16, uppercase: false) + "\n"
                } else {
                    content += "  0x0 (nil)\n" // Represent nil addresses
                }
            }
        }
        content += "--- End of Raw Report ---\n" // Consistent footer
        
        try content.write(to: filePath, atomically: true, encoding: .utf8)
        print("FileReportWriter: Simulated pending_crash.txt created/updated at \(filePath.path)")
    }
    
    /// Write a crash report to a file
    /// - Parameter report: Crash report to write
    /// - Returns: URL where the report was written, if successful
    public func write(report: CrashReport) -> URL? {
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        
        // Generate file name
        let fileName = generateFileName(for: report)
        let fileURL = directory.appendingPathComponent(fileName)
        
        // Format report
        let reportContent = report.formatted(format: .plainText)
        
        // Write to temporary file first
        let tempFileURL = directory.appendingPathComponent("temp_\(UUID().uuidString).\(fileExtension)")
        
        do {
            try reportContent.write(to: tempFileURL, atomically: false, encoding: .utf8)
            
            // Move to final destination
            try FileManager.default.moveItem(at: tempFileURL, to: fileURL)
            
            return fileURL
        } catch {
            // Clean up temporary file if it exists
            try? FileManager.default.removeItem(at: tempFileURL)
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func generateFileName(for report: CrashReport) -> String {
        let timestamp = dateFormatter.string(from: report.timestamp)
        let appName = report.applicationInfo.name.replacingOccurrences(of: " ", with: "_")
        let pid = ProcessInfo.processInfo.processIdentifier
        let uniqueID = UUID().uuidString.prefix(8) // Add a short UUID to ensure uniqueness
        
        return "\(appName)_\(timestamp)_\(pid)_\(uniqueID).\(fileExtension)"
    }
}


