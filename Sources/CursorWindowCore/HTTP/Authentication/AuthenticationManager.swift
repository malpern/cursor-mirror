import Vapor
import Foundation
import Logging

/// Authentication configuration for the HTTP server
public struct AuthenticationConfig: Equatable, Sendable {
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
    
    /// Creates an authentication configuration
    public init(
        enabled: Bool = true,
        username: String? = nil,
        password: String? = nil,
        apiKey: String? = nil,
        sessionDuration: Int = 3600,
        methods: Set<AuthenticationMethod> = [.basic, .apiKey]
    ) {
        self.enabled = enabled
        self.username = username
        self.password = password
        self.apiKey = apiKey
        self.sessionDuration = sessionDuration
        self.methods = methods
    }
}

/// Authentication methods supported by the server
public enum AuthenticationMethod: String, Hashable, Sendable {
    /// HTTP Basic authentication
    case basic
    
    /// API key authentication
    case apiKey
    
    /// JWT token authentication
    case jwt
}

/// Represents an authenticated user or client
public struct AuthenticatedUser: Hashable, Sendable {
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
public enum AuthenticationError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Authentication is required but not provided
    case authenticationRequired
    
    /// The provided credentials are invalid
    case invalidCredentials
    
    /// The authentication token has expired
    case expiredCredentials
    
    /// The requested authentication method is not supported
    case unsupportedMethod
    
    /// Human-readable description of the error
    public var description: String {
        switch self {
        case .authenticationRequired:
            return "Authentication is required to access this resource"
        case .invalidCredentials:
            return "The provided authentication credentials are invalid"
        case .expiredCredentials:
            return "The authentication credentials have expired"
        case .unsupportedMethod:
            return "The requested authentication method is not supported"
        }
    }
    
    /// Convert to Vapor's Abort error
    public var asAbort: Abort {
        switch self {
        case .authenticationRequired:
            return Abort(.unauthorized, reason: self.description)
        case .invalidCredentials:
            return Abort(.unauthorized, reason: self.description)
        case .expiredCredentials:
            return Abort(.unauthorized, reason: self.description)
        case .unsupportedMethod:
            return Abort(.badRequest, reason: self.description)
        }
    }
    
    /// Create a generic conversion function
    public static func asAbort(_ error: Error) -> Abort {
        if let authError = error as? AuthenticationError {
            return authError.asAbort
        } else {
            return Abort(.internalServerError, reason: "Authentication error: \(error.localizedDescription)")
        }
    }
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
    private let logger: Logger
    
    public init(authManager: AuthenticationManager, logger: Logger = Logger(label: "auth.middleware")) {
        self.authManager = authManager
        self.logger = logger
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
                logger.debug("User authenticated with basic auth: \(user.username)")
            } catch let error as AuthenticationError {
                logger.warning("Basic auth failed: \(error.description)")
                // Continue without setting authenticated user
            } catch {
                logger.error("Unexpected error during basic auth: \(error)")
                // Continue without setting authenticated user
            }
        }
        
        // Check if the request has an API key
        if let apiKey = request.headers[.apiKey].first ?? request.query[String.self, at: "api_key"] {
            do {
                let user = try await authManager.authenticateApiKey(apiKey)
                request.authenticatedUser = user
                logger.debug("User authenticated with API key: \(user.username)")
            } catch let error as AuthenticationError {
                logger.warning("API key auth failed: \(error.description)")
                // Continue without setting authenticated user
            } catch {
                logger.error("Unexpected error during API key auth: \(error)")
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

/// Extension for Vapor's RouteBuilder to add protected routes
extension RoutesBuilder {
    /// Create a route group that requires authentication
    public func protected(using authManager: AuthenticationManager) -> RoutesBuilder {
        self.grouped(AuthProtectedRouteMiddleware(authManager: authManager))
    }
}

/// Middleware that ensures a route is protected with authentication
public struct AuthProtectedRouteMiddleware: AsyncMiddleware {
    private let authManager: AuthenticationManager
    private let logger: Logger
    
    public init(authManager: AuthenticationManager, logger: Logger = Logger(label: "auth.protected")) {
        self.authManager = authManager
        self.logger = logger
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check if user is already authenticated
        if let user = request.authenticatedUser, user.isValid {
            return try await next.respond(to: request)
        }
        
        // Check for token in query string
        if let tokenString = request.query[String.self, at: "token"],
           let token = UUID(uuidString: tokenString),
           await authManager.validateSession(token) {
            // Session is valid
            logger.debug("Request authenticated via token")
            return try await next.respond(to: request)
        }
        
        // Authentication failed
        logger.warning("Authentication required but not provided")
        throw AuthenticationError.authenticationRequired.asAbort
    }
} 