import Vapor
import Foundation

/// Authentication configuration for the HTTP server
public struct AuthenticationConfig: Equatable {
    /// Whether authentication is enabled
    public let enabled: Bool
    
    /// The username for basic authentication
    public let username: String?
    
    /// The password for basic authentication
    public let password: String?
    
    /// API key for token-based authentication
    public let apiKey: String?
    
    /// Session duration in seconds (default: 1 hour)
    public let sessionDuration: Int
    
    /// Authentication methods to enable
    public let methods: Set<AuthenticationMethod>
    
    /// Whether to limit streaming to single viewer
    public let singleViewerOnly: Bool
    
    /// Creates a configuration with authentication disabled
    public static var disabled: AuthenticationConfig {
        AuthenticationConfig(enabled: false, username: nil, password: nil, apiKey: nil)
    }
    
    /// Creates a configuration for basic authentication
    public static func basic(username: String, password: String) -> AuthenticationConfig {
        AuthenticationConfig(
            enabled: true,
            username: username,
            password: password,
            apiKey: nil,
            methods: [.basic]
        )
    }
    
    /// Creates a configuration for API key authentication
    public static func apiKey(_ key: String) -> AuthenticationConfig {
        AuthenticationConfig(
            enabled: true,
            username: nil,
            password: nil,
            apiKey: key,
            methods: [.apiKey]
        )
    }
    
    /// Creates a configuration for iCloud authentication
    public static func iCloud(singleViewerOnly: Bool = true) -> AuthenticationConfig {
        AuthenticationConfig(
            enabled: true,
            username: nil,
            password: nil,
            apiKey: nil,
            methods: [.iCloud],
            singleViewerOnly: singleViewerOnly
        )
    }
    
    /// Creates an authentication configuration
    public init(
        enabled: Bool = true,
        username: String? = nil,
        password: String? = nil,
        apiKey: String? = nil,
        sessionDuration: Int = 3600,
        methods: Set<AuthenticationMethod> = [.basic, .apiKey],
        singleViewerOnly: Bool = false
    ) {
        self.enabled = enabled
        self.username = username
        self.password = password
        self.apiKey = apiKey
        self.sessionDuration = sessionDuration
        self.methods = methods
        self.singleViewerOnly = singleViewerOnly
    }
}

/// Represents an authenticated user or client
public struct AuthenticatedUser: Hashable {
    /// Unique identifier for the user/client
    public let id: UUID
    
    /// Username or client identifier
    public let username: String
    
    /// Authentication method used
    public let method: AuthenticationMethod
    
    /// Timestamp when the user was authenticated
    public let authenticatedAt: Date
    
    /// Expiration date for the authentication
    public let expiresAt: Date
    
    /// Creates a new authenticated user
    public init(
        id: UUID = UUID(),
        username: String,
        method: AuthenticationMethod,
        authenticatedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.method = method
        self.authenticatedAt = authenticatedAt
        self.expiresAt = expiresAt ?? authenticatedAt.addingTimeInterval(3600)
    }
    
    /// Check if the authentication is still valid
    public var isValid: Bool {
        Date() < expiresAt
    }
}

/// Errors that can occur during authentication
public enum AuthenticationError: Error, Equatable {
    /// Authentication is required but not provided
    case authenticationRequired
    
    /// The provided credentials are invalid
    case invalidCredentials
    
    /// The authentication token has expired
    case expiredCredentials
    
    /// The requested authentication method is not supported
    case unsupportedMethod
}

