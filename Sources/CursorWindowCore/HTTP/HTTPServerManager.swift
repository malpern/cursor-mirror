import Vapor
import Foundation
import NIOSSL
import Leaf
import Metrics
import SwiftPrometheus

/// Configuration options for the HTTP server
public struct HTTPServerConfig: Equatable {
    /// The hostname or IP address to bind to
    public let hostname: String
    
    /// The port to bind to
    public let port: Int
    
    /// The address of the server
    public var address: String {
        return "http\(useSSL ? "s" : "")://\(hostname):\(port)"
    }
    
    /// Whether to enable SSL/TLS
    public let useSSL: Bool
    
    /// Path to SSL certificate
    public let sslCert: String?
    
    /// Path to SSL private key
    public let sslKey: String?
    
    /// Enable admin dashboard
    public let enableAdmin: Bool
    
    /// Admin username
    public let adminUsername: String
    
    /// Admin password
    public let adminPassword: String
    
    /// Maximum request log entries to keep
    public let maxRequestLogs: Int
    
    /// Whether to enable CORS
    public let enableCORS: Bool
    
    /// Security configuration
    public let security: SecurityConfiguration
    
    /// Middleware configuration
    public let middleware: MiddlewareConfig
    
    /// Whether to enable CloudKit integration
    public let enableCloudKit: Bool
    
    /// Authentication configuration
    public let authentication: AuthenticationConfig
    
    /// Whether to limit streaming to a single viewer
    public let singleViewerOnly: Bool
    
    /// Create a new HTTP server configuration
    public init(
        hostname: String = "127.0.0.1",
        port: Int = 8080,
        useSSL: Bool = false,
        sslCert: String? = nil,
        sslKey: String? = nil,
        enableAdmin: Bool = true,
        adminUsername: String = "admin",
        adminPassword: String = "password",
        maxRequestLogs: Int = 100,
        enableCORS: Bool = true,
        security: SecurityConfiguration = .standard,
        middleware: MiddlewareConfig = .standard,
        enableCloudKit: Bool = false,
        authentication: AuthenticationConfig = .basic(username: "admin", password: "admin"),
        singleViewerOnly: Bool = false
    ) {
        self.hostname = hostname
        self.port = port
        self.useSSL = useSSL
        self.sslCert = sslCert
        self.sslKey = sslKey
        self.enableAdmin = enableAdmin
        self.adminUsername = adminUsername
        self.adminPassword = adminPassword
        self.maxRequestLogs = maxRequestLogs
        self.enableCORS = enableCORS
        self.security = security
        self.middleware = middleware
        self.enableCloudKit = enableCloudKit
        self.authentication = authentication
        self.singleViewerOnly = singleViewerOnly
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

/// Configuration for the metrics collection
public struct MetricsConfiguration: Equatable {
    /// Whether metrics collection is enabled
    public let isEnabled: Bool
    
    /// Metrics collection interval in seconds
    public let collectInterval: Double
    
    /// Whether to expose Prometheus metrics endpoint
    public let exposePrometheusEndpoint: Bool
    
    /// Create a new metrics configuration
    public init(
        isEnabled: Bool = true,
        collectInterval: Double = 30.0,
        exposePrometheusEndpoint: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.collectInterval = collectInterval
        self.exposePrometheusEndpoint = exposePrometheusEndpoint
    }
    
    /// Standard metrics configuration with all features enabled
    public static let standard = MetricsConfiguration()
    
    /// Minimal metrics configuration with only basic metrics
    public static let minimal = MetricsConfiguration(
        isEnabled: true,
        collectInterval: 60.0,
        exposePrometheusEndpoint: false
    )
    
    /// Disabled metrics configuration
    public static let disabled = MetricsConfiguration(
        isEnabled: false,
        collectInterval: 0,
        exposePrometheusEndpoint: false
    )
}

/// Errors that can occur during HTTP server operations
public enum HTTPServerError: Error, Equatable {
    case serverAlreadyRunning
    case serverNotRunning
    case invalidConfiguration
    case streamError(String)
    case sslConfigurationError
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
    
    // Add metrics properties
    private var requestCounter: CounterHandler?
    private var activeConnectionsGauge: GaugeHandler?
    private var requestDurationHistogram: TimerHandler?
    private var segmentSizeHistogram: HistogramHandler?
    private var lastMetricsCollection: Date?
    private var metricsTimer: Task<Void, Error>?
    
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
        let app = try await configureApp()
        
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
        
        // 0. Add HTTP to HTTPS redirect if enabled and TLS is enabled
        if config.middleware.forceHTTPS && config.useSSL {
            app.middleware.use(HTTPSRedirectMiddleware())
        }
        
        // 1. Add secure headers middleware if enabled
        if config.middleware.addSecureHeaders {
            app.middleware.use(SecureHeadersMiddleware(config: config.security))
        }
        
        // 2. Add DoS protection if enabled
        if config.security.dosProtection.enabled {
            app.middleware.use(DoSProtectionMiddleware(config: config.security.dosProtection))
        }
        
        // 3. Add request validation middleware
        app.middleware.use(RequestValidationMiddleware(
            maxBodySize: config.middleware.maxBodySize,
            maxMultipartSize: config.middleware.maxMultipartSize
        ))
        
        // 4. Then add request logging if enabled
        if config.logging.isEnabled {
            app.middleware.use(RequestLoggerMiddleware(
                configuration: config.logging,
                logger: app.logger
            ))
        }
        
        // 5. Add rate limiting if enabled
        if config.rateLimit.isEnabled {
            self.rateLimiter = app.enableRateLimiting(config.rateLimit)
        }
        
        // 6. Add CORS if enabled
        if config.enableCORS {
            let corsConfiguration = CORSMiddleware.Configuration(
                allowedOrigin: .custom(config.allowedOrigin),
                allowedMethods: config.allowedMethods,
                allowedHeaders: config.allowedHeaders,
                allowCredentials: config.allowCredentials,
                cacheExpiration: config.cacheExpiration
            )
            let corsMiddleware = CORSMiddleware(configuration: corsConfiguration)
            app.middleware.use(corsMiddleware)
        }
        
        // 7. Add static file middleware
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        
        // 8. Add error middleware
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))
        
