import Vapor
import Foundation

/// Middleware for protecting routes that require authentication
public struct ProtectedRouteMiddleware: AsyncMiddleware {
    private let authManager: AuthenticationManager
    private let requiredMethods: Set<AuthenticationMethod>
    
    /// Initialize the middleware with an authentication manager
    /// - Parameters:
    ///   - authManager: The authentication manager to use
    ///   - requiredMethods: The authentication methods that are accepted (default: any method)
    public init(
        authManager: AuthenticationManager,
        requiredMethods: Set<AuthenticationMethod> = [.basic, .apiKey, .jwt]
    ) {
        self.authManager = authManager
        self.requiredMethods = requiredMethods
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // If the user is already authenticated (from auth middleware)
        if let user = request.authenticatedUser, user.isValid {
            // Check if the method is acceptable
            if requiredMethods.contains(user.method) {
                return try await next.respond(to: request)
            } else {
                throw Abort(.forbidden, reason: "Authentication method not allowed for this route")
            }
        }
        
        // Try to authenticate with token
        if let tokenStr = request.query[String.self, at: "token"],
           let token = UUID(uuidString: tokenStr),
           await authManager.validateSession(token) {
            return try await next.respond(to: request)
        }
        
        // If we get here, authentication failed
        let response = Response(status: .unauthorized)
        response.headers.bearerWWWAuthenticate = .init(realm: "CursorWindow")
        
        // Add WWW-Authenticate header for basic auth if it's supported
        if requiredMethods.contains(.basic) {
            response.headers.basicWWWAuthenticate = .init(realm: "CursorWindow")
        }
        
        return response
    }
}

/// Extension for guarding routes with authentication
extension RoutesBuilder {
    /// Add authentication protection to a group of routes
    /// - Parameters:
    ///   - authManager: The authentication manager
    ///   - methods: The authentication methods that are accepted (default: any method)
    /// - Returns: A route group with authentication protection
    public func protected(
        using authManager: AuthenticationManager,
        methods: Set<AuthenticationMethod> = [.basic, .apiKey, .jwt]
    ) -> RoutesBuilder {
        self.grouped(
            AuthMiddleware(authManager: authManager),
            ProtectedRouteMiddleware(authManager: authManager, requiredMethods: methods)
        )
    }
} 