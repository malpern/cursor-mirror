import Vapor
import Foundation
import NIOSSL
import Leaf

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
    
    /// CORS configuration
    public let cors: CORSConfiguration
    
    /// Request logging configuration
    public let logging: RequestLoggingConfiguration
    
    /// Rate limiting configuration
    public let rateLimit: RateLimitConfiguration
    
    /// Configuration for the admin dashboard
    public struct AdminDashboard {
        /// Whether the admin dashboard is enabled
        public var enabled: Bool
        
        /// Whether to serve static assets for the admin dashboard
        public var serveAssets: Bool
        
        /// Initialize admin dashboard configuration
        public init(enabled: Bool = true, serveAssets: Bool = true) {
            self.enabled = enabled
            self.serveAssets = serveAssets
        }
    }
    
    /// Admin dashboard configuration
    public var admin: AdminDashboard
    
    /// Creates a new HTTP server configuration
    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        enableTLS: Bool = false,
        workerCount: Int = System.coreCount,
        authentication: AuthenticationConfig = .disabled,
        cors: CORSConfiguration = .permissive,
        logging: RequestLoggingConfiguration = .basic,
        rateLimit: RateLimitConfiguration = .standard,
        admin: AdminDashboard = AdminDashboard()
    ) {
        self.host = host
        self.port = port
        self.enableTLS = enableTLS
        self.workerCount = workerCount
        self.authentication = authentication
        self.cors = cors
        self.logging = logging
        self.rateLimit = rateLimit
        self.admin = admin
    }
}

/// CORS configuration for the HTTP server
public struct CORSConfiguration: Equatable {
    /// Allowed origin domains
    public let allowedOrigin: String
    
    /// Allowed HTTP methods
    public let allowedMethods: [HTTPMethod]
    
    /// Allowed HTTP headers
    public let allowedHeaders: [HTTPHeaders.Name]
    
    /// Whether to allow credentials
    public let allowCredentials: Bool
    
    /// Max age for preflight requests in seconds
    public let cacheExpiration: Int
    
    /// Whether CORS is enabled
    public let isEnabled: Bool
    
    /// Creates a new CORS configuration
    public init(
        allowedOrigin: String = "*",
        allowedMethods: [HTTPMethod] = [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [HTTPHeaders.Name] = [.accept, .authorization, .contentType, .origin, "X-Requested-With"],
        allowCredentials: Bool = false,
        cacheExpiration: Int = 600,
        isEnabled: Bool = true
    ) {
        self.allowedOrigin = allowedOrigin
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.allowCredentials = allowCredentials
        self.cacheExpiration = cacheExpiration
        self.isEnabled = isEnabled
    }
    
    /// Permissive CORS configuration that allows all origins
    public static let permissive = CORSConfiguration()
    
    /// Disabled CORS configuration
    public static let disabled = CORSConfiguration(isEnabled: false)
    
    /// Strict CORS configuration for a specific origin
    public static func strict(origin: String) -> CORSConfiguration {
        CORSConfiguration(allowedOrigin: origin, allowCredentials: true)
    }
}

/// Request logging configuration for the HTTP server
public struct RequestLoggingConfiguration: Equatable {
    /// Log levels for different status code ranges
    public enum LogLevel: Equatable {
        case debug
        case info
        case notice
        case warning
        case error
        case critical
        
        /// Converts to Vapor's Logger.Level
        var vaporLevel: Logger.Level {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .notice: return .notice
            case .warning: return .warning
            case .error: return .error
            case .critical: return .critical
            }
        }
    }
    
    /// Log level for successful responses (2xx)
    public let successLevel: LogLevel
    
    /// Log level for redirect responses (3xx)
    public let redirectLevel: LogLevel
    
    /// Log level for client error responses (4xx)
    public let clientErrorLevel: LogLevel
    
    /// Log level for server error responses (5xx)
    public let serverErrorLevel: LogLevel
    
    /// Request paths to exclude from logging
    public let excludedPaths: [String]
    
    /// Whether to log request bodies
    public let logRequestBodies: Bool
    
    /// Whether to log response bodies
    public let logResponseBodies: Bool
    
    /// Whether request logging is enabled
    public let isEnabled: Bool
    
