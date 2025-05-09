#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(Linux)
/// Thread information collector implementation for Linux
public class LinuxThreadInfoCollector: ThreadInfoCollectorProtocol {
    /// Initialize a new Linux thread information collector
    public init() {}
    
    /// Collect thread information
    /// - Returns: Thread information
    public func collectThreadInfo() -> ThreadInfo {
        // Get current thread ID
        let currentThreadID = UInt64(pthread_self())
        
        // Get thread count and additional info
        let (threadCount, additionalInfo) = getThreadInfo()
        
        return ThreadInfo(
            currentThreadID: currentThreadID,
            threadCount: threadCount,
            additionalInfo: additionalInfo
        )
    }
    
    // MARK: - Private Methods
    
    /// Get thread count and additional information
    /// - Returns: Tuple with thread count and additional information
    private func getThreadInfo() -> (Int, String) {
        var threadCount = 1
        var additionalInfo = ""
        
        // Try to get thread information from /proc/self/task
        let taskDirURL = URL(fileURLWithPath: "/proc/self/task")
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: taskDirURL, includingPropertiesForKeys: nil)
            
            // Count the number of thread directories
            threadCount = contents.count
            
            // Get information about each thread
            for threadDir in contents {
                let threadID = threadDir.lastPathComponent
                
                // Try to get thread status
                let statusURL = threadDir.appendingPathComponent("status")
                if let statusContent = try? String(contentsOf: statusURL, encoding: .utf8) {
                    let lines = statusContent.split(separator: "\n")
                    
                    var threadName = "Thread \(threadID)"
                    var threadState = "Unknown"
                    
                    for line in lines {
                        if line.hasPrefix("Name:") {
                            let components = line.split(separator: ":")
                            if components.count > 1 {
                                threadName = components[1].trimmingCharacters(in: .whitespaces)
                            }
                        } else if line.hasPrefix("State:") {
                            let components = line.split(separator: ":")
                            if components.count > 1 {
                                threadState = components[1].trimmingCharacters(in: .whitespaces)
                            }
                            break
                        }
                    }
                    
                    additionalInfo += "\(threadName) (ID: \(threadID)): State=\(threadState)\n"
                } else {
                    additionalInfo += "Thread \(threadID): No status information available\n"
                }
            }
        } catch {
            // If we can't access the task directory, fall back to a simpler approach
            additionalInfo = "Thread information not available. Error: \(error.localizedDescription)"
        }
        
        return (threadCount, additionalInfo)
    }
}
#endif
