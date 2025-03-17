#if os(macOS)
import Vapor
import CloudKit
import Foundation

/// Middleware for handling CloudKit authentication
public struct CloudKitAuthMiddleware: AsyncMiddleware {
    private let authManager: AuthenticationManager
    
    /// Create a new CloudKit authentication middleware
    /// - Parameter authManager: The authentication manager to use
    public init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    /// Process the request and authenticate using CloudKit if possible
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Skip if user is already authenticated
        if let user = request.authenticatedUser, user.isValid {
            return try await next.respond(to: request)
        }
        
        // Check for iCloud identity token in headers or query
        if let identityToken = request.headers.first(name: "X-CloudKit-Identity"),
           let deviceId = request.headers.first(name: "X-CloudKit-DeviceID") {
            do {
                // Try to authenticate using CloudKit
                let user = try await authManager.authenticateWithiCloud(
                    deviceIdentifier: deviceId,
                    userIdentityToken: identityToken
                )
                
                // Set authenticated user
                request.authenticatedUser = user
            } catch {
                // Continue without setting authenticated user
                // Authentication failure will be handled by ProtectedRouteMiddleware
            }
        }
        
        // Check for iCloud identity in query parameters (for stream URLs)
        if let identityToken = request.query[String.self, at: "icloud_token"],
           let deviceId = request.query[String.self, at: "device_id"] {
            do {
                // Try to authenticate using CloudKit
                let user = try await authManager.authenticateWithiCloud(
                    deviceIdentifier: deviceId,
                    userIdentityToken: identityToken
                )
                
                // Set authenticated user
                request.authenticatedUser = user
            } catch {
                // Continue without setting authenticated user
                // Authentication failure will be handled by ProtectedRouteMiddleware
            }
        }
        
        // Proceed with the request
        return try await next.respond(to: request)
    }
}

/// Extension to add CloudKit authentication to routes
extension RoutesBuilder {
    /// Protect routes with CloudKit authentication
    public func protectedByiCloud(using authManager: AuthenticationManager) -> RoutesBuilder {
        self.grouped(
            CloudKitAuthMiddleware(authManager: authManager),
            ProtectedRouteMiddleware(authManager: authManager, requiredMethods: [.iCloud])
        )
    }
}
#endif 