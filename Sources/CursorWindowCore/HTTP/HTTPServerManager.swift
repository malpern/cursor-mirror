import Vapor
import Foundation

/// Configuration options for the HTTP server
public struct HTTPServerConfig: Equatable {
    /// The hostname to bind to
    public let host: String
    
    /// The port to listen on
    public let port: Int
    
    /// Whether to enable TLS/SSL
    public let enableTLS: Bool
    
    /// Number of worker threads
    public let workerCount: Int
    
    /// Authentication configuration
    public let authentication: AuthenticationConfig
    
    /// Creates a new HTTP server configuration
    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        enableTLS: Bool = false,
        workerCount: Int = System.coreCount,
        authentication: AuthenticationConfig = .disabled
    ) {
        self.host = host
        self.port = port
        self.enableTLS = enableTLS
        self.workerCount = workerCount
        self.authentication = authentication
    }
}

/// Errors that can occur during HTTP server operations
public enum HTTPServerError: Error, Equatable {
    case serverAlreadyRunning
    case serverNotRunning
    case invalidConfiguration
    case streamError(String)
}

/// Manages an HTTP server for streaming HLS content
public actor HTTPServerManager {
    private let config: HTTPServerConfig
    private var app: Application?
    internal private(set) var isRunning: Bool = false
    private let streamManager: HLSStreamManager
    private let authManager: AuthenticationManager
    
    public init(config: HTTPServerConfig = HTTPServerConfig()) {
        self.config = config
        self.streamManager = HLSStreamManager()
        self.authManager = AuthenticationManager(config: config.authentication)
    }
    
    deinit {
        if let app = app {
            Task.detached {
                try? await app.server.shutdown()
            }
        }
    }
    
    /// Starts the HTTP server
    public func start() async throws {
        guard !isRunning else {
            throw HTTPServerError.serverAlreadyRunning
        }
        
        // Create the application
        let app = try await Application.make(.development)
        
        // Configure server settings
        app.http.server.configuration.hostname = config.host
        app.http.server.configuration.port = config.port
        
        // Configure middleware
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))
        
        // Add authentication middleware
        app.middleware.use(AuthMiddleware(authManager: authManager))
        
        // Configure routes
        try configureRoutes(app)
        
        // Start the server
        try await app.startup()
        self.app = app
        self.isRunning = true
        
        // Periodically clean up expired sessions
        Task.detached { [weak self] in
            while await self?.isRunning == true {
                await self?.authManager.cleanupExpiredSessions()
                try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            }
        }
    }
    
    /// Stops the HTTP server
    public func stop() async throws {
        guard let app = self.app, isRunning else {
            throw HTTPServerError.serverNotRunning
        }
        
        // Use async shutdown
        try await app.server.shutdown()
        
        self.app = nil
        self.isRunning = false
    }
    
    /// Update the authentication configuration
    public func updateAuthentication(_ config: AuthenticationConfig) async {
        await authManager.updateConfig(config)
    }
    
    /// Configure server routes
    private func configureRoutes(_ app: Application) throws {
        // Public routes
        
        // Health check endpoint
        app.get("health") { req -> String in
            "OK"
        }
        
        // Version endpoint
        app.get("version") { req -> String in
            "1.0.0"
        }
        
        // Authentication endpoints
        
        // Login endpoint
        app.post("auth", "login") { [authManager] req -> Response in
            guard let credentials = try? req.content.decode(LoginCredentials.self) else {
                throw Abort(.badRequest, reason: "Invalid login credentials")
            }
            
            do {
                let user = try await authManager.authenticateBasic(
                    username: credentials.username,
                    password: credentials.password
                )
                
                // Return the session token
                let response = Response(status: .ok)
                response.headers.contentType = .json
                try response.content.encode([
                    "token": user.id.uuidString,
                    "username": user.username,
                    "expiresAt": ISO8601DateFormatter().string(from: user.expiresAt)
                ])
                return response
            } catch {
                throw Abort(.unauthorized, reason: "Invalid credentials")
            }
        }
        
        // API key validation endpoint
        app.post("auth", "verify") { [authManager] req -> Response in
            guard let apiKeyData = try? req.content.decode(APIKeyData.self) else {
                throw Abort(.badRequest, reason: "Invalid API key data")
            }
            
            do {
                let user = try await authManager.authenticateApiKey(apiKeyData.apiKey)
                
                // Return the session token
                let response = Response(status: .ok)
                response.headers.contentType = .json
                try response.content.encode([
                    "token": user.id.uuidString,
                    "username": user.username,
                    "expiresAt": ISO8601DateFormatter().string(from: user.expiresAt)
                ])
                return response
            } catch {
                throw Abort(.unauthorized, reason: "Invalid API key")
            }
        }
        
        // Logout endpoint
        app.delete("auth", "logout") { [authManager] req -> Response in
            if let tokenStr = req.query[String.self, at: "token"],
               let token = UUID(uuidString: tokenStr) {
                await authManager.invalidateSession(token)
            }
            
            return Response(status: .ok)
        }
        
        // Protected or Semi-protected routes
        
        // Stream access endpoint - may be protected depending on configuration
        var streamRoutes: RoutesBuilder = app.routes
        
        if config.authentication.enabled {
            streamRoutes = app.routes.protected(using: authManager)
        }
            
        streamRoutes.post("stream", "access") { [streamManager] (req: Request) -> Response in
            do {
                let streamKey = try await streamManager.requestAccess()
                let response = Response(status: .ok)
                response.headers.contentType = .json
                try response.content.encode(["streamKey": streamKey.uuidString] as [String: String])
                return response
            } catch {
                let response = Response(status: .conflict)
                response.headers.contentType = .json
                try response.content.encode(["error": "Stream is currently in use"] as [String: String])
                return response
            }
        }
        
        // Stream content endpoints - check stream key for validation
        app.get("stream", "master.m3u8") { [streamManager] req -> Response in
            // Validate stream key from query parameter
            guard let streamKeyStr = req.query[String.self, at: "key"],
                  let streamKey = UUID(uuidString: streamKeyStr),
                  await streamManager.validateAccess(streamKey) else {
                return Response(status: .unauthorized)
            }
            
            // Generate a basic master playlist (placeholder implementation)
            let response = Response(status: .ok)
            response.headers.contentType = .init(type: "application", subType: "vnd.apple.mpegurl")
            response.headers.cacheControl = .init(noCache: true)
            response.body = .init(string: "#EXTM3U\n#EXT-X-VERSION:3\n")
            return response
        }
        
        // Media playlist endpoint
        app.get("stream", ":quality", "playlist.m3u8") { [streamManager] req -> Response in
            // Validate stream key from query parameter
            guard let streamKeyStr = req.query[String.self, at: "key"],
                  let streamKey = UUID(uuidString: streamKeyStr),
                  await streamManager.validateAccess(streamKey) else {
                return Response(status: .unauthorized)
            }
            
            // Generate a basic media playlist (placeholder implementation)
            let response = Response(status: .ok)
            response.headers.contentType = .init(type: "application", subType: "vnd.apple.mpegurl")
            response.headers.cacheControl = .init(noCache: true)
            response.body = .init(string: "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:2\n")
            return response
        }
        
        // Segment endpoint
        app.get("stream", ":quality", "segment_:index.ts") { [streamManager] req -> Response in
            // Validate stream key from query parameter
            guard let streamKeyStr = req.query[String.self, at: "key"],
                  let streamKey = UUID(uuidString: streamKeyStr),
                  await streamManager.validateAccess(streamKey) else {
                return Response(status: .unauthorized)
            }
            
            // Provide a basic response (placeholder implementation)
            let response = Response(status: .ok)
            response.headers.contentType = .init(type: "video", subType: "mp2t")
            response.headers.cacheControl = .init(noCache: true)
            return response
        }
        
        // Stream release endpoint
        app.delete("stream", "access") { [streamManager] req -> Response in
            guard let streamKeyStr = req.query[String.self, at: "key"],
                  let streamKey = UUID(uuidString: streamKeyStr) else {
                return Response(status: .badRequest)
            }
            
            await streamManager.releaseAccess(streamKey)
            return Response(status: .ok)
        }
        
        // Admin routes - always protected
        let adminRoutes = app.routes.grouped("admin").protected(using: authManager)
        
        // Server status endpoint
        adminRoutes.get("status") { [streamManager] req -> Response in
            let response = Response(status: .ok)
            response.headers.contentType = .json
            
            struct ServerStatus: Content {
                let serverRunning: Bool
                let streamActive: Bool
                let authEnabled: Bool
                let hostname: String
                let port: Int
            }
            
            try response.content.encode(ServerStatus(
                serverRunning: true,
                streamActive: await self.checkStreamActive(streamManager),
                authEnabled: await self.config.authentication.enabled,
                hostname: await self.config.host,
                port: await self.config.port
            ))
            
            return response
        }
    }
    
    /// Helper method to check if a stream is active
    private func checkStreamActive(_ streamManager: HLSStreamManager) async -> Bool {
        // Try to request access, if it fails with streamInUse, there's an active stream
        do {
            let token = try await streamManager.requestAccess()
            // If we got here, there was no active stream, so release the token we just got
            await streamManager.releaseAccess(token)
            return false
        } catch {
            // If we can't get access, assume it's because a stream is active
            return true
        }
    }
}

// MARK: - Authentication model types

/// Credentials for basic authentication login
private struct LoginCredentials: Content {
    let username: String
    let password: String
}

/// Data for API key authentication
private struct APIKeyData: Content {
    let apiKey: String
}

// MARK: - HLSStreamManager Extension

extension HLSStreamManager {
    /// Check if there is an active stream
    var hasActiveStream: Bool {
        get async {
            // Try to request access, if it fails with streamInUse, there's an active stream
            do {
                let token = try await requestAccess()
                // If we got here, there was no active stream, so release the token we just got
                await releaseAccess(token)
                return false
            } catch {
                // If we can't get access, assume it's because a stream is active
                return true
            }
        }
    }
} 