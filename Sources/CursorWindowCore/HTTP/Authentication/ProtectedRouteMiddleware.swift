import Vapor
import Foundation

/// Middleware for protecting routes that require authentication
public struct ProtectedRouteMiddleware: AsyncMiddleware {
    private let authManager: AuthenticationManager
    private let requiredMethods: Set<AuthenticationMethod>
    private let handlers: [any AuthenticationHandlerProtocol]
    
    /// Initialize the middleware with an authentication manager
    /// - Parameters:
    ///   - authManager: The authentication manager to use
    ///   - requiredMethods: The authentication methods that are accepted (default: any method)
    public init(
        authManager: AuthenticationManager,
        requiredMethods: Set<AuthenticationMethod> = [.basic, .apiKey, .jwt, .iCloud, .token]
    ) {
        self.authManager = authManager
        self.requiredMethods = requiredMethods
        self.handlers = AuthenticationHandlerFactory.createHandlers(for: requiredMethods)
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
        
        // If there's no authenticated user yet, try to authenticate with our handlers
        // (This might be a case where a token is in the query but hasn't been processed by AuthMiddleware)
        for handler in handlers {
            if let user = await handler.authenticate(request: request, authManager: authManager) {
                request.authenticatedUser = user
                if requiredMethods.contains(user.method) {
                    return try await next.respond(to: request)
                }
            }
        }
        
        // If we get here, authentication failed
        let response = Response(status: .unauthorized)
        
        // Add challenge headers from each handler
        for handler in handlers {
            handler.addAuthenticationChallengeHeaders(to: &response)
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
        methods: Set<AuthenticationMethod> = [.basic, .apiKey, .jwt, .iCloud, .token]
    ) -> RoutesBuilder {
        self.grouped(
            AuthMiddleware(authManager: authManager, methods: methods),
            ProtectedRouteMiddleware(authManager: authManager, requiredMethods: methods)
        )
    }
} 