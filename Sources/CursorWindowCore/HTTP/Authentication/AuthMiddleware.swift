import Vapor
import Foundation
#if os(macOS)
import CloudKit
#endif

/// Middleware for handling authentication in Vapor
public struct AuthMiddleware: AsyncMiddleware {
    private let authManager: AuthenticationManager
    private let handlers: [any AuthenticationHandlerProtocol]
    
    /// Initialize middleware with an authentication manager and a set of authentication methods
    /// - Parameters:
    ///   - authManager: The authentication manager to use
    ///   - methods: The authentication methods to support (default: all methods)
    public init(
        authManager: AuthenticationManager,
        methods: Set<AuthenticationMethod> = [.basic, .apiKey, .jwt, .iCloud, .token]
    ) {
        self.authManager = authManager
        self.handlers = AuthenticationHandlerFactory.createHandlers(for: methods)
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Attempt to authenticate with each handler
        for handler in handlers {
            if let user = await handler.authenticate(request: request, authManager: authManager) {
                request.authenticatedUser = user
                break // Stop after first successful authentication
            }
        }
        
        return try await next.respond(to: request)
    }
}

/// Extension to add authentication capabilities to Vapor Request
extension Request {
    /// Get the authenticated user from the request
    public var authenticatedUser: AuthenticatedUser? {
        get { storage[AuthenticatedUserKey.self] }
        set { storage[AuthenticatedUserKey.self] = newValue }
    }
}

/// Storage key for the authenticated user
private struct AuthenticatedUserKey: StorageKey {
    typealias Value = AuthenticatedUser
}

/// Extension to add custom HTTP headers
extension HTTPHeaders.Name {
    /// Header for API key authentication
    public static let apiKey = HTTPHeaders.Name("X-API-Key")
}

#if os(macOS)
/// Extension to add CloudKit authentication to routes
extension RoutesBuilder {
    /// Protect routes with CloudKit authentication
    public func protectedByiCloud(using authManager: AuthenticationManager) -> RoutesBuilder {
        self.grouped(
            AuthMiddleware(authManager: authManager, methods: [.iCloud]),
            ProtectedRouteMiddleware(authManager: authManager, requiredMethods: [.iCloud])
        )
    }
}
#endif 