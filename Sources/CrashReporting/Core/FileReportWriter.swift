#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Implementation of CrashReportWriterProtocol that writes to a file
public class FileReportWriter: CrashReportWriterProtocol {
    /// Directory where crash reports will be stored
    private var directory: URL
    
    /// File extension for crash reports
    private let fileExtension: String
    
    /// Date formatter for file names
    private let dateFormatter: DateFormatter
    
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
    }
    
    /// Set the directory where crash reports will be stored
    /// - Parameter directory: Directory URL
    public func setDirectory(_ directory: URL) {
        self.directory = directory
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
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
        
        return "\(appName)_\(timestamp)_\(pid).\(fileExtension)"
    }
}
