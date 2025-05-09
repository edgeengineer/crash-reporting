#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(Linux)
/// System information collector implementation for Linux
public class LinuxSystemInfoCollector: SystemInfoCollectorProtocol {
    /// Initialize a new Linux system information collector
    public init() {}
    
    /// Collect system information
    /// - Returns: System information
    public func collectSystemInfo() -> SystemInfo {
        return SystemInfo(
            cpuArchitecture: cpuArchitecture(),
            osName: osName(),
            osVersion: osVersion(),
            kernelVersion: kernelVersion(),
            additionalInfo: additionalInfo()
        )
    }
    
    // MARK: - Private Methods
    
    /// Get CPU architecture
    /// - Returns: CPU architecture string
    private func cpuArchitecture() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        
        return machine
    }
    
    /// Get OS name
    /// - Returns: OS name string
    private func osName() -> String {
        // Try to read from /etc/os-release
        if let osRelease = try? String(contentsOfFile: "/etc/os-release", encoding: .utf8) {
            let lines = osRelease.split(separator: "\n")
            
            for line in lines {
                if line.hasPrefix("NAME=") {
                    let name = line.dropFirst(5)
                    // Remove quotes if present
                    if name.first == "\"" && name.last == "\"" {
                        return String(name.dropFirst().dropLast())
                    }
                    return String(name)
                }
            }
        }
        
        // Fallback to uname
        var sysinfo = utsname()
        uname(&sysinfo)
        
        let sysname = withUnsafePointer(to: &sysinfo.sysname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        
        return sysname
    }
    
    /// Get OS version
    /// - Returns: OS version string
    private func osVersion() -> String {
        // Try to read from /etc/os-release
        if let osRelease = try? String(contentsOfFile: "/etc/os-release", encoding: .utf8) {
            let lines = osRelease.split(separator: "\n")
            
            for line in lines {
                if line.hasPrefix("VERSION_ID=") {
                    let version = line.dropFirst(11)
                    // Remove quotes if present
                    if version.first == "\"" && version.last == "\"" {
                        return String(version.dropFirst().dropLast())
                    }
                    return String(version)
                }
            }
        }
        
        // Fallback to uname
        var sysinfo = utsname()
        uname(&sysinfo)
        
        let release = withUnsafePointer(to: &sysinfo.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        
        return release
    }
    
    /// Get kernel version
    /// - Returns: Kernel version string
    private func kernelVersion() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        
        let release = withUnsafePointer(to: &sysinfo.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        
        return release
    }
    
    /// Get additional system information
    /// - Returns: Dictionary of additional information
    private func additionalInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        // Try to get CPU info from /proc/cpuinfo
        if let cpuInfo = try? String(contentsOfFile: "/proc/cpuinfo", encoding: .utf8) {
            let lines = cpuInfo.split(separator: "\n")
            
            var cpuModel = ""
            var cpuCores = 0
            
            for line in lines {
                if line.hasPrefix("model name") {
                    if let colonIndex = line.firstIndex(of: ":") {
                        let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
                        cpuModel = value
                    }
                } else if line.hasPrefix("processor") {
                    cpuCores += 1
                }
            }
            
            if !cpuModel.isEmpty {
                info["CPU Model"] = cpuModel
            }
            
            if cpuCores > 0 {
                info["CPU Cores"] = "\(cpuCores)"
            }
        }
        
        // Try to get memory info from /proc/meminfo
        if let memInfo = try? String(contentsOfFile: "/proc/meminfo", encoding: .utf8) {
            let lines = memInfo.split(separator: "\n")
            
            for line in lines {
                if line.hasPrefix("MemTotal:") {
                    let components = line.split(separator: " ").filter { !$0.isEmpty }
                    if components.count >= 2 {
                        if let memKB = Int(components[1]) {
                            let memGB = Double(memKB) / 1024.0 / 1024.0
                            info["Physical Memory"] = String(format: "%.2f GB", memGB)
                        }
                    }
                    break
                }
            }
        }
        
        return info
    }
}
#endif
