import Vapor
import Foundation

/// Handler for API key authentication
public struct APIKeyAuthenticationHandler: AuthenticationHandlerProtocol {
    /// The authentication method
    public var method: AuthenticationMethod { .apiKey }
    
    /// Authenticate a request using an API key
    public func authenticate(request: Request, authManager: AuthenticationManager) async -> AuthenticatedUser? {
        // Look for API key in headers or query parameters
        guard let apiKey = request.headers[.apiKey].first ?? request.query[String.self, at: "api_key"] else {
            return nil
        }
        
        do {
            // Authenticate with the manager
            return try await authManager.authenticateApiKey(apiKey)
        } catch {
            // Log authentication failure
            request.logger.debug("API key authentication failed: \(error)")
            return nil
        }
    }
    
    /// Add authentication challenge headers for API key auth
    public func addAuthenticationChallengeHeaders(to response: inout Response) {
        // API key auth does not typically use challenge headers
    }
} 