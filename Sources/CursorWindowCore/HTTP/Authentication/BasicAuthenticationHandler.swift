import Vapor
import Foundation

/// Handler for basic authentication
public struct BasicAuthenticationHandler: AuthenticationHandlerProtocol {
    /// The authentication method
    public var method: AuthenticationMethod { .basic }
    
    /// Authenticate a request using HTTP Basic authentication
    public func authenticate(request: Request, authManager: AuthenticationManager) async -> AuthenticatedUser? {
        // Look for basic auth credentials in the request
        guard let basicAuth = request.headers.basicAuthorization else {
            return nil
        }
        
        do {
            // Authenticate with the manager
            return try await authManager.authenticateBasic(
                username: basicAuth.username,
                password: basicAuth.password
            )
        } catch {
            // Log authentication failure
            request.logger.debug("Basic authentication failed: \(error)")
            return nil
        }
    }
    
    /// Add authentication challenge headers for basic auth
    public func addAuthenticationChallengeHeaders(to response: inout Response) {
        response.headers.add(name: "WWW-Authenticate", value: "Basic realm=\"CursorWindow\"")
    }
} 