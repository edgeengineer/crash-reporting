import Foundation
import Testing
@testable import CrashReporting

@Suite("Crash Reporting Tests")
struct CrashReportingTests {
    
    // Directory for test crash reports
    var testReportDirectory: URL!
    
    init() {
        // Create a temporary directory for test crash reports
        testReportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrashReportingTests_\(UUID().uuidString)", isDirectory: true)
        
        try? FileManager.default.createDirectory(
            at: testReportDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - Unit Tests
    
    @Test func testCrashReportGeneration() throws {
        // Configure the crash reporter
        CrashReporter.shared.configure(
            applicationName: "TestApp",
            applicationVersion: "1.0.0",
            crashReportDirectory: testReportDirectory
        )
        
        // Generate a manual crash report
        let reportURL = CrashReporter.shared.writeCrashReport(reason: "Test crash report")
        
        // Verify the report was created
        #expect(reportURL != nil)
        #expect(FileManager.default.fileExists(atPath: reportURL!.path))
        
        // Read the report content
        let reportContent = try String(contentsOf: reportURL!)
        
        // Verify the report contains the expected information
        #expect(reportContent.contains("Date:"))
        #expect(reportContent.contains("Reason: Test crash report"))
        #expect(reportContent.contains("APPLICATION INFORMATION"))
        #expect(reportContent.contains("Name: TestApp"))
        #expect(reportContent.contains("Version: 1.0.0"))
        #expect(reportContent.contains("SYSTEM INFORMATION"))
        #expect(reportContent.contains("CPU Architecture:"))
        #expect(reportContent.contains("OS Name:"))
        #expect(reportContent.contains("OS Version:"))
        #expect(reportContent.contains("Kernel Version:"))
        #expect(reportContent.contains("THREAD INFORMATION"))
        #expect(reportContent.contains("Current Thread ID:"))
        #expect(reportContent.contains("STACK TRACE"))
    }
    
    @Test func testSimulatedSignal() throws {
        // Configure the crash reporter
        CrashReporter.shared.configure(
            applicationName: "TestApp",
            applicationVersion: "1.0.0",
            crashReportDirectory: testReportDirectory
        )
        
        // Simulate a signal
        let reportURL = CrashReporter.shared.simulateSignal(SIGSEGV)
        
        // Verify the report was created
        #expect(reportURL != nil)
        #expect(FileManager.default.fileExists(atPath: reportURL!.path))
        
        // Read the report content
        let reportContent = try String(contentsOf: reportURL!)
        
        // Verify the report contains the expected information
        #expect(reportContent.contains("Signal: 11 (SIGSEGV"))
        #expect(reportContent.contains("Reason: Simulated signal"))
    }
    
    @Test func testReportFormatting() {
        // Create a test crash report
        let timestamp = Date()
        let stackTrace = StackTrace(frames: [
            StackFrame(address: "0x1000", symbolName: "testFunction", offset: 10, fileName: "test.swift", lineNumber: 42)
        ])
        let threadInfo = ThreadInfo(currentThreadID: 1234, threadCount: 1, additionalInfo: "Test thread")
        let systemInfo = SystemInfo(
            cpuArchitecture: "x86_64",
            osName: "TestOS",
            osVersion: "1.0",
            kernelVersion: "1.0",
            additionalInfo: ["Test": "Value"]
        )
        let appInfo = ApplicationInfo(name: "TestApp", version: "1.0.0", path: "/path/to/app")
        
        let report = CrashReport(
            timestamp: timestamp,
            signal: SIGSEGV,
            reason: "Test reason",
            stackTrace: stackTrace,
            threadInfo: threadInfo,
            systemInfo: systemInfo,
            applicationInfo: appInfo
        )
        
        // Test plain text format
        let plainText = report.formatted(format: .plainText)
        #expect(plainText.contains("CRASH REPORT"))
        #expect(plainText.contains("Signal: 11 (SIGSEGV"))
        #expect(plainText.contains("Reason: Test reason"))
        #expect(plainText.contains("Name: TestApp"))
        #expect(plainText.contains("CPU Architecture: x86_64"))
        #expect(plainText.contains("Current Thread ID: 1234"))
        #expect(plainText.contains("testFunction"))
        
        // Test JSON format
        let json = report.formatted(format: .json)
        #expect(json.contains("\"signal\": 11"))
        #expect(json.contains("\"signalName\": \"SIGSEGV"))
        #expect(json.contains("\"reason\": \"Test reason\""))
        #expect(json.contains("\"name\": \"TestApp\""))
        #expect(json.contains("\"cpuArchitecture\": \"x86_64\""))
        #expect(json.contains("\"currentThreadID\": 1234"))
        #expect(json.contains("\"symbolName\": \"testFunction\""))
        
        // Test XML format
        let xml = report.formatted(format: .xml)
        #expect(xml.contains("<signal>11</signal>"))
        #expect(xml.contains("<signalName>SIGSEGV"))
        #expect(xml.contains("<reason>Test reason</reason>"))
        #expect(xml.contains("<name>TestApp</name>"))
        #expect(xml.contains("<cpuArchitecture>x86_64</cpuArchitecture>"))
        #expect(xml.contains("<currentThreadID>1234</currentThreadID>"))
        #expect(xml.contains("<symbolName>testFunction</symbolName>"))
    }
    
    // MARK: - Integration Tests
    
    @Test func testCrashTesterExecution() throws {
        // Get the path to the CrashTester executable
        let crashTesterURL = productsDirectory.appendingPathComponent("CrashTester")
        
        // Skip test if CrashTester doesn't exist
        guard FileManager.default.fileExists(atPath: crashTesterURL.path) else {
            Issue.record("CrashTester executable not found at \(crashTesterURL.path)")
            return
        }
        
        // Run the CrashTester with a manual crash report
        let process = Process()
        process.executableURL = crashTesterURL
        process.arguments = ["manual", testReportDirectory.path]
        
        try process.run()
        process.waitUntilExit()
        
        // Give the crash reporter a moment to finish writing
        Thread.sleep(forTimeInterval: 1.0)
        
        // Find crash report files
        let crashReports = try FileManager.default.contentsOfDirectory(at: testReportDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "crash" }
        
        // Verify a crash report was generated
        #expect(!crashReports.isEmpty, "No crash report was generated")
        
        if let reportURL = crashReports.first {
            // Read the report content
            let reportContent = try String(contentsOf: reportURL)
            
            // Verify the report contains the expected information
            #expect(reportContent.contains("CrashTester"))
            #expect(reportContent.contains("Manual crash report"))
        }
    }
    
    @Test func testActualCrash() throws {
        // Get the path to the CrashTester executable
        let crashTesterURL = productsDirectory.appendingPathComponent("CrashTester")
        
        guard FileManager.default.fileExists(atPath: crashTesterURL.path) else {
            Issue.record("CrashTester executable not found at \(crashTesterURL.path)")
            return
        }
        
        // Ensure no old raw log exists from previous runs in this specific test directory
        let rawLogName = "pending_crash.txt" // Matches FileReportWriter.rawCrashLogName
        let rawReportURL = testReportDirectory.appendingPathComponent(rawLogName)
        try? FileManager.default.removeItem(at: rawReportURL)

        // Configure CrashReporter to use the unique test directory
        CrashReporter.shared.configure(
            applicationName: "TestApp", // Consistent with other tests
            applicationVersion: "1.0.0",
            crashReportDirectory: testReportDirectory
        )

        // Run CrashTester to generate the raw_pending_crash.txt
        let process = Process()
        process.executableURL = crashTesterURL
        process.arguments = ["raw_report_segfault", testReportDirectory.path]
        
        print("testActualCrash: Running CrashTester to generate raw report...")
        try process.run()
        process.waitUntilExit()
        
        print("testActualCrash: CrashTester (raw_report_segfault) exited with status \(process.terminationStatus).")
        // For raw_report_segfault, CrashTester should exit 0 if it successfully created the raw log.
        #expect(process.terminationStatus == 0, "CrashTester (raw_report_segfault) did not exit cleanly (status 0).")

        // Now, process the pending raw crash report
        print("testActualCrash: Attempting to process pending raw crash report...")
        let finalReportURL = CrashReporter.shared.processPendingRawCrashReport()

        #expect(finalReportURL != nil, "Processing pending raw crash report did not produce a final report URL.")
        
        guard let validFinalReportURL = finalReportURL else {
            Issue.record("Final report URL was nil after processing raw log.")
            return
        }

        #expect(FileManager.default.fileExists(atPath: validFinalReportURL.path), "Final formatted crash report file was not found.")

        // Verify content of the final, fully formatted report
        let fullReportContent = try String(contentsOf: validFinalReportURL)
        print("--- Content of final formatted .crash report ---")
        print(fullReportContent)
        print("-------------------------------------------------")

        #expect(fullReportContent.contains("Signal: \(SIGSEGV)"), "Final report does not contain correct signal.")
        #expect(fullReportContent.contains("Reason: Crash (recovered from raw log)"), "Final report reason is incorrect.")
        #expect(fullReportContent.contains("STACK TRACE"), "Final report does not contain STACK TRACE header.")
        #expect(fullReportContent.contains("0x"), "Final report does not appear to contain raw frame addresses (0x...). An empty stack trace might be valid if no frames were captured.")

        // Also check that pending_crash.txt was deleted after processing
        #expect(!FileManager.default.fileExists(atPath: rawReportURL.path), "pending_crash.txt was not deleted after processing.")
    }
}

// MARK: - Helper Extensions

extension CrashReportingTests {
    /// Returns the URL to the built products directory.
    var productsDirectory: URL {
        #if os(macOS) || os(Linux) // Common logic for SPM builds

        // Get the path of the current test file
        let currentFileURL = URL(fileURLWithPath: #filePath) // Swift 5.8+

        // Navigate up to find the package root directory (which contains the .build folder)
        var packageRootURL = currentFileURL
        var attempts = 0 // Safety break for the loop
        while !FileManager.default.fileExists(atPath: packageRootURL.appendingPathComponent(".build").path) {
            packageRootURL = packageRootURL.deletingLastPathComponent()
            attempts += 1
            // Stop if we reach the file system root or too many attempts, to prevent infinite loop
            if packageRootURL.path == "/" || attempts > 10 {
                fatalError("Could not find .build directory by traversing up from \(currentFileURL.path)")
            }
        }
        
        let productsDir = packageRootURL.appendingPathComponent(".build/debug")

        if !FileManager.default.fileExists(atPath: productsDir.path) {
             fatalError("Products directory does not exist at expected path: \(productsDir.path). Ensure 'swift build' has been run.")
        }

        return productsDir

        #else
        fatalError("Unsupported OS for productsDirectory determination")
        #endif
    }
}
