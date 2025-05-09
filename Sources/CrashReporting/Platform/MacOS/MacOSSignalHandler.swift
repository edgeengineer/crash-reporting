#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(macOS)
/// Signal handler implementation for macOS
public class MacOSSignalHandler: SignalHandlerProtocol, @unchecked Sendable {
    /// Signals to handle
    private let signals: [Int32] = [
        SIGABRT, // Abort
        SIGILL,  // Illegal instruction
        SIGSEGV, // Segmentation violation
        SIGFPE,  // Floating point exception
        SIGBUS,  // Bus error
        SIGPIPE  // Broken pipe
    ]
    
    /// Previous signal handlers
    private var previousHandlers: [Int32: @convention(c) (Int32) -> Void] = [:]
    
    /// Callback to invoke when a signal is received
    private var callback: ((Int32) -> Void)?
    
    /// Initialize a new macOS signal handler
    public init() {}
    
    /// Register signal handlers with a callback
    /// - Parameter callback: Callback to invoke when a signal is received
    public func registerSignalHandlers(callback: @escaping (Int32) -> Void) {
        self.callback = callback
        
        // Register signal handlers
        for signal in signals {
            registerHandler(for: signal)
        }
    }
    
    /// Unregister signal handlers
    public func unregisterSignalHandlers() {
        // Restore previous signal handlers
        for (signalValue, handler) in previousHandlers {
            signal(signalValue, handler)
        }
        
        previousHandlers.removeAll()
        callback = nil
    }
    
    /// Raise a signal
    /// - Parameter signal: Signal to raise
    public func raiseSignal(_ signalValue: Int32) {
        // Restore the previous handler for this signal
        if let previousHandler = previousHandlers[signalValue] {
            signal(signalValue, previousHandler)
        }
        
        // Re-raise the signal for the default handler to catch it
        raise(signalValue)
    }
    
    // MARK: - Private Methods
    
    private func registerHandler(for signal: Int32) {
        // Create a signal action
        var signalAction = sigaction()
        
        // Set the handler function
        signalAction.__sigaction_u.__sa_handler = { signal in
            // Get the shared instance of the signal handler
            let signalHandler = MacOSSignalHandler.shared
            
            // Call the callback
            signalHandler.callback?(signal)
        }
        
        // Add flags to reset the handler and restart system calls
        signalAction.sa_flags = Int32(SA_RESTART)
        
        // Empty the signal mask
        sigemptyset(&signalAction.sa_mask)
        
        // Register the signal action
        var previousAction = sigaction()
        if sigaction(signal, &signalAction, &previousAction) == 0 {
            // Store the previous handler
            previousHandlers[signal] = previousAction.__sigaction_u.__sa_handler
        }
    }
    
    // MARK: - Shared Instance
    
    /// Shared instance for use in C signal handlers
    private static let shared = MacOSSignalHandler()
}
#endif