        // 9. Add authentication middleware
        app.middleware.use(AuthMiddleware(authManager: authManager))
        
        // 10. Add CloudKit authentication middleware if enabled
        if config.enableCloudKit {
            #if os(macOS)
            app.middleware.use(CloudKitAuthMiddleware(authManager: authManager))
            #endif
        }
        
        // Configure route handlers
        configureRouteHandlers(app)
        
        // Add metrics middleware if enabled
        if config.metrics.isEnabled {
            app.middleware.use(MetricsMiddleware(recordMetrics: { req, res, startTime in
                await self.recordRequestMetrics(req: req, startTime: startTime, status: res.status)
            }))
        }
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
            
        streamRoutes.post("stream", "access") { [streamManager, authManager] (req: Request) -> Response in
            do {
                // First try to request a streaming session from the auth manager (handles single viewer case)
                let sessionId = try await authManager.requestStreamingSession()
                
                // Then try to request access from the stream manager
                let streamKey = try await streamManager.requestAccess()
                
                // Return both keys in the response
                let response = Response(status: .ok)
                response.headers.contentType = .json
                try response.content.encode([
                    "streamKey": streamKey.uuidString,
                    "sessionId": sessionId.uuidString
                ] as [String: String])
                
                return response
            } catch AuthenticationManager.StreamError.streamInUse {
                // Stream is already in use by another viewer
                let response = Response(status: .conflict)
                response.headers.contentType = .json
                try response.content.encode(["error": "Stream is already being viewed by another user"] as [String: String])
                return response
            } catch {
                // Other errors (like HLSStreamManager.StreamError.streamInUse)
                let response = Response(status: .conflict)
                response.headers.contentType = .json
                try response.content.encode(["error": "Stream is currently in use"] as [String: String])
                return response
            }
        }
        
