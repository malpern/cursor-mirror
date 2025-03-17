import Vapor
import Foundation
#if os(macOS)
import CloudKit

/// Handler for CloudKit/iCloud authentication
public struct CloudKitAuthenticationHandler: AuthenticationHandlerProtocol {
    /// The authentication method
    public var method: AuthenticationMethod { .iCloud }
    
    /// Authenticate a request using iCloud identity
    public func authenticate(request: Request, authManager: AuthenticationManager) async -> AuthenticatedUser? {
        // Look for the iCloud identity token in headers and query parameters
        let deviceId = request.headers["X-iCloud-Device-ID"].first ?? request.query[String.self, at: "device_id"]
        let identityToken = request.headers["X-iCloud-Identity-Token"].first ?? request.query[String.self, at: "identity_token"]
        
        // Make sure we have both the device ID and identity token
        guard let deviceId = deviceId, let identityToken = identityToken else {
            return nil
        }
        
        do {
            // Authenticate with the manager
            return try await authManager.authenticateWithiCloud(
                deviceIdentifier: deviceId,
                userIdentityToken: identityToken
            )
        } catch {
            // Log authentication failure
            request.logger.debug("iCloud authentication failed: \(error)")
            return nil
        }
    }
    
    /// Add authentication challenge headers for iCloud auth
    public func addAuthenticationChallengeHeaders(to response: inout Response) {
        // iCloud authentication does not use challenge headers
    }
}
#endif 