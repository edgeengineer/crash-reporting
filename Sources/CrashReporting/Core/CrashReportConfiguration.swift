#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Configuration options for crash reporting
public struct CrashReportConfiguration {
    /// Format of the crash report
    public enum ReportFormat {
        case plainText
        case json
        case xml
    }
    
    /// Level of detail in crash reports
    public enum DetailLevel {
        case minimal    // Basic information only
        case standard   // All required information
        case extended   // Additional diagnostics when available
    }
    
    /// Report format (default: .plainText)
    public var format: ReportFormat = .plainText
    
    /// Detail level (default: .standard)
    public var detailLevel: DetailLevel = .standard
    
    /// Maximum number of crash reports to keep (0 = unlimited)
    public var maxReports: Int = 10
    
    /// Whether to include symbolication when available
    public var includeSymbolication: Bool = true
    
    /// Public initializer with default values
    public init() {}
    
    /// Public initializer with custom values
    /// - Parameters:
    ///   - format: Report format
    ///   - detailLevel: Detail level
    ///   - maxReports: Maximum number of reports to keep
    ///   - includeSymbolication: Whether to include symbolication
    public init(
        format: ReportFormat,
        detailLevel: DetailLevel,
        maxReports: Int,
        includeSymbolication: Bool
    ) {
        self.format = format
        self.detailLevel = detailLevel
        self.maxReports = maxReports
        self.includeSymbolication = includeSymbolication
    }
}