        // Add a new endpoint to release a stream session
        streamRoutes.post("stream", "release") { [streamManager, authManager] (req: Request) -> Response in
            if let streamKeyStr = try? req.content.get(String.self, at: "streamKey"),
               let streamKey = UUID(uuidString: streamKeyStr),
               let sessionIdStr = try? req.content.get(String.self, at: "sessionId"),
               let sessionId = UUID(uuidString: sessionIdStr) {
                
                // Release both the stream access and the session
                await streamManager.releaseAccess(streamKey)
                await authManager.releaseStreamingSession(sessionId)
                
                return Response(status: .ok)
            }
            
            return Response(status: .badRequest)
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
        
        // Video segment routes
        app.get("stream", ":quality", "video", ":filename") { req -> Response in
            let startTime = Date()
            
            guard let quality = req.parameters.get("quality"),
                  let filename = req.parameters.get("filename") else {
                throw Abort(.badRequest, reason: "Invalid segment request")
            }
            
            // Check if this is a range request
            var range: HTTPRange? = nil
            if let rangeHeader = req.headers.first(name: "Range") {
                range = HTTPRange.parse(from: rangeHeader)
            }
            
            // Get segment data with possible range
            let (data, headers) = try await self.videoSegmentHandler.getSegmentData(
                quality: quality,
                filename: filename,
                range: range
            )
            
            // Record metrics for this segment delivery
            self.recordSegmentMetrics(quality: quality, size: data.count)
            
            var response = Response(status: range != nil ? .partialContent : .ok)
            response.body = .init(data: data)
            
            // Add headers
            for (key, value) in headers {
                response.headers.add(name: key, value: value)
            }
            
            // Record request metrics
            await self.recordRequestMetrics(req: req, startTime: startTime, status: response.status)
            
            return response
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
        if config.enableCORS {
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
        if config.enableAdmin {
            let leafResolver = LeafRenderer(configuration: .init(viewsDirectory: "Resources/Views"), viewsDirectory: "Resources/Views", eventLoop: app.eventLoopGroup.next())
            
            app.views.use(.leaf)
            
            // Create the admin controller
            let adminController = AdminController(httpServer: self, hlsManager: streamManager, authManager: authManager)
            adminController.setupRoutes(app)
            self.adminController = adminController
            
            // Serve static assets if enabled
            if config.serveAssets {
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
    
    private func configureApp() async throws -> Application {
        // Configure server
        var serverConfig = HTTPServer.Configuration.default(
            hostname: config.host,
            port: config.port
        )
        
        // Configure TLS if enabled
        if config.useSSL {
            if let sslCert = config.sslCert, let sslKey = config.sslKey {
                // Use provided SSL certificate and key
                serverConfig.tlsConfiguration = .makeServerConfiguration(
                    certificateChain: [.certificate(.init(file: sslCert, format: .pem))],
                    privateKey: .file(sslKey)
                )
            } else if let sslCert = config.sslCert {
                // Create configuration from SSL certificate
                let certificatePath = sslCert
                let keyPath = config.sslKey ?? ""
                
                guard FileManager.default.fileExists(atPath: certificatePath),
                      FileManager.default.fileExists(atPath: keyPath) else {
                    logger.error("SSL certificate not found at \(certificatePath) and key at \(keyPath)")
                    throw HTTPServerError.sslConfigurationError
                }
                
                serverConfig.tlsConfiguration = .makeServerConfiguration(
                    certificateChain: [.certificate(.init(file: certificatePath, format: .pem))],
                    privateKey: .file(keyPath)
                )
            } else if let sslKey = config.sslKey {
                // Create configuration from SSL key
                let keyPath = sslKey
                
                guard FileManager.default.fileExists(atPath: keyPath) else {
                    logger.error("SSL key not found at \(keyPath)")
                    throw HTTPServerError.sslConfigurationError
                }
                
                serverConfig.tlsConfiguration = .makeServerConfiguration(
                    certificateChain: [.certificate(.generate(commonName: config.host))],
                    privateKey: .file(keyPath)
                )
            } else {
                logger.warning("SSL enabled but no certificates provided, generating self-signed certificate")
                
                // Generate self-signed certificate
                serverConfig.tlsConfiguration = try .makeServerConfiguration(
                    certificateChain: [.certificate(.generate(commonName: config.host))],
                    privateKey: .generated
                )
            }
        }
        
        // Create app with configuration
        var app = Application(Environment.development)
        app.http.server.configuration = serverConfig
        app.http.server.configuration.supportVersions = [HTTPVersion(major: 1, minor: 1), HTTPVersion(major: 2, minor: 0)]
        
        // Configure metrics if enabled
        if config.metrics.isEnabled {
            configureMetrics(app: &app)
        }
        
        return app
    }
    
    // Set up metrics collection
    private func configureMetrics(app: inout Application) {
        // Register Prometheus client
        let prometheusClient = PrometheusClient()
        MetricsSystem.bootstrap(prometheusClient)
        
        // Create metrics
        requestCounter = Counter(
            label: "http_requests_total",
            dimensions: [
                ("method", ""),
                ("path", ""),
                ("status", "")
            ]
        )
        
        activeConnectionsGauge = Gauge(
            label: "http_active_connections"
        )
        
        requestDurationHistogram = Timer(
            label: "http_request_duration_seconds",
            dimensions: [
                ("method", ""),
                ("path", "")
            ]
        )
        
        segmentSizeHistogram = Histogram(
            label: "video_segment_size_bytes",
            dimensions: [
                ("quality", "")
            ],
            buckets: [.exponential(start: 10_000, factor: 2, count: 10)]
        )
        
        // Add Prometheus metrics endpoint if enabled
        if config.metrics.exposePrometheusEndpoint {
            app.get("metrics") { req -> Response in
                var headers = HTTPHeaders()
                headers.add(name: .contentType, value: "text/plain; version=0.0.4")
                
                return Response(
                    status: .ok,
                    headers: headers,
                    body: .init(string: prometheusClient.collect())
                )
            }
        }
        
        // Start metrics collection timer
        startMetricsCollectionTimer()
    }
    
    // Start periodic metrics collection
    private func startMetricsCollectionTimer() {
        guard config.metrics.isEnabled, config.metrics.collectInterval > 0 else { return }
        
        metricsTimer = Task {
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: UInt64(config.metrics.collectInterval * 1_000_000_000))
                await collectMetrics()
            }
        }
    }
    
    // Record metrics for a segment request
    private func recordSegmentMetrics(quality: String, size: Int) {
        guard config.metrics.isEnabled, let histogram = segmentSizeHistogram else { return }
        
        histogram.record(Double(size), dimensions: [("quality", quality)])
    }
    
    // Collect current metrics
    private func collectMetrics() async {
        guard config.metrics.isEnabled else { return }
        
        lastMetricsCollection = Date()
        
        if let gauge = activeConnectionsGauge {
            let connections = await streamManager.activeConnectionCount()
            gauge.record(Double(connections))
        }
        
        // Additional metrics collection can be added here
    }
    
    // Record HTTP request metrics
    private func recordRequestMetrics(req: Request, startTime: Date, status: HTTPStatus) {
        guard config.metrics.isEnabled else { return }
        
        let pathString = req.url.path
        let methodString = req.method.string
        
        // Record request count
        requestCounter?.increment(
            dimensions: [
                ("method", methodString),
                ("path", pathString),
                ("status", String(status.code))
            ]
        )
        
        // Record request duration
        let duration = Date().timeIntervalSince(startTime)
        requestDurationHistogram?.record(
            duration,
            dimensions: [
                ("method", methodString),
                ("path", pathString)
            ]
        )
    }
    
    // Update configureRoutes to include metrics
    private func configureRoutes() throws {
        // ... existing code ...
        
        // Update video segment route to collect metrics
        app.get("stream", ":quality", "video", ":filename") { req -> Response in
            let startTime = Date()
            
            guard let quality = req.parameters.get("quality"),
                  let filename = req.parameters.get("filename") else {
                throw Abort(.badRequest, reason: "Invalid segment request")
            }
            
            // Check if this is a range request
            var range: HTTPRange? = nil
            if let rangeHeader = req.headers.first(name: "Range") {
                range = HTTPRange.parse(from: rangeHeader)
            }
            
            // Get segment data with possible range
            let (data, headers) = try await self.videoSegmentHandler.getSegmentData(
                quality: quality,
                filename: filename,
                range: range
            )
            
            // Record metrics for this segment delivery
            self.recordSegmentMetrics(quality: quality, size: data.count)
            
            var response = Response(status: range != nil ? .partialContent : .ok)
            response.body = .init(data: data)
            
            // Add headers
            for (key, value) in headers {
                response.headers.add(name: key, value: value)
            }
            
            // Record request metrics
            await self.recordRequestMetrics(req: req, startTime: startTime, status: response.status)
            
            return response
        }
        
        // ... existing code ...
    }
    
    // Update shutdown to clean up metrics
    public func shutdown() async throws {
        // Cancel metrics collection timer
        metricsTimer?.cancel()
        metricsTimer = nil
        
        // Existing shutdown code
        try await app?.shutdown()
        app = nil
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

// Middleware for metrics collection
private struct MetricsMiddleware: AsyncMiddleware {
    let recordMetrics: (Request, Response, Date) async -> Void
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let startTime = Date()
        let response = try await next.respond(to: request)
        await recordMetrics(request, response, startTime)
        return response
    }
}

/// Middleware to redirect HTTP requests to HTTPS
struct HTTPSRedirectMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Only redirect if the request is not secure
        guard !request.application.http.server.configuration.tlsConfiguration?.certificateVerification.isEnabled ?? false else {
            return next.respond(to: request)
        }
        
        // Get the host from the request
        guard let host = request.headers.first(name: .host) else {
            return next.respond(to: request)
        }
        
        // Create the redirect URL
        let redirectURL = "https://\(host)\(request.url.path)"
        
        // Create and return a redirect response
        let response = Response(status: .permanentRedirect)
        response.headers.replaceOrAdd(name: .location, value: redirectURL)
        return request.eventLoop.makeSucceededFuture(response)
    }
}

/// Middleware to add security headers to responses
struct SecureHeadersMiddleware: Middleware {
    let config: SecurityConfiguration
    
    init(config: SecurityConfiguration) {
        self.config = config
    }
    
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        return next.respond(to: request).map { response in
            // Add CSP header if enabled
            if config.csp.enabled {
                response.headers.replaceOrAdd(
                    name: HTTPHeaders.Name(config.csp.headerName),
                    value: config.csp.headerValue
                )
            }
            
            // Add HSTS header if enabled
            if config.enableHSTS {
                response.headers.replaceOrAdd(
                    name: "Strict-Transport-Security",
                    value: "max-age=31536000; includeSubDomains"
                )
            }
            
            // Add X-Frame-Options header if configured
            if let xFrameOptions = config.xFrameOptions {
                response.headers.replaceOrAdd(
                    name: "X-Frame-Options",
                    value: xFrameOptions
                )
            }
            
            // Add X-Content-Type-Options header if configured
            if let xContentTypeOptions = config.xContentTypeOptions {
                response.headers.replaceOrAdd(
                    name: "X-Content-Type-Options", 
                    value: xContentTypeOptions
                )
            }
            
            // Add Referrer-Policy header if configured
            if let referrerPolicy = config.referrerPolicy {
                response.headers.replaceOrAdd(
                    name: "Referrer-Policy",
                    value: referrerPolicy
                )
            }
            
            return response
        }
    }
}

/// Middleware to protect against DoS attacks
struct DoSProtectionMiddleware: Middleware {
    let config: SecurityConfiguration.DoSProtection
    private var connectionCounter = AtomicInteger(value: 0)
    private var activeConnections = [String: Date]()
    private let lock = NSLock()
    
