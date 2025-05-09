#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Darwin

#if os(macOS)
/// Thread information collector implementation for macOS
public class MacOSThreadInfoCollector: ThreadInfoCollectorProtocol {
    /// Initialize a new macOS thread information collector
    public init() {}
    
    /// Collect thread information
    /// - Returns: Thread information
    public func collectThreadInfo() -> ThreadInfo {
        // Get current thread ID
        let currentThreadID = UInt64(pthread_mach_thread_np(pthread_self()))
        
        // Get thread count
        let threadCount = getThreadCount()
        
        // Get additional thread information
        let additionalInfo = getAdditionalThreadInfo()
        
        return ThreadInfo(
            currentThreadID: currentThreadID,
            threadCount: threadCount,
            additionalInfo: additionalInfo
        )
    }
    
    // MARK: - Private Methods
    
    /// Get the number of threads in the current process
    /// - Returns: Thread count
    private func getThreadCount() -> Int {
        // Get the task port for the current process
        let taskPort = mach_task_self_
        
        // Get thread list
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(taskPort, &threadList, &threadCount)
        
        if result == KERN_SUCCESS, let threadList = threadList {
            // Deallocate the thread list when done
            defer {
                let _ = vm_deallocate(
                    taskPort,
                    vm_address_t(UInt(bitPattern: threadList)),
                    vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_act_t>.size)
                )
            }
            
            return Int(threadCount)
        }
        
        // Return 1 if we couldn't get the thread count
        return 1
    }
    
    /// Get additional thread information
    /// - Returns: Additional thread information as a string
    private func getAdditionalThreadInfo() -> String {
        var info = ""
        
        // Get the task port for the current process
        let taskPort = mach_task_self_
        
        // Get thread list
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(taskPort, &threadList, &threadCount)
        
        if result == KERN_SUCCESS, let threadList = threadList {
            // Deallocate the thread list when done
            defer {
                let _ = vm_deallocate(
                    taskPort,
                    vm_address_t(UInt(bitPattern: threadList)),
                    vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_act_t>.size)
                )
            }
            
            // Get information for each thread
            for i in 0..<threadCount {
                let thread = threadList[Int(i)]
                
                // Get thread basic info
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<natural_t>.size)
                let threadInfoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                        thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                if threadInfoResult == KERN_SUCCESS {
                    // Format thread info
                    let threadID = UInt64(thread)
                    let cpuUsage = Float(threadInfo.cpu_usage) / Float(TH_USAGE_SCALE) * 100.0
                    
                    // Determine thread state
                    var stateString = "Unknown"
                    switch threadInfo.run_state {
                    case TH_STATE_RUNNING:
                        stateString = "Running"
                    case TH_STATE_STOPPED:
                        stateString = "Stopped"
                    case TH_STATE_WAITING:
                        stateString = "Waiting"
                    case TH_STATE_UNINTERRUPTIBLE:
                        stateString = "Uninterruptible"
                    case TH_STATE_HALTED:
                        stateString = "Halted"
                    default:
                        stateString = "Unknown"
                    }
                    
                    // Add thread info to the result
                    info += "Thread \(threadID): State=\(stateString), CPU=\(String(format: "%.1f%%", cpuUsage))\n"
                }
            }
        }
        
        return info
    }
}
#endif
