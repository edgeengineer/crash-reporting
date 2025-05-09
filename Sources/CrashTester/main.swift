#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CrashReporting

/// Simple executable to test crash reporting functionality
/// Usage: CrashTester [crash-type] [report-directory]
/// - crash-type: Type of crash to simulate (segfault, abort, divide-by-zero, etc.)
/// - report-directory: Directory where crash reports will be stored

// Parse command line arguments
let crashType = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "segfault"
let reportDirectory = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : FileManager.default.temporaryDirectory

print("CrashTester: Initializing with crash type '\(crashType)' and report directory '\(reportDirectory.path)'")

// Configure the crash reporter
CrashReporter.shared.configure(
    applicationName: "CrashTester",
    applicationVersion: "1.0.0",
    crashReportDirectory: reportDirectory
)

// Install signal handlers
CrashReporter.shared.installHandlers()

print("CrashTester: Crash reporter configured and handlers installed")
print("CrashTester: Waiting 1 second before crashing...")

// Wait a moment to ensure everything is set up
Thread.sleep(forTimeInterval: 1.0)

// Trigger the crash based on the specified type
print("CrashTester: Triggering crash of type '\(crashType)'")

switch crashType.lowercased() {
case "segfault", "sigsegv":
    // Segmentation fault
    let ptr: UnsafeMutablePointer<Int>? = nil
    ptr!.pointee = 42
    
case "abort", "sigabrt":
    // Abort
    abort()
    
case "floating-point-exception", "fpe", "sigfpe":
    print("Simulating floating point exception (SIGFPE)...")
    // Division by zero
    func getZero() -> Int { return 0 }
    let x = 1
    let y = getZero()
    print("Attempting division by \(x) / \(y)...")
    let _ = x / y
    print("Survived division by zero (should not happen).") // Should not be reached
    
case "illegal-instruction", "sigill":
    print("Simulating illegal instruction (SIGILL)...")
    let code: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF] // Invalid instruction bytes
    typealias FunctionType = @convention(c) () -> Void
    code.withUnsafeBytes { rawBufferPointer in
        // This attempts to execute bytes from the data section.
        // Behavior can be unpredictable; it might crash with SIGSEGV or SIGBUS
        // if the memory is not executable, or SIGILL if it is executable but contains invalid opcodes.
        if let baseAddress = rawBufferPointer.baseAddress {
            let functionPointer = baseAddress.bindMemory(to: FunctionType.self, capacity: 1)
            functionPointer.pointee()
        }
    }
    print("Survived illegal instruction simulation (should not happen).") // Should not be reached
    
case "bus-error", "sigbus":
    // Bus error (unaligned memory access)
    let ptr = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    defer { ptr.deallocate() }
    let misalignedPtr = ptr.advanced(by: 1).bindMemory(to: Int.self, capacity: 1)
    misalignedPtr.pointee = 42
    
case "manual":
    // Manual crash report
    print("CrashTester: Writing manual crash report")
    let url = CrashReporter.shared.writeCrashReport(reason: "Manual crash report")
    print("CrashTester: Wrote crash report to \(url?.path ?? "unknown")")
    exit(0)
    
default:
    print("CrashTester: Unknown crash type '\(crashType)'")
    print("CrashTester: Available crash types: segfault, abort, divide-by-zero, illegal-instruction, bus-error, manual")
    exit(1)
}

// Should never reach here
print("CrashTester: Failed to crash!")
exit(1)