    init(config: SecurityConfiguration.DoSProtection) {
        self.config = config
    }
    
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Get client IP
        let clientIP = request.remoteAddress?.ipAddress ?? "unknown"
        
        // Check if connection count exceeds limit
        let currentConnections = connectionCounter.add(1)
        if currentConnections > config.maxConnections {
            connectionCounter.sub(1)
            return request.eventLoop.makeFailedFuture(Abort(.tooManyRequests, reason: "Too many concurrent connections"))
        }
        
        // Check for connection frequency from the same IP
        let shouldBlock = checkRateLimit(for: clientIP)
        if shouldBlock {
            connectionCounter.sub(1)
            return request.eventLoop.makeFailedFuture(Abort(.tooManyRequests, reason: "Rate limit exceeded"))
        }
        
        // Process the request
        return next.respond(to: request).always { _ in
            // Release the connection count
            connectionCounter.sub(1)
        }
    }
    
    private func checkRateLimit(for ip: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        
        // Clean up expired records
        activeConnections = activeConnections.filter { now.timeIntervalSince($0.value) < Double(config.resetTimeout) }
        
        // Check if this IP already has a connection
        if let lastConnection = activeConnections[ip] {
            // If the last connection was very recent, may be a DoS attempt
            if now.timeIntervalSince(lastConnection) < 0.1 { // 100ms
                return true
            }
        }
        
        // Update the last connection time
        activeConnections[ip] = now
        return false
    }
}

/// Simple atomic integer for thread-safe counting
class AtomicInteger {
    private var value: Int
    private let lock = NSLock()
    
    init(value: Int) {
        self.value = value
    }
    
    func add(_ delta: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += delta
        return value
    }
    
    func sub(_ delta: Int) -> Int {
        add(-delta)
    }
}

/// Middleware to validate request data
struct RequestValidationMiddleware: Middleware {
    let maxBodySize: Int
    let maxMultipartSize: Int
    
    init(maxBodySize: Int, maxMultipartSize: Int) {
        self.maxBodySize = maxBodySize
        self.maxMultipartSize = maxMultipartSize
    }
    
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Check content length if available
        if let contentLengthStr = request.headers.first(name: "Content-Length"),
           let contentLength = Int(contentLengthStr),
           contentLength > maxBodySize {
            return request.eventLoop.makeFailedFuture(
                Abort(.payloadTooLarge, reason: "Request body too large")
            )
        }
        
        // Check content type for multipart forms
        if let contentType = request.headers.first(name: "Content-Type"),
           contentType.contains("multipart/form-data"),
           let contentLengthStr = request.headers.first(name: "Content-Length"),
           let contentLength = Int(contentLengthStr),
           contentLength > maxMultipartSize {
            return request.eventLoop.makeFailedFuture(
                Abort(.payloadTooLarge, reason: "Multipart form data too large")
            )
        }
        
        // Validate URL for path traversal attempts
        if request.url.path.contains("..") || request.url.path.contains("//") {
            return request.eventLoop.makeFailedFuture(
                Abort(.badRequest, reason: "Invalid URL path")
            )
        }
        
        return next.respond(to: request)
    }
}

/// Security configuration for the HTTP server
public struct SecurityConfiguration: Equatable {
    /// Content Security Policy configuration
    public struct CSP: Equatable {
        /// Whether CSP is enabled
        public let enabled: Bool
        
        /// Policy directives for CSP
        public let directives: [String: String]
        
        /// Whether to use the report-only mode
        public let reportOnly: Bool
        
        /// Whether to allow inline scripts
        public let allowInlineScripts: Bool
        
        /// Whether to allow inline styles
        public let allowInlineStyles: Bool
        
        /// Create a new CSP configuration
        public init(
            enabled: Bool = true,
            reportOnly: Bool = false,
            allowInlineScripts: Bool = false,
            allowInlineStyles: Bool = true,
            directives: [String: String] = [:]
        ) {
            self.enabled = enabled
            self.reportOnly = reportOnly
            self.allowInlineScripts = allowInlineScripts
            self.allowInlineStyles = allowInlineStyles
            self.directives = directives
        }
        
        /// Generate the CSP header value
        public var headerValue: String {
            var policy = [String]()
            
            // Add base directives
            policy.append("default-src 'self'")
            policy.append("img-src 'self' data:")
            
            // Add script directives
            if allowInlineScripts {
                policy.append("script-src 'self' 'unsafe-inline'")
            } else {
                policy.append("script-src 'self'")
            }
            
            // Add style directives
            if allowInlineStyles {
                policy.append("style-src 'self' 'unsafe-inline'")
            } else {
                policy.append("style-src 'self'")
            }
            
            // Add custom directives
            for (key, value) in directives {
                policy.append("\(key) \(value)")
            }
            
            return policy.joined(separator: "; ")
        }
        
        /// Name of the CSP header
        public var headerName: String {
            reportOnly ? "Content-Security-Policy-Report-Only" : "Content-Security-Policy"
        }
    }
    
    /// DoS protection configuration
    public struct DoSProtection: Equatable {
        /// Whether DoS protection is enabled
        public let enabled: Bool
        
        /// Maximum number of simultaneous connections
        public let maxConnections: Int
        
        /// Connection reset timeout in seconds
        public let resetTimeout: Int
        
        /// Create a new DoS protection configuration
        public init(
            enabled: Bool = true,
            maxConnections: Int = 1000,
            resetTimeout: Int = 60
        ) {
            self.enabled = enabled
            self.maxConnections = maxConnections
            self.resetTimeout = resetTimeout
        }
    }
    
    /// Content Security Policy
    public let csp: CSP
    
    /// DoS protection
    public let dosProtection: DoSProtection
    
    /// HSTS configuration
    public let enableHSTS: Bool
    
    /// X-Frame-Options header value
    public let xFrameOptions: String?
    
    /// X-Content-Type-Options header value
    public let xContentTypeOptions: String?
    
    /// Referrer-Policy header value
    public let referrerPolicy: String?
    
    /// Create a new security configuration
    public init(
        csp: CSP = CSP(),
        dosProtection: DoSProtection = DoSProtection(),
        enableHSTS: Bool = true,
        xFrameOptions: String? = "SAMEORIGIN",
        xContentTypeOptions: String? = "nosniff",
        referrerPolicy: String? = "strict-origin-when-cross-origin"
    ) {
        self.csp = csp
        self.dosProtection = dosProtection
        self.enableHSTS = enableHSTS
        self.xFrameOptions = xFrameOptions
        self.xContentTypeOptions = xContentTypeOptions
        self.referrerPolicy = referrerPolicy
    }
    
    /// Standard security configuration with recommended settings
    public static let standard = SecurityConfiguration()
    
    /// Strict security configuration with enhanced protection
    public static let strict = SecurityConfiguration(
        csp: CSP(allowInlineScripts: false, allowInlineStyles: false),
        dosProtection: DoSProtection(maxConnections: 500),
        enableHSTS: true,
        xFrameOptions: "DENY"
    )
    
    /// Disabled security configuration
    public static let disabled = SecurityConfiguration(
        csp: CSP(enabled: false),
        dosProtection: DoSProtection(enabled: false),
        enableHSTS: false,
        xFrameOptions: nil,
        xContentTypeOptions: nil,
        referrerPolicy: nil
    )
}

/// Middleware configuration for the HTTP server
public struct MiddlewareConfig: Equatable {
    /// Whether to force HTTPS
    public let forceHTTPS: Bool
    
    /// Whether to add secure headers
    public let secureHeaders: Bool
    
    /// Maximum size of request body in bytes
    public let maxBodySize: Int?
    
    /// Create a new middleware configuration
    public init(
        forceHTTPS: Bool = true,
        secureHeaders: Bool = true,
        maxBodySize: Int? = 10_485_760 // 10MB
    ) {
        self.forceHTTPS = forceHTTPS
        self.secureHeaders = secureHeaders
        self.maxBodySize = maxBodySize
    }
    
    /// Standard middleware configuration
    public static let standard = MiddlewareConfig()
    
    /// Disabled middleware configuration
    public static let disabled = MiddlewareConfig(
        forceHTTPS: false,
        secureHeaders: false,
        maxBodySize: nil
    )
} 