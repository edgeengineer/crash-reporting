#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if os(Linux)
/// Signal handler implementation for Linux
public class LinuxSignalHandler: SignalHandlerProtocol {
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
    private var previousHandlers: [Int32: sigaction] = [:]
    
    /// Callback to invoke when a signal is received
    private var callback: ((Int32) -> Void)?
    
    /// Initialize a new Linux signal handler
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
        for (signal, previousAction) in previousHandlers {
            sigaction(signal, &previousHandlers[signal]!, nil)
        }
        
        previousHandlers.removeAll()
        callback = nil
    }
    
    /// Raise a signal
    /// - Parameter signal: Signal to raise
    public func raiseSignal(_ signal: Int32) {
        // Restore the previous handler for this signal
        if let previousAction = previousHandlers[signal] {
            var action = previousAction
            sigaction(signal, &action, nil)
        }
        
        // Raise the signal
        raise(signal)
    }
    
    // MARK: - Private Methods
    
    private func registerHandler(for signal: Int32) {
        // Create a signal action
        var signalAction = sigaction()
        
        // Set up the signal handler
        signalAction.sa_sigaction = { (signal, info, context) in
            // Get the shared instance of the signal handler
            let signalHandler = LinuxSignalHandler.shared
            
            // Call the callback
            signalHandler.callback?(signal)
        }
        
        // Add flags to reset the handler and provide additional information
        signalAction.sa_flags = Int32(SA_SIGINFO | SA_RESTART)
        
        // Empty the signal mask
        sigemptyset(&signalAction.sa_mask)
        
        // Register the signal action
        var previousAction = sigaction()
        if sigaction(signal, &signalAction, &previousAction) == 0 {
            // Store the previous handler
            previousHandlers[signal] = previousAction
        }
    }
    
    // MARK: - Shared Instance
    
    /// Shared instance for use in C signal handlers
    private static let shared = LinuxSignalHandler()
}
#endif