/// Manages authentication for the HTTP server
public actor AuthenticationManager {
    /// The current authentication configuration
    private var config: AuthenticationConfig
    
    /// Currently active sessions
    private var sessions: [UUID: AuthenticatedUser]
    
    /// Creates a new authentication manager
    public init(config: AuthenticationConfig = .disabled) {
        self.config = config
        self.sessions = [:]
    }
    
    /// Update the authentication configuration
    public func updateConfig(_ config: AuthenticationConfig) {
        self.config = config
        
        // Clear sessions if authentication is disabled
        if !config.enabled {
            sessions.removeAll()
        }
    }
    
    /// Authenticates a user with HTTP Basic authentication
    public func authenticateBasic(username: String, password: String) throws -> AuthenticatedUser {
        guard config.enabled else {
            // Create a default user if authentication is disabled
            return AuthenticatedUser(username: "anonymous", method: .basic)
        }
        
        guard config.methods.contains(.basic) else {
            throw AuthenticationError.unsupportedMethod
        }
        
        guard let configUsername = config.username,
              let configPassword = config.password,
              username == configUsername,
              password == configPassword else {
            throw AuthenticationError.invalidCredentials
        }
        
        let user = AuthenticatedUser(
            username: username,
            method: .basic,
            expiresAt: Date().addingTimeInterval(TimeInterval(config.sessionDuration))
        )
        
        // Store the session
        sessions[user.id] = user
        
        return user
    }
    
    /// Authenticates a request with an API key
    public func authenticateApiKey(_ key: String) throws -> AuthenticatedUser {
        guard config.enabled else {
            // Create a default user if authentication is disabled
            return AuthenticatedUser(username: "api-client", method: .apiKey)
        }
        
        guard config.methods.contains(.apiKey) else {
            throw AuthenticationError.unsupportedMethod
        }
        
        guard let configKey = config.apiKey, key == configKey else {
            throw AuthenticationError.invalidCredentials
        }
        
        let user = AuthenticatedUser(
            username: "api-client",
            method: .apiKey,
            expiresAt: Date().addingTimeInterval(TimeInterval(config.sessionDuration))
        )
        
        // Store the session
        sessions[user.id] = user
        
        return user
    }
    
    /// Authenticates a user using iCloud identity
    public func authenticateWithiCloud(
        deviceIdentifier: String,
        userIdentityToken: String
    ) throws -> AuthenticatedUser {
        guard config.enabled else {
            // Create a default user if authentication is disabled
            return AuthenticatedUser(username: "icloud-user", method: .iCloud)
        }
        
        guard config.methods.contains(.iCloud) else {
            throw AuthenticationError.unsupportedMethod
        }
        
        // In a real implementation, we would validate the iCloud identity token
        // with Apple's identity verification service. This is a simplified version.
        
        // For now, we'll just check that the token is not empty
        guard !userIdentityToken.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }
        
        // Create a user record based on the provided identity
        let user = AuthenticatedUser(
            username: "icloud-user-\(deviceIdentifier)",
            method: .iCloud,
            expiresAt: Date().addingTimeInterval(TimeInterval(config.sessionDuration))
        )
        
        // Store the session
        sessions[user.id] = user
        
        return user
    }
    
    /// Validate a session token
    public func validateSession(_ token: UUID) -> Bool {
        guard config.enabled else {
            return true // Authentication disabled, all sessions are valid
        }
        
        guard let user = sessions[token], user.isValid else {
            return false
        }
        
        return true
    }
    
    /// Invalidate a session
    public func invalidateSession(_ token: UUID) {
        sessions.removeValue(forKey: token)
    }
    
    /// Clean up expired sessions
    public func cleanupExpiredSessions() {
        let now = Date()
        sessions = sessions.filter { $0.value.expiresAt > now }
    }
    
    // Add active viewer tracking for single-viewer mode
    private var activeViewerId: UUID?

    /// Request a streaming session
    public func requestStreamingSession() async throws -> UUID {
        if config.singleViewerOnly {
            // Only allow one viewer at a time if configured
            if let existingId = activeViewerId, 
               let user = sessions[existingId], 
               user.isValid {
                throw StreamError.streamInUse
            }
        }
        
        // Generate a new session ID
        let sessionId = UUID()
        
        // Create an authentication record
        let user = AuthenticatedUser(
            id: sessionId,
            username: "stream-viewer",
            method: .token,
            expiresAt: Date().addingTimeInterval(TimeInterval(config.sessionDuration))
        )
        
        // Store the session
        sessions[sessionId] = user
        
        // Track active viewer if we're in single-viewer mode
        if config.singleViewerOnly {
            activeViewerId = sessionId
        }
        
        return sessionId
    }

    /// Release a streaming session
    public func releaseStreamingSession(_ sessionId: UUID) {
        // Remove the session
        sessions.removeValue(forKey: sessionId)
        
        // Clear the active viewer if this was the active one
        if activeViewerId == sessionId {
            activeViewerId = nil
        }
    }

    /// Error type for stream operations
    public enum StreamError: Error, Equatable {
        case streamInUse
        case invalidToken
    }
}

// MARK: - Vapor extensions

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

/// Middleware for handling authentication in Vapor
public struct AuthMiddleware: AsyncMiddleware {
    private let authManager: AuthenticationManager
    
    public init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check if the request has basic auth credentials
        if let basicAuth = request.headers.basicAuthorization {
            do {
                let user = try await authManager.authenticateBasic(
                    username: basicAuth.username,
                    password: basicAuth.password
                )
                request.authenticatedUser = user
            } catch {
                // Continue without setting authenticated user
            }
        }
        
        // Check if the request has an API key
        if let apiKey = request.headers[.apiKey].first ?? request.query[String.self, at: "api_key"] {
            do {
                let user = try await authManager.authenticateApiKey(apiKey)
                request.authenticatedUser = user
            } catch {
                // Continue without setting authenticated user
            }
        }
        
        return try await next.respond(to: request)
    }
}

/// Extension to add custom HTTP headers
extension HTTPHeaders.Name {
    /// Header for API key authentication
    public static let apiKey = HTTPHeaders.Name("X-API-Key")
} 