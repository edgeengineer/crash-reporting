#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(Linux)
/// Stack trace generator implementation for Linux
public class LinuxStackTraceGenerator: StackTraceGeneratorProtocol {
    /// Maximum number of stack frames to capture
    private let maxFrames: Int
    
    /// Initialize a new Linux stack trace generator
    /// - Parameter maxFrames: Maximum number of stack frames to capture (default: 128)
    public init(maxFrames: Int = 128) {
        self.maxFrames = maxFrames
    }
    
    /// Generate a stack trace
    /// - Returns: Stack trace
    public func generateStackTrace() -> StackTrace {
        // Allocate memory for stack trace addresses
        let addresses = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: maxFrames)
        defer { addresses.deallocate() }
        
        // Get the stack trace
        let frameCount = backtrace(addresses, Int32(maxFrames))
        
        // Convert to stack frames
        var frames: [StackFrame] = []
        
        if frameCount > 0 {
            // Get symbols for addresses
            if let symbols = backtrace_symbols(addresses, frameCount) {
                defer { free(symbols) }
                
                // Process each symbol
                for i in 0..<Int(frameCount) {
                    if let symbol = symbols[i] {
                        let frame = processSymbol(String(cString: symbol), address: addresses[i])
                        frames.append(frame)
                    }
                }
            } else {
                // If symbol lookup failed, just use addresses
                for i in 0..<Int(frameCount) {
                    let addressString = String(format: "0x%llx", UInt64(bitPattern: addresses[i]))
                    frames.append(StackFrame(address: addressString))
                }
            }
        }
        
        return StackTrace(frames: frames)
    }
    
    // MARK: - Private Methods
    
    /// Process a symbol string from backtrace_symbols
    /// - Parameters:
    ///   - symbol: Symbol string
    ///   - address: Raw address
    /// - Returns: Stack frame
    private func processSymbol(_ symbol: String, address: UnsafeMutableRawPointer?) -> StackFrame {
        // Format the address as a string
        let addressString = String(format: "0x%llx", UInt64(bitPattern: address))
        
        // Parse the symbol string
        // Format on Linux is typically: "module(symbol+offset) [address]"
        // Example: "/lib/x86_64-linux-gnu/libc.so.6(abort+0x16a) [0x7f8a19b42c4a]"
        
        var symbolName: String? = nil
        var offset: Int? = nil
        var fileName: String? = nil
        
        // Extract the file name (module)
        if let openParenIndex = symbol.firstIndex(of: "(") {
            fileName = String(symbol[..<openParenIndex])
            
            // Extract the symbol name and offset
            if let closeParenIndex = symbol.firstIndex(of: ")"),
               let plusIndex = symbol[openParenIndex...closeParenIndex].firstIndex(of: "+") {
                
                symbolName = String(symbol[symbol.index(after: openParenIndex)..<plusIndex])
                
                let offsetStartIndex = symbol.index(after: plusIndex)
                let offsetEndIndex = closeParenIndex
                
                if offsetStartIndex < offsetEndIndex {
                    let offsetString = String(symbol[offsetStartIndex..<offsetEndIndex])
                    if offsetString.hasPrefix("0x") {
                        // Handle hexadecimal offset
                        let hexOffset = String(offsetString.dropFirst(2))
                        offset = Int(hexOffset, radix: 16)
                    } else {
                        // Handle decimal offset
                        offset = Int(offsetString)
                    }
                }
            }
        }
        
        return StackFrame(
            address: addressString,
            symbolName: symbolName,
            offset: offset,
            fileName: fileName,
            lineNumber: nil
        )
    }
    
    /// Try to get additional symbol information using addr2line
    /// - Parameters:
    ///   - address: Memory address
    ///   - module: Module (executable or library)
    /// - Returns: Optional tuple with file name and line number
    private func getSymbolInfoWithAddr2line(address: String, module: String) -> (String, Int)? {
        // Create a process to run addr2line
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/addr2line")
        
        // Set up arguments
        process.arguments = ["-e", module, address]
        
        // Set up pipes for output
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            // Run addr2line
            try process.run()
            process.waitUntilExit()
            
            // Get the output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8) {
                // Parse the output (format: "file:line")
                let components = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
                if components.count >= 2,
                   let lineNumber = Int(components[1]) {
                    return (String(components[0]), lineNumber)
                }
            }
        } catch {
            // Ignore errors
        }
        
        return nil
    }
}
#endif