    /// Creates a new request logging configuration
    public init(
        successLevel: LogLevel = .info,
        redirectLevel: LogLevel = .notice,
        clientErrorLevel: LogLevel = .warning,
        serverErrorLevel: LogLevel = .error,
        excludedPaths: [String] = ["/health", "/version", "/favicon.ico"],
        logRequestBodies: Bool = false,
        logResponseBodies: Bool = false,
        isEnabled: Bool = true
    ) {
        self.successLevel = successLevel
        self.redirectLevel = redirectLevel
        self.clientErrorLevel = clientErrorLevel
        self.serverErrorLevel = serverErrorLevel
        self.excludedPaths = excludedPaths
        self.logRequestBodies = logRequestBodies
        self.logResponseBodies = logResponseBodies
        self.isEnabled = isEnabled
    }
    
    /// Basic logging configuration that logs only status codes
    public static let basic = RequestLoggingConfiguration()
    
    /// Disabled logging configuration
    public static let disabled = RequestLoggingConfiguration(isEnabled: false)
    
    /// Verbose logging configuration that includes request and response bodies
    public static let verbose = RequestLoggingConfiguration(
        excludedPaths: ["/health", "/favicon.ico"],
        logRequestBodies: true,
        logResponseBodies: true
    )
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
    private var rateLimiter: RateLimiter?
    private var adminController: AdminController?
    
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
        
        // Configure routes and middleware
        try configureRoutes(app)
        
        // Start the server
        try await app.startup()
        self.app = app
        self.isRunning = true
        
