import Foundation

/// Errors that can occur with the HTTP server
public enum HTTPServerError: Error, CustomStringConvertible, Sendable {
    /// Server is not running
    case serverNotRunning
    
    /// Server is already running
    case serverAlreadyRunning
    
    /// SSL configuration error
    case sslConfigurationError(String)
    
    /// Port binding error
    case portBindingError(Int, String)
    
    /// Server initialization failed
    case serverInitializationFailed(String)
    
    /// Server shutdown error
    case serverShutdownError(String)
    
    /// Invalid configuration
    case invalidConfiguration(String)
    
    /// Generic server error
    case serverError(String)
    
    /// Authentication error
    case authenticationError(String)
    
    /// Human-readable description of the error
    public var description: String {
        switch self {
        case .serverNotRunning:
            return "Server is not running"
        case .serverAlreadyRunning:
            return "Server is already running"
        case .sslConfigurationError(let message):
            return "SSL configuration error: \(message)"
        case .portBindingError(let port, let message):
            return "Failed to bind to port \(port): \(message)"
        case .serverInitializationFailed(let message):
            return "Server initialization failed: \(message)"
        case .serverShutdownError(let message):
            return "Server shutdown error: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        }
    }
} 