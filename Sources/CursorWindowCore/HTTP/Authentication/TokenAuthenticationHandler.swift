import Vapor
import Foundation

/// Handler for token-based authentication
public struct TokenAuthenticationHandler: AuthenticationHandlerProtocol {
    /// The authentication method
    public var method: AuthenticationMethod { .token }
    
    /// Authenticate a request using a token
    public func authenticate(request: Request, authManager: AuthenticationManager) async -> AuthenticatedUser? {
        // Check for token in query parameters
        if let tokenStr = request.query[String.self, at: "token"],
           let token = UUID(uuidString: tokenStr),
           await authManager.validateSession(token) {
            
            // Create a basic authenticated user for token
            return AuthenticatedUser(
                id: token,
                username: "token-user",
                method: .token
            )
        }
        
        return nil
    }
    
    /// Add authentication challenge headers for token authentication
    public func addAuthenticationChallengeHeaders(to response: inout Response) {
        // Token authentication typically doesn't use a challenge header
        // so we don't need to add anything here
    }
} 