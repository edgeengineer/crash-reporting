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
    print("CrashTester: Simulating crash via abort() for SIGABRT test...")
    abort()
    
case "abort", "sigabrt":
    print("CrashTester: Simulating crash via abort() for SIGABRT...")
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
    
case "raw_report_segfault": // New case for generating a raw pending_crash.txt
    print("CrashTester: Simulating generation of raw_pending_crash.txt for a segfault...")
    let signal = SIGSEGV // Or use the platform-specific value if not directly available
    var currentTime: time_t = 0
    time(&currentTime)
    
    let maxStackFrames = 32 // Keep it reasonably small for a raw report
    let addresses = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: maxStackFrames)
    let frameCount = backtrace(addresses, Int32(maxStackFrames))
    var frameAddressArray = [UnsafeMutableRawPointer?]()
    for i in 0..<Int(frameCount) {
        frameAddressArray.append(addresses[i])
    }
    addresses.deallocate()

    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    let platformThreadID = UInt64(pthread_mach_thread_np(pthread_self()))
    #elseif os(Linux)
    let rawPthreadT = pthread_self()
    let platformThreadID = UInt64(bitPattern: UnsafeRawPointer(bitPattern: rawPthreadT))
    #else
    let platformThreadID: UInt64 = 0
    #endif

    if let writer = CrashReporter.shared.reportWriter as? FileReportWriter {
        do {
            try writer.simulatePendingCrashTxt(signal: signal, 
                                               timestamp: currentTime, 
                                               threadID: platformThreadID, 
                                               frameAddresses: frameAddressArray)
            print("CrashTester: Successfully simulated pending_crash.txt generation.")
            exit(0) // Successful simulation
        } catch {
            print("CrashTester: Error simulating pending_crash.txt: \(error)")
            exit(1) // Error during simulation
        }
    } else {
        print("CrashTester: ReportWriter is not a FileReportWriter, cannot simulate raw log.")
        exit(1)
    }
    
default:
    print("CrashTester: Unknown crash type '\(crashType)'")
    print("CrashTester: Available crash types: segfault, abort, divide-by-zero, illegal-instruction, bus-error, manual")
    exit(1)
}

// Should never reach here
print("CrashTester: Failed to crash!")
exit(1)
