import Foundation

/// Errors that can occur in the HTTP server
public enum ServerError: Error, LocalizedError {
    /// Server is already running
    case serverAlreadyRunning
    
    /// Server failed to start
    case serverStartFailed(Error)
    
    /// Server is not running
    case serverNotRunning
    
    /// Invalid server configuration
    case invalidConfiguration(String)
    
    /// Authentication failed
    case authenticationFailed
    
    /// Invalid credentials
    case invalidCredentials
    
    /// Encoder not connected
    case encoderNotConnected
    
    /// Stream not available
    case streamNotAvailable
    
    /// Internal server error
    case internalError(String)
    
    /// File not found
    case fileNotFound(String)
    
    /// Unauthorized access
    case unauthorized
    
    /// Custom error message
    public var errorDescription: String? {
        switch self {
        case .serverAlreadyRunning:
            return "Server is already running"
        case .serverStartFailed(let error):
            return "Server failed to start: \(error.localizedDescription)"
        case .serverNotRunning:
            return "Server is not running"
        case .invalidConfiguration(let reason):
            return "Invalid server configuration: \(reason)"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidCredentials:
            return "Invalid credentials"
        case .encoderNotConnected:
            return "Video encoder not connected"
        case .streamNotAvailable:
            return "Stream not available"
        case .internalError(let message):
            return "Internal server error: \(message)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
} 