import Foundation
import Vapor
import Logging
import NIO

// Import our HLS-related types
import struct CursorWindowCore.H264EncoderSettings
import class CursorWindowCore.H264VideoEncoder
import CursorWindowCore

/// HTTP server manager for handling web requests
public class HTTPServerManager {
    // MARK: - Properties
    
    /// Server configuration
    public let config: ServerConfig
    
    /// Logger for server operations
    private let logger: Logger
    
    /// Vapor application instance
    private var app: Application?
    
    /// HLS Stream manager
    public private(set) var streamManager: CursorWindowCore.HLSStreamManager
    
    /// Authentication manager
    public let authManager: AuthenticationManager
    
    /// Admin controller for server dashboard
    private var adminController: AdminController!
    
    /// Whether the server is currently running
    public private(set) var isRunning: Bool = false
    
    /// Server start time
    private var startTime: Date?
    
    /// HLS playlist generator
    private let playlistGenerator: CursorWindowCore.HLSPlaylistGenerator
    
    /// HLS segment manager
    private let segmentManager: CursorWindowCore.HLSSegmentManager
    
    /// HLS stream controller
    private let streamController: CursorWindowCore.HLSStreamController
    
    /// HLS encoding adapter
    private var encodingAdapter: CursorWindowCore.HLSEncodingAdapter?
    
    // MARK: - Lifecycle
    
    /// Initialize with configuration
    /// - Parameters:
    ///   - config: Server configuration
    ///   - logger: Logger
    ///   - streamManager: HLS stream manager
    ///   - authManager: Authentication manager
    public init(
        config: ServerConfig,
        logger: Logger,
        streamManager: CursorWindowCore.HLSStreamManager,
        authManager: AuthenticationManager
    ) {
        self.config = config
        self.logger = logger
        self.streamManager = streamManager
        self.authManager = authManager
        
        // Initialize HLS components
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let segmentsDirectory = documentsDirectory.appendingPathComponent("HLSSegments")
        
        let segmentManager = CursorWindowCore.HLSSegmentManager(
            segmentDirectory: segmentsDirectory,
            targetSegmentDuration: 4.0,
            maxSegmentCount: 5
        )
        self.segmentManager = segmentManager
        
        let baseURL = "http://\(config.hostname):\(config.port)"
        let playlistGenerator = CursorWindowCore.HLSPlaylistGenerator(
            baseURL: baseURL,
            qualities: [.hd, .sd],
            playlistLength: 5,
            targetSegmentDuration: 4.0
        )
        self.playlistGenerator = playlistGenerator
        
        let streamController = CursorWindowCore.HLSStreamController(
            playlistGenerator: playlistGenerator,
            segmentManager: segmentManager,
            streamManager: streamManager
        )
        self.streamController = streamController
        
        // Create the adapter for encoding
        self.encodingAdapter = CursorWindowCore.HLSEncodingAdapter(
            videoEncoder: H264VideoEncoder(),
            segmentManager: segmentManager,
            streamManager: streamManager
        )
        
        // Complete initialization before creating AdminController
        // Now that required properties are initialized, we can create the admin controller
        adminController = AdminController(
            serverManager: self,
            streamManager: streamManager,
            authManager: authManager
        )
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
        
        logger.info("Starting HTTP server on \(config.hostname):\(config.port)")
        
        do {
            // Create a new application using async-compatible approach
            let app = try await Application.make(.development)
            
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
            await configureRoutes(app)
            
            // Configure admin dashboard if enabled
            if config.enableAdmin {
                configureAdmin(app)
            }
            
            // Save the application
            self.app = app
            
            // Start the application
            try await app.startup()
            
            // Record startup
            isRunning = true
            startTime = Date()
            
            logger.info("HTTP server started on \(config.hostname):\(config.port)")
        } catch {
            // Clean up application
            if let app = app {
                // Use DispatchQueue instead of Task to handle shutdown
                DispatchQueue.global(qos: .background).async {
                    app.shutdown()
                }
                self.app = nil
            }
            
            // Log and throw error
            logger.error("Failed to start HTTP server: \(error)")
            throw HTTPServerError.serverInitializationFailed(error.localizedDescription)
        }
    }
    
    /// Stop the HTTP server
    /// - Throws: HTTPServerError if the server fails to stop
    public func stop() async throws {
        guard let app = app, isRunning else {
            throw HTTPServerError.serverNotRunning
        }
        
        logger.info("Stopping HTTP server")
        
        // Shutdown the application on a background thread
        DispatchQueue.global(qos: .background).async {
            app.shutdown()
        }
        
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
    /// - Parameter application: Vapor application
    func configureRoutes(_ application: Application) async {
        // Configure admin routes
        await adminController?.setupRoutes(application)
        
        // Configure HLS stream routes
        await streamController.setupRoutes(application)
        
        // Add health check
        application.get("health") { _ -> String in
            return "OK"
        }
        
        // Add version endpoint
        application.get("version") { _ -> String in
            return "1.0.0"
        }
    }
    
    /// Configure the admin interface
    /// - Parameter app: The Vapor application
    private func configureAdmin(_ app: Application) {
        // Setup admin routes
        Task {
            await adminController.setupRoutes(app)
        }
    }
    
    /// Connect a video encoder to the HLS stream
    /// - Parameter videoEncoder: H264 video encoder
    /// - Throws: Error if connection fails
    public func connectVideoEncoder(_ videoEncoder: H264VideoEncoder) throws {
        encodingAdapter = CursorWindowCore.HLSEncodingAdapter(
            videoEncoder: videoEncoder,
            segmentManager: segmentManager,
            streamManager: streamManager
        )
    }
    
    /// Start HLS streaming
    /// - Parameter encoderSettings: Optional encoding settings
    /// - Throws: Error if starting streaming fails
    public func startStreaming(encoderSettings: H264EncoderSettings? = nil) async throws {
        guard let encodingAdapter = encodingAdapter else {
            throw ServerError.encoderNotConnected
        }
        
        try await encodingAdapter.start(settings: encoderSettings)
    }
    
    /// Stop HLS streaming
    /// - Throws: Error if stopping streaming fails
    public func stopStreaming() async throws {
        guard let encodingAdapter = encodingAdapter else {
            return
        }
        
        try await encodingAdapter.stop()
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
