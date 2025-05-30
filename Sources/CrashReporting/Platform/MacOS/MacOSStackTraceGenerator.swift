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
    
    public func generateStackTrace(fromRawAddresses addresses: [UnsafeMutableRawPointer?]) -> StackTrace {
        var frames: [StackFrame] = []

        for rawAddressOptional in addresses {
            let addressString: String
            var frame: StackFrame

            if let rawAddress = rawAddressOptional {
                let numericAddress = UInt(bitPattern: OpaquePointer(rawAddress))
                addressString = "0x" + String(numericAddress, radix: 16, uppercase: false)

                var info = Dl_info()
                if dladdr(rawAddress, &info) != 0 {
                    // dladdr succeeded
                    let mangledSymbolNameFromDladdr: String?
                    if let sname = info.dli_sname {
                        mangledSymbolNameFromDladdr = String(cString: sname)
                    } else {
                        mangledSymbolNameFromDladdr = nil
                    }

                    let parsedInfo = parseMangledSymbol(mangledSymbolNameFromDladdr ?? "<unknown symbol from dladdr>", 
                                                        address: rawAddress, 
                                                        info: info)
                    
                    frame = StackFrame(
                        address: addressString,
                        symbolName: parsedInfo.symbolName, 
                        offset: parsedInfo.offset,
                        fileName: parsedInfo.fileName,
                        lineNumber: parsedInfo.lineNumber
                    )
                } else {
                    // dladdr failed
                    frame = StackFrame(address: addressString, symbolName: "<dladdr failed>")
                }
            } else {
                // Address was nil
                addressString = "0x0 (nil address)"
                frame = StackFrame(address: addressString, symbolName: "<nil address pointer>")
            }
            frames.append(frame)
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
        if let demangled = demangleSwiftSymbol(mangledSymbol) {
            symbolName = demangled
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
    
    // Reverted to placeholder demangleSwiftSymbol
    private func demangleSwiftSymbol(_ mangledName: String) -> String? {
        // Placeholder - actual demangling requires resolving linker issues or using a C helper.
        // Common Swift mangled name prefixes for a basic check:
        if mangledName.hasPrefix("_$s") || mangledName.hasPrefix("$s") || 
           mangledName.hasPrefix("_T0") || mangledName.hasPrefix("_Tt") {
            // To indicate it *would* be demangled, but isn't currently.
            // return mangledName + " [demangling_placeholder]"
            return nil // Or return mangledName if you prefer to see it.
        }
        return nil // Not a recognized Swift mangled name pattern, or demangling failed/skipped.
    }
}
#endif
