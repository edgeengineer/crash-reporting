#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(macOS)
/// Stack trace generator implementation for macOS
public class MacOSStackTraceGenerator: StackTraceGeneratorProtocol {
    /// Maximum number of stack frames to capture
    private let maxFrames: Int
    
    /// Initialize a new macOS stack trace generator
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
                    if let symbolCString = symbols[i] {
                        // address here is addresses[i] which is UnsafeMutableRawPointer?
                        let frame = processSymbol(String(cString: symbolCString), address: addresses[i])
                        frames.append(frame)
                    } else {
                        // Handle case where symbol string is nil, but we might still have an address
                        let addressString: String
                        if let addr = addresses[i] { // addr is UnsafeMutableRawPointer
                            let numericAddress = UInt(bitPattern: OpaquePointer(addr))
                            addressString = "0x" + String(numericAddress, radix: 16, uppercase: false)
                        } else {
                            addressString = "0x0 (nil address)"
                        }
                        frames.append(StackFrame(address: addressString, symbolName: "(nil symbol)"))
                    }
                }
            } else {
                // If symbol lookup failed (backtrace_symbols returned nil), just use addresses
                for i in 0..<Int(frameCount) {
                    let currentAddressString: String
                    if let addr = addresses[i] { // addr is UnsafeMutableRawPointer
                        let numericAddress = UInt(bitPattern: OpaquePointer(addr))
                        currentAddressString = "0x" + String(numericAddress, radix: 16, uppercase: false)
                    } else {
                        currentAddressString = "0x0 (nil address)"
                    }
                    frames.append(StackFrame(address: currentAddressString))
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
        let addressString: String
        if let addr = address { // addr is UnsafeMutableRawPointer
            let numericAddress = UInt(bitPattern: OpaquePointer(addr))
            addressString = "0x" + String(numericAddress, radix: 16, uppercase: false)
        } else {
            addressString = "0x0 (nil address)"
        }
        
        var info = Dl_info()
        // Only call dladdr and parseMangledSymbol if we have a non-nil address
        if let unwrappedAddress = address, dladdr(unwrappedAddress, &info) != 0 {
            let parsedInfo = parseMangledSymbol(symbol, address: unwrappedAddress, info: info)
            return StackFrame(address: addressString, symbolName: parsedInfo.symbolName ?? symbol, offset: parsedInfo.offset, fileName: parsedInfo.fileName, lineNumber: parsedInfo.lineNumber)
        } else {
            // Fallback if dladdr fails or address is nil
            return StackFrame(address: addressString, symbolName: symbol)
        }
    }
    
    // Ensure parseMangledSymbol takes a non-optional address
    private func parseMangledSymbol(_ mangledSymbol: String, address: UnsafeMutableRawPointer, info: Dl_info) -> (symbolName: String?, fileName: String?, lineNumber: Int?, offset: Int?) {
        var symbolName: String?
        var fileName: String?
        let lineNumber: Int? = nil // Line number is hard to get reliably from Dl_info alone
        var offset: Int?
        
        // Attempt to demangle the symbol name
        if let demangledName = try? demangleSwiftSymbol(mangledSymbol) {
            symbolName = demangledName
        } else if let sname = info.dli_sname, let name = String(validatingCString: sname) {
            symbolName = name
        } else {
            symbolName = mangledSymbol
        }
        
        // Get the filename
        if let dli_fname = info.dli_fname, let fname = String(validatingCString: dli_fname) {
            fileName = fname
        }
        
        // Calculate offset from the symbol's start address (dli_saddr)
        if let symbolStartAddressPointer = info.dli_saddr { // symbolStartAddressPointer is UnsafeMutableRawPointer
            let intAddress = Int(bitPattern: address) // address is non-optional UnsafeMutableRawPointer
            let uAddress = UInt64(intAddress)
            
            let intSymbolStartAddress = Int(bitPattern: symbolStartAddressPointer) // symbolStartAddressPointer is non-optional here
            let uSymbolStartAddress = UInt64(intSymbolStartAddress)
            
            if uAddress >= uSymbolStartAddress {
                offset = Int(uAddress - uSymbolStartAddress)
            } else {
                offset = nil 
            }
        }
        
        return (symbolName, fileName, lineNumber, offset)
    }
    
    // Placeholder for demangleSwiftSymbol if not already defined elsewhere
    // You'll need the actual implementation for this.
    // @_silgen_name("swift_demangle")
    // private func _swift_demangleImpl(...) -> ...
    private func demangleSwiftSymbol(_ mangledName: String) throws -> String? {
        // This is a simplified placeholder. Real demangling is complex.
        // You might be using an existing library or a more complete implementation.
        if mangledName.hasPrefix("_$s") || mangledName.hasPrefix("$s") || mangledName.hasPrefix("_T0") {
            // Very naive check, actual demangling is needed
            // return "\(mangledName) (demangled)" // Placeholder return
            return nil // Simulate no change if proper demangling isn't set up here
        }
        return nil
    }
}
#endif