        // Start maintenance tasks
        startMaintenanceTasks()
    }
    
    /// Starts background maintenance tasks
    private func startMaintenanceTasks() {
        // Task for cleaning up expired sessions
        Task.detached { [weak self] in
            while await self?.isRunning == true {
                await self?.authManager.cleanupExpiredSessions()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            }
        }
        
        // Task for cleaning up rate limit buckets
        if config.rateLimit.isEnabled, let rateLimiter = rateLimiter {
            Task.detached { [weak self] in
                while await self?.isRunning == true {
                    await rateLimiter.cleanupExpiredBuckets()
                    try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                }
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
        // Configure middleware in proper order
        
        // 1. First add request logging if enabled
        if config.logging.isEnabled {
            app.middleware.use(RequestLoggerMiddleware(
                configuration: config.logging,
                logger: app.logger
            ))
        }
        
        // 2. Add rate limiting if enabled
        if config.rateLimit.isEnabled {
            self.rateLimiter = app.enableRateLimiting(config.rateLimit)
        }
        
        // 3. Add CORS if enabled
        if config.cors.isEnabled {
            let corsConfiguration = CORSMiddleware.Configuration(
                allowedOrigin: .custom(config.cors.allowedOrigin),
                allowedMethods: config.cors.allowedMethods,
                allowedHeaders: config.cors.allowedHeaders,
                allowCredentials: config.cors.allowCredentials,
                cacheExpiration: config.cors.cacheExpiration
            )
            let corsMiddleware = CORSMiddleware(configuration: corsConfiguration)
            app.middleware.use(corsMiddleware)
        }
        
        // 4. Add static file middleware
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        
        // 5. Add error middleware
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))
        
        // 6. Add authentication middleware
        app.middleware.use(AuthMiddleware(authManager: authManager))
        
        // Configure route handlers
        configureRouteHandlers(app)
    }
    
    /// Configure route handlers
    private func configureRouteHandlers(_ app: Application) {
        // Public routes
        
        // Health check endpoint
        app.get("health") { req -> String in
            "OK"
        }
        
        // Version endpoint
        app.get("version") { req -> String in
            "1.0.0"
        }
        
        // Authentication endpoints - apply stricter rate limits
        let authRoutes = app.routes.grouped("auth")
        
        if config.rateLimit.isEnabled, let rateLimiter = rateLimiter {
            // Create a stricter rate limiter for auth endpoints
            let authRateLimiter = RateLimiter(configuration: .strict)
            
            // Apply stricter rate limits to auth endpoints
            authRoutes.rateLimited(using: authRateLimiter)
        }
        
        // Login endpoint
        authRoutes.post("login") { [authManager] req -> Response in
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
        authRoutes.post("verify") { [authManager] req -> Response in
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
        authRoutes.delete("logout") { [authManager] req -> Response in
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
    
    /// Configures the application routes
    private func configureRoutes(_ app: Application) {
        app.middleware.use(RequestLoggerMiddleware(
            configuration: config.logging,
            logger: app.logger
        ))
        
        // Set up CORS if enabled
        if config.cors.isEnabled {
            app.middleware.use(CORSMiddleware(configuration: config.cors))
        }
        
        // Set up rate limiting if enabled
        if config.rateLimit.isEnabled {
            let rateLimiter = app.enableRateLimiting(config.rateLimit)
            app.middleware.use(RateLimitMiddleware(rateLimiter: rateLimiter, excludedPaths: config.rateLimit.excludedPaths))
            
            // Set up the bucket cleanup task
            let cleanupInterval = config.rateLimit.cleanupInterval * 60
            app.eventLoopGroup.next().scheduleRepeatedTask(initialDelay: .seconds(cleanupInterval), delay: .seconds(cleanupInterval)) { task in
                rateLimiter.cleanupExpiredBuckets()
            }
            
            // Set up stricter rate limits for auth routes
            let authRateLimiter = RateLimiter(configuration: config.rateLimit.stricterForAuth())
            self.rateLimiter = rateLimiter
            
            let authRoutes = app.grouped("auth")
                .grouped(RateLimitMiddleware(rateLimiter: authRateLimiter))
            
            // Configure auth routes with authentication
            configureAuthRoutes(authRoutes)
        } else {
            // Configure auth routes without rate limiting
            let authRoutes = app.grouped("auth")
            configureAuthRoutes(authRoutes)
        }
        
        // Configure stream routes
        configureStreamRoutes(app)
        
        // Setup admin dashboard if enabled
        if config.admin.enabled {
            let leafResolver = LeafRenderer(configuration: .init(viewsDirectory: "Resources/Views"), viewsDirectory: "Resources/Views", eventLoop: app.eventLoopGroup.next())
            
            app.views.use(.leaf)
            
            // Create the admin controller
            let adminController = AdminController(httpServer: self, hlsManager: streamManager, authManager: authManager)
            adminController.setupRoutes(app)
            self.adminController = adminController
            
            // Serve static assets if enabled
            if config.admin.serveAssets {
                app.middleware.use(FileMiddleware(publicDirectory: "Public"))
            }
        }
    }
    
    // Request logging middleware will call this to record requests for the admin dashboard
    public func recordRequest(method: String, path: String, statusCode: Int, ipAddress: String, duration: Double, details: String? = nil) {
        guard let adminController = adminController else { return }
        
        let requestLog = AdminController.RequestLog(
            id: UUID(),
            timestamp: Date(),
            method: method,
            path: path,
            statusCode: statusCode,
            ipAddress: ipAddress,
            duration: duration,
            details: details
        )
        
        Task {
            await adminController.recordRequest(requestLog)
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

/// Middleware for logging HTTP requests and responses
struct RequestLoggerMiddleware: AsyncMiddleware {
    let configuration: RequestLoggingConfiguration
    let logger: Logger
    
    init(configuration: RequestLoggingConfiguration, logger: Logger) {
        self.configuration = configuration
        self.logger = logger
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Skip logging for excluded paths
        if configuration.excludedPaths.contains(request.url.path) {
            return try await next.respond(to: request)
        }
        
        // Log request details
        let startTime = Date()
        let requestId = request.headers.first(name: "X-Request-ID") ?? UUID().uuidString
        
        // Log request
        var requestLog = "[\(request.method)] \(request.url.path)"
        if let query = request.url.query, !query.isEmpty {
            requestLog += "?\(query)"
        }
        
        logger.debug("\(requestId) Request: \(requestLog)")
        
        if configuration.logRequestBodies, 
           let body = request.body.data, 
           let bodyString = body.getString(at: body.readerIndex, length: body.readableBytes),
           !bodyString.isEmpty {
            logger.debug("\(requestId) Request body: \(bodyString)")
        }
        
        // Process the request and capture response
        let response: Response
        do {
            response = try await next.respond(to: request)
        } catch {
            // Log errors
            logger.error("\(requestId) Error: \(error)")
            throw error
        }
        
        // Calculate duration
        let duration = Date().timeIntervalSince(startTime)
        let durationMs = Int(duration * 1000)
        
        // Determine log level based on status code
        let logLevel: RequestLoggingConfiguration.LogLevel
        switch response.status.code {
        case 200..<300:
            logLevel = configuration.successLevel
        case 300..<400:
            logLevel = configuration.redirectLevel
        case 400..<500:
            logLevel = configuration.clientErrorLevel
        default:
            logLevel = configuration.serverErrorLevel
        }
        
        // Create log message
        var logMessage = "\(requestId) Response: \(response.status.code) \(response.status.reasonPhrase) (\(durationMs)ms)"
        
        // Log with appropriate level
        switch logLevel {
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .notice:
            logger.notice("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .critical:
            logger.critical("\(logMessage)")
        }
        
        // Log response body if enabled
        if configuration.logResponseBodies, 
           let body = response.body,
           let bodyString = body.getString(at: 0, length: body.readableBytes),
           !bodyString.isEmpty {
            logger.debug("\(requestId) Response body: \(bodyString)")
        }
        
        return response
    }
} 