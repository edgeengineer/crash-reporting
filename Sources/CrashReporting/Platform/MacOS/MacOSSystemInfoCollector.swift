#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(macOS)
/// System information collector implementation for macOS
public class MacOSSystemInfoCollector: SystemInfoCollectorProtocol {
    /// Initialize a new macOS system information collector
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
        return "macOS"
    }
    
    /// Get OS version
    /// - Returns: OS version string
    private func osVersion() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }
    
    /// Get kernel version
    /// - Returns: Kernel version string
    private func kernelVersion() -> String {
        var size = 0
        sysctlbyname("kern.osrelease", nil, &size, nil, 0)
        var version = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osrelease", &version, &size, nil, 0)
        
        return version.withUnsafeBufferPointer { buffer -> String in
            if let nullTerminatorIndex = buffer.firstIndex(of: 0) {
                let validData = buffer[..<nullTerminatorIndex]
                let uint8Slice = validData.map { UInt8(bitPattern: $0) }
                return String(decoding: uint8Slice, as: UTF8.self)
            }
            let uint8Buffer = buffer.map { UInt8(bitPattern: $0) }
            return String(decoding: uint8Buffer, as: UTF8.self)
        }
    }
    
    /// Get additional system information
    /// - Returns: Dictionary of additional information
    private func additionalInfo() -> [String: String] {
        var info: [String: String] = [:]
        
        // Get model identifier
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        
        info["Model"] = model.withUnsafeBufferPointer { buffer -> String in
            if let nullTerminatorIndex = buffer.firstIndex(of: 0) {
                let validData = buffer[..<nullTerminatorIndex]
                let uint8Slice = validData.map { UInt8(bitPattern: $0) }
                return String(decoding: uint8Slice, as: UTF8.self)
            }
            let uint8Buffer = buffer.map { UInt8(bitPattern: $0) }
            return String(decoding: uint8Buffer, as: UTF8.self)
        }
        
        // Get physical memory
        var memSize: UInt64 = 0
        size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memSize, &size, nil, 0)
        
        let memoryGB = Double(memSize) / (1024 * 1024 * 1024)
        info["Physical Memory"] = String(format: "%.2f GB", memoryGB)
        
        // Get CPU info
        var cpuCount: Int32 = 0
        size = MemoryLayout<Int32>.size
        sysctlbyname("hw.logicalcpu", &cpuCount, &size, nil, 0)
        
        info["CPU Cores"] = "\(cpuCount)"
        
        return info
    }
}
#endif
