import Vapor
import Foundation

/// Protocol that defines the interface for authentication handlers
///
/// Authentication handlers are responsible for extracting credentials from requests
/// and authenticating users using those credentials. Each authentication method
/// (Basic, API Key, CloudKit, etc.) has its own handler implementation.
public protocol AuthenticationHandlerProtocol {
    /// The authentication method this handler supports
    var method: AuthenticationMethod { get }
    
    /// Attempts to authenticate the request using this handler's authentication method
    /// - Parameters:
    ///   - request: The request to authenticate
    ///   - authManager: The authentication manager to use
    /// - Returns: An authenticated user if authentication was successful, nil otherwise
    func authenticate(request: Request, authManager: AuthenticationManager) async throws -> AuthenticatedUser?
    
    /// Adds authentication challenge headers to the response if needed
    /// - Parameter response: The response to add headers to
    func addAuthenticationChallengeHeaders(to response: inout Response)
}

/// Extension with default implementation for common functionality
extension AuthenticationHandlerProtocol {
    /// Default implementation that does nothing
    public func addAuthenticationChallengeHeaders(to response: inout Response) {
        // Default implementation does nothing
    }
}

/// Factory for creating authentication handlers
public enum AuthenticationHandlerFactory {
    /// Creates a set of handlers for the specified authentication methods
    /// - Parameter methods: The authentication methods to create handlers for
    /// - Returns: An array of authentication handlers
    public static func createHandlers(for methods: Set<AuthenticationMethod>) -> [any AuthenticationHandlerProtocol] {
        var handlers: [any AuthenticationHandlerProtocol] = []
        
        if methods.contains(.basic) {
            handlers.append(BasicAuthenticationHandler())
        }
        
        if methods.contains(.apiKey) {
            handlers.append(APIKeyAuthenticationHandler())
        }
        
        if methods.contains(.jwt) {
            handlers.append(JWTAuthenticationHandler())
        }
        
        if methods.contains(.token) {
            handlers.append(TokenAuthenticationHandler())
        }
        
        #if os(macOS)
        if methods.contains(.iCloud) {
            handlers.append(CloudKitAuthenticationHandler())
        }
        #endif
        
        return handlers
    }
} 