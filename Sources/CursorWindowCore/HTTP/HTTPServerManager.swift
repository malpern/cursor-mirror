import Foundation
import Vapor
import Logging
import NIO

/// HTTP server manager for handling web requests
public actor HTTPServerManager {
    // MARK: - Properties
    
    /// Server configuration
    public let config: ServerConfig
    
    /// Logger for server operations
    private let logger: Logger
    
    /// Vapor application instance
    private var app: Application?
    
    /// HLS Stream manager
    public let streamManager: HLSStreamManager
    
    /// Authentication manager
    public let authManager: AuthenticationManager
    
    /// Admin controller for web interface
    private var adminController: AdminController?
    
    /// Whether the server is currently running
    public private(set) var isRunning: Bool = false
    
    /// Server start time
    private var startTime: Date?
    
    // MARK: - Lifecycle
    
    /// Initialize a new HTTP server manager
    /// - Parameters:
    ///   - config: Server configuration
    ///   - logger: Logger for server operations
    ///   - streamManager: HLS Stream manager
    ///   - authManager: Authentication manager
    public init(
        config: ServerConfig,
        logger: Logger,
        streamManager: HLSStreamManager,
        authManager: AuthenticationManager
    ) {
        self.config = config
        self.logger = logger
        self.streamManager = streamManager
        self.authManager = authManager
    }
    
    /// Clean up resources when deinitialized
    deinit {
        if isRunning, let app = app {
            app.shutdown()
        }
    }
    
    // MARK: - Server Management
    
    /// Start the HTTP server
    /// - Throws: HTTPServerError if the server fails to start
    public func start() async throws {
        // Check if server is already running
        guard !isRunning else {
            throw HTTPServerError.serverAlreadyRunning
        }
        
        // Set up server
        do {
            // Create a new application
            let app = Application(.development)
            
            // Configure HTTP settings
            app.http.server.configuration.hostname = config.hostname
            app.http.server.configuration.port = config.port
            
            // Configure middleware
            configureMiddleware(app)
            
            // Configure TLS if needed
            if let tlsConfig = config.tls {
                try configureTLS(app, tlsConfig: tlsConfig)
            }
            
            // Configure routes
            configureRoutes(app)
            
            // Configure admin dashboard if enabled
            if config.enableAdmin {
                configureAdmin(app)
            }
            
            // Save the application
            self.app = app
            
            // Start the application
            try app.start()
            
            // Record startup
            isRunning = true
            startTime = Date()
            
            logger.info("HTTP server started on \(config.hostname):\(config.port)")
        } catch {
            // Clean up application
            app?.shutdown()
            app = nil
            
            // Log and throw error
            logger.error("Failed to start HTTP server: \(error)")
            throw HTTPServerError.serverInitializationFailed(error.localizedDescription)
        }
    }
    
    /// Stop the HTTP server
    /// - Throws: HTTPServerError if the server fails to stop
    public func stop() async throws {
        // Check if server is running
        guard isRunning, let app = app else {
            throw HTTPServerError.serverNotRunning
        }
        
        // Shutdown the application
        app.shutdown()
        
        // Update state
        self.app = nil
        isRunning = false
        startTime = nil
        
        logger.info("HTTP server stopped")
    }
    
    /// Record a request log
    /// - Parameter log: The request log to record
    public func recordRequest(_ log: RequestLog) async {
        if let adminController = adminController {
            await adminController.recordRequest(log)
        }
    }
    
    // MARK: - Configuration
    
    /// Configure application middleware
    /// - Parameter app: The Vapor application
    private func configureMiddleware(_ app: Application) {
        // Clear existing middleware
        app.middleware = .init()
        
        // Add default middleware
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))
        
        // Add CORS if enabled
        if config.enableCORS, let corsConfig = config.cors {
            let corsMiddleware = CORSMiddleware(
                configuration: .init(
                    allowedOrigin: .custom(corsConfig.allowedOrigins.joined(separator: ", ")),
                    allowedMethods: corsConfig.allowedMethods.compactMap { HTTPMethod(rawValue: $0) },
                    allowedHeaders: corsConfig.allowedHeaders.map { HTTPHeaders.Name($0) }
                )
            )
            app.middleware.use(corsMiddleware)
        }
        
        // Add request logging middleware
        app.middleware.use(RequestLoggingMiddleware(
            config: RequestLoggingConfig(),
            logger: logger,
            serverManager: self
        ))
    }
    
    /// Configure TLS (SSL)
    /// - Parameters:
    ///   - app: The Vapor application
    ///   - tlsConfig: TLS configuration
    /// - Throws: HTTPServerError if TLS configuration fails
    private func configureTLS(_ app: Application, tlsConfig: TLSConfig) throws {
        // Check if certificate and key exist
        let certPath = tlsConfig.certificatePath
        let keyPath = tlsConfig.privateKeyPath
        
        guard FileManager.default.fileExists(atPath: certPath),
              FileManager.default.fileExists(atPath: keyPath) else {
            throw HTTPServerError.sslConfigurationError("Certificate or key file not found")
        }
        
        // Log that we would configure TLS (actual implementation requires additional imports)
        logger.info("TLS configuration requested but not fully implemented")
        logger.info("Would configure with certificate: \(certPath) and key: \(keyPath)")
        
        // In a real implementation, we would configure TLS here
        throw HTTPServerError.sslConfigurationError("TLS configuration is not fully implemented")
    }
    
    /// Configure application routes
    /// - Parameter app: The Vapor application
    private func configureRoutes(_ app: Application) {
        // Health check route
        app.get("health") { _ -> String in
            "OK"
        }
        
        // Status route
        app.get("status") { [weak self] req -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }
            
            // Create status response
            let status = ServerStatus(
                serverRunning: true,
                streamActive: self.streamManager.isStreaming,
                authEnabled: self.config.authentication.enabled,
                hostname: self.config.hostname,
                port: self.config.port,
                startTime: self.startTime?.timeIntervalSince1970 ?? 0,
                uptime: self.startTime != nil ? Date().timeIntervalSince(self.startTime!) : 0
            )
            
            return try! JSONEncoder().encode(status).encodeResponse(for: req)
        }
        
        // Stream routes
        configureStreamRoutes(app)
    }
    
    /// Configure the admin interface
    /// - Parameter app: The Vapor application
    private func configureAdmin(_ app: Application) {
        // Create admin controller
        let adminController = AdminController(
            serverManager: self,
            streamManager: streamManager,
            authManager: authManager,
            logger: logger
        )
        self.adminController = adminController
        
        // Setup admin routes
        Task {
            await adminController.setupRoutes(app)
        }
    }
    
    /// Configure stream routes
    /// - Parameter app: The Vapor application
    private func configureStreamRoutes(_ app: Application) {
        // Create stream routes group
        let streamRoutes = app.grouped("streams")
        
        // Add auth middleware if needed
        let protectedRoutes: RoutesBuilder
        if config.authentication.enabled {
            // Create simple admin auth middleware
            struct AdminAuthHandler: AsyncMiddleware {
                let authManager: AuthenticationManager
                
                init(authManager: AuthenticationManager) {
                    self.authManager = authManager
                }
                
                func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
                    // Check for basic auth
                    if let auth = request.headers.basicAuthorization {
                        // Try to authenticate
                        do {
                            _ = try await authManager.authenticateBasic(username: auth.username, password: auth.password)
                            return try await next.respond(to: request)
                        } catch {
                            return Response(status: .unauthorized)
                        }
                    }
                    
                    // Unauthorized
                    return Response(status: .unauthorized)
                }
            }
            
            protectedRoutes = streamRoutes.grouped(AdminAuthHandler(authManager: authManager))
        } else {
            protectedRoutes = streamRoutes
        }
        
        // Configure stream endpoints
        protectedRoutes.get(":key", "master.m3u8") { [weak self] req -> Response in
            guard let self = self, let key = req.parameters.get("key") else {
                return Response(status: .badRequest)
            }
            
            // Simple placeholder response that uses the values
            self.logger.info("Received request for stream key: \(key)")
            
            return Response(status: .ok, 
                           headers: ["Content-Type": "application/vnd.apple.mpegurl"], 
                           body: .init(string: "#EXTM3U\n#EXT-X-VERSION:3\n"))
        }
    }
}

// MARK: - Helper Types

/// Server status information
struct ServerStatus: Content {
    /// Whether the server is running
    let serverRunning: Bool
    
    /// Whether a stream is active
    let streamActive: Bool
    
    /// Whether authentication is enabled
    let authEnabled: Bool
    
    /// Server hostname
    let hostname: String
    
    /// Server port
    let port: Int
    
    /// Server start time (Unix timestamp)
    let startTime: TimeInterval
    
    /// Server uptime in seconds
    let uptime: TimeInterval
}

// MARK: - Extensions

extension Data {
    /// Encode this data as a response
    func encodeResponse(for req: Request) -> Response {
        let res = Response()
        res.headers.contentType = .json
        res.body = .init(data: self)
        return res
    }
}
