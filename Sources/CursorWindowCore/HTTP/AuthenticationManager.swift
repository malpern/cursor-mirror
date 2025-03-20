import Foundation
import Vapor

/// Manages authentication for the HTTP server
public actor AuthenticationManager {
    /// Authentication configuration
    public let config: AuthenticationConfig
    
    /// Active sessions
    private var sessions: [UUID: Session] = [:]
    
    /// Active streaming sessions (one per user)
    private var streamingSessions: [UUID: UUID] = [:]
    
    /// Create a new authentication manager
    /// - Parameter config: Authentication configuration
    public init(config: AuthenticationConfig) {
        self.config = config
    }
    
    /// Represents an authenticated session
    public struct Session: Sendable {
        /// Session ID
        public let id: UUID
        
        /// Username
        public let username: String
        
        /// When the session was created
        public let createdAt: Date
        
        /// When the session expires
        public let expiresAt: Date
        
        /// Whether the session is still valid
        public var isValid: Bool {
            Date() < expiresAt
        }
    }
    
    /// Authenticate with basic auth
    /// - Parameters:
    ///   - username: Username
    ///   - password: Password
    /// - Returns: A new session
    /// - Throws: Error if authentication fails
    public func authenticateBasic(username: String, password: String) async throws -> Session {
        // Check if authentication is enabled
        guard config.enabled, config.methods.contains(.basic) else {
            throw HTTPServerError.authenticationError("Basic authentication is not enabled")
        }
        
        // In a real app, you would check credentials against a database
        // For this example, we'll accept a hardcoded username/password
        guard username == "admin" && password == "admin" else {
            throw HTTPServerError.authenticationError("Invalid credentials")
        }
        
        // Create a new session
        return createSession(username: username)
    }
    
    /// Authenticate with an API key
    /// - Parameter apiKey: API key string
    /// - Returns: A new session
    /// - Throws: Error if authentication fails
    public func authenticateApiKey(_ apiKey: String) async throws -> Session {
        // Check if authentication is enabled
        guard config.enabled, config.methods.contains(.token) else {
            throw HTTPServerError.authenticationError("Token authentication is not enabled")
        }
        
        // In a real app, you would verify the API key against a database
        // For this example, we'll accept a hardcoded API key
        guard apiKey == "demo_api_key" else {
            throw HTTPServerError.authenticationError("Invalid API key")
        }
        
        // Create a new session
        return createSession(username: "api_user")
    }
    
    /// Validate a session token
    /// - Parameter token: Session token
    /// - Returns: Whether the session is valid
    /// - Throws: Error if session is invalid
    public func validateSession(_ token: UUID) async throws -> Bool {
        // Look up the session
        guard let session = sessions[token], session.isValid else {
            throw HTTPServerError.authenticationError("Invalid or expired session")
        }
        
        return true
    }
    
    /// Invalidate a session
    /// - Parameter token: Session token to invalidate
    public func invalidateSession(_ token: UUID) async {
        sessions[token] = nil
    }
    
    /// Request a streaming session
    /// - Returns: A streaming session token
    /// - Throws: Error if streaming is unavailable
    public func requestStreamingSession() async throws -> UUID {
        // Create a new streaming session token
        let token = UUID()
        
        // Store it
        streamingSessions[token] = token
        
        return token
    }
    
    /// Release a streaming session
    /// - Parameter token: Streaming session token
    public func releaseStreamingSession(_ token: UUID) async {
        streamingSessions[token] = nil
    }
    
    /// Clean up expired sessions
    public func cleanupExpiredSessions() async {
        let now = Date()
        
        // Remove expired sessions
        sessions = sessions.filter { _, session in
            session.expiresAt > now
        }
    }
    
    /// Create a new session
    /// - Parameter username: Username
    /// - Returns: The new session
    private func createSession(username: String) -> Session {
        let sessionId = UUID()
        let createdAt = Date()
        let expiresAt = createdAt.addingTimeInterval(config.sessionDuration)
        
        let session = Session(
            id: sessionId,
            username: username,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
        
        // Store the session
        sessions[sessionId] = session
        
        return session
    }
} 