import Foundation
import Vapor
import Logging
import NIO
import SwiftUI
import Leaf
import CoreMedia
import CursorWindowCore
import NIOFoundationCompat
import CloudKit

// No need to explicitly import types from our own module
// import struct CursorWindowCore.H264EncoderSettings
// import class CursorWindowCore.H264VideoEncoder
// import CursorWindowCore

/// HTTP server manager for handling web requests
@available(macOS 10.15, *)
public class HTTPServerManager: @unchecked Sendable {
    // MARK: - Singleton
    
    /// Shared instance
    private static var _shared: HTTPServerManager?
    public static var shared: HTTPServerManager {
        if _shared == nil {
            _shared = HTTPServerManager()
        }
        return _shared!
    }
    
    // MARK: - Properties
    
    /// Server configuration
    public let config: ServerConfig
    
    /// Logger for server operations
    private let logger: Logger
    
    /// Vapor application instance
    private var app: Application?
    
    /// Direct access to the application for emergency shutdown
    /// Only use this for critical cleanup during app termination
    public var directAccessApp: Application? {
        return app
    }
    
    /// Whether the server is currently running
    public private(set) var isRunning: Bool = false
    
    /// Server start time
    public private(set) var startTime: Date?
    
    /// Add a serial queue for thread safety
    private let queue = DispatchQueue(label: "com.cursor-window.server.queue")
    
    /// HLS Stream manager
    public private(set) var streamManager: HLSStreamManager
    
    /// Authentication manager
    public let authManager: AuthenticationManager
    
    /// Admin controller for server dashboard
    private var adminController: AdminController!
    
    /// HLS playlist generator
    private let playlistGenerator: HLSPlaylistGenerator
    
    /// HLS segment manager
    private let segmentManager: HLSSegmentManager
    
    /// HLS stream controller
    private let streamController: HLSStreamController
    
    /// HLS encoding adapter
    private var encodingAdapter: HLSEncodingAdapter?
    
    /// CloudKit registration queue
    private let cloudKitQueue = DispatchQueue(label: "com.cursor-window.server.cloudkit", qos: .utility)
    
    // MARK: - Lifecycle
    
    /// Initialize with configuration
    /// - Parameters:
    ///   - config: Server configuration
    ///   - logger: Logger
    ///   - streamManager: HLS stream manager
    ///   - authManager: Authentication manager
    public init(
        config: ServerConfig = ServerConfig(),
        logger: Logger = Logger(label: "com.cursor-window.server"),
        streamManager: HLSStreamManager = HLSStreamManager(),
        authManager: AuthenticationManager = AuthenticationManager()
    ) {
        self.config = config
        self.logger = logger
        self.streamManager = streamManager
        self.authManager = authManager
        
        // Initialize HLS components
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let segmentsDirectory = documentsDirectory.appendingPathComponent("HLSSegments")
        
        let segmentManager = HLSSegmentManager(
            segmentDirectory: segmentsDirectory,
            targetSegmentDuration: 4.0,
            maxSegmentCount: 5
        )
        self.segmentManager = segmentManager
        
        let baseURL = "http://\(config.hostname):\(config.port)"
        let playlistGenerator = HLSPlaylistGenerator(
            baseURL: baseURL,
            qualities: [.hd, .sd],
            playlistLength: 5,
            targetSegmentDuration: 4.0
        )
        self.playlistGenerator = playlistGenerator
        
        let streamController = HLSStreamController(
            playlistGenerator: playlistGenerator,
            segmentManager: segmentManager,
            streamManager: streamManager
        )
        self.streamController = streamController
        
        // Create the admin controller
        adminController = AdminController(
            serverManager: self,
            streamManager: streamManager,
            authManager: authManager
        )
        
        // Don't initialize encoder adapter in init to avoid potential circular reference
    }
    
    /// Clean up resources when deinitialized
    deinit {
        // Log deallocation but don't try to shutdown
        logger.warning("HTTPServerManager being deallocated while server is \(isRunning ? "running" : "stopped")")
    }
    
    // MARK: - Server Management
    
    /// Start the HTTP server
    /// - Throws: HTTPServerError if the server fails to start
    public func start() async throws {
        print("TRACE: start() called from:")
        Thread.callStackSymbols.forEach { print("  \($0)") }
        
        guard !isRunning else {
            print("TRACE: Server is already running")
            return
        }
        
        print("TRACE: Creating Vapor application")
        let app = try await Application.make(.development)
        app.http.server.configuration.hostname = config.hostname
        app.http.server.configuration.port = config.port
        print("TRACE: Application created")
        
        // TESTING: CloudKit registration disabled temporarily
        print("TRACE: CloudKit registration disabled for testing")
        
        // Configure middleware
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        app.middleware.use(ErrorMiddleware.default(environment: app.environment))
        
        // Configure routes
        await configureRoutes(app)
        
        print("TRACE: Configuring admin if enabled")
        if config.enableAdmin {
            try await configureAdmin(app)
        }
        
        // Save application reference
        self.app = app
        
        // Start the application
        print("TRACE: Starting Vapor application")
        try await app.startup()
        print("TRACE: Application started successfully")
        isRunning = true
    }
    
    /// Stop the HTTP server using the fastest path possible
    /// - Parameter skipCloudKit: Whether to skip CloudKit operations (default: false)
    /// - Throws: HTTPServerError if the server fails to stop
    public func stop(skipCloudKit: Bool = false) async throws {
        print("TRACE: stop() called from:")
        Thread.callStackSymbols.forEach { print("  \($0)") }
        
        guard let app = app, isRunning else {
            print("TRACE: Server not running, throwing error")
            throw HTTPServerError.serverNotRunning
        }
        
        logger.info("Stopping HTTP server")
        print("TRACE: Beginning server shutdown sequence")
        
        // Update state first to prevent additional requests
        isRunning = false
        startTime = nil
        
        // If we're asked to make CloudKit updates, place a timeout on them
        if !skipCloudKit {
            print("TRACE: Will attempt CloudKit offline registration with timeout")
            let cloudKitTask = Task {
                do {
                    // Attempt to perform CloudKit update with a timeout
                    _ = try await withTimeout(seconds: 2.0) {
                        try await DeviceRegistrationService.markOffline()
                    }
                    print("TRACE: Successfully marked device as offline in CloudKit")
                } catch {
                    print("TRACE: CloudKit update timed out or failed: \(error.localizedDescription)")
                    // Continue shutdown even if CloudKit fails
                }
            }
            
            // Only wait a maximum of 2 seconds for CloudKit
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) {
                if !cloudKitTask.isCancelled {
                    print("TRACE: Cancelling CloudKit task after timeout")
                    cloudKitTask.cancel()
                }
            }
        } else {
            print("TRACE: Skipping CloudKit offline status update per request")
        }
        
        print("TRACE: Stopping any active streaming")
        // Ensure any active streaming is stopped first
        if let encodingAdapter = encodingAdapter {
            do {
                print("TRACE: Stopping encoding adapter")
                try await encodingAdapter.stop()
                print("TRACE: Encoding adapter stopped")
            } catch {
                print("TRACE: Error stopping encoding adapter: \(error)")
            }
        }
        
        print("TRACE: Preparing for Vapor app shutdown")
        // Ensure we capture the application
        let appRef = app
        self.app = nil
        
        print("TRACE: Executing Vapor shutdown sequence")
        
        // First shutdown the EventLoopGroup
        print("TRACE: Shutting down EventLoopGroup")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            appRef.eventLoopGroup.shutdownGracefully { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        print("TRACE: Calling app.asyncShutdown()")
        // Call the regular shutdown method
        try await app.asyncShutdown()
        
        print("TRACE: Server shutdown completed")
        logger.info("HTTP server stopped")
    }
    
    /// Timeout helper for async operations
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                return try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "com.cursor-window", code: 408, 
                             userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            // Return the first task to complete (operation or timeout)
            let result = try await group.next()!
            // Cancel the remaining task
            group.cancelAll()
            return result
        }
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
    ///   - tlsConfig: TLS configuration
    ///   - app: The Vapor application
    /// - Throws: HTTPServerError if TLS configuration fails
    private func configureTLS(_ tlsConfig: TLSConfig, for app: Application) throws {
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
    private func configureRoutes(_ application: Application) async {
        // Configure admin routes
        await adminController?.setupRoutes(application)
        
        // Configure HLS stream routes
        await streamController.setupRoutes(application)
        
        // Register touch event routes
        TouchEventController.shared.registerRoutes(with: application)
        
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
    private func configureAdmin(_ app: Application) async throws {
        // Setup admin routes
        try await adminController.setupRoutes(app)
    }
    
    /// Connect a video encoder to the HLS stream
    /// - Parameter videoEncoder: H264 video encoder
    /// - Throws: Error if connection fails
    public func connectVideoEncoder(_ videoEncoder: H264VideoEncoder) throws {
        encodingAdapter = HLSEncodingAdapter(
            videoEncoder: videoEncoder,
            segmentManager: segmentManager,
            streamManager: streamManager
        )
    }
    
    /// Start HLS streaming
    /// - Parameter encoderSettings: Optional encoding settings
    /// - Throws: ServerError if streaming fails to start
    public func startStreaming(encoderSettings: H264EncoderSettings? = nil) async throws {
        guard let encodingAdapter = encodingAdapter else {
            throw ServerError.encoderNotConnected
        }
        
        do {
            try await encodingAdapter.start(settings: encoderSettings)
            logger.info("Started HLS streaming with encoder settings: \(String(describing: encoderSettings))")
        } catch {
            logger.error("Failed to start streaming: \(error.localizedDescription)")
            
            if let hlsError = error as? HLSEncodingError {
                switch hlsError {
                case .encodingAlreadyActive:
                    throw ServerError.serverAlreadyRunning
                case .invalidStreamQuality:
                    throw ServerError.invalidConfiguration("Invalid stream quality")
                default:
                    throw ServerError.internalError("Encoding error: \(hlsError.description)")
                }
            } else {
                throw ServerError.from(error)
            }
        }
    }
    
    /// Stop HLS streaming
    /// - Throws: ServerError if stopping streaming fails
    public func stopStreaming() async throws {
        guard let encodingAdapter = encodingAdapter else {
            logger.warning("Stop streaming called with no encoder connected")
            return
        }
        
        do {
            try await encodingAdapter.stop()
            logger.info("Stopped HLS streaming")
        } catch {
            logger.error("Failed to stop streaming: \(error.localizedDescription)")
            throw ServerError.from(error)
        }
    }
    
    private func performShutdown(_ app: Application) {
        app.shutdown()
    }
    
    /// Emergency synchronous server shutdown - use only during application termination
    public func emergencyShutdown() {
        print("EMERGENCY: Performing synchronous server shutdown")
        
        // Mark as not running immediately
        isRunning = false
        startTime = nil
        
        // Capture app reference
        guard let app = self.app else {
            print("EMERGENCY: No server app to shut down")
            return
        }
        
        // Clear reference immediately
        self.app = nil
        
        // Shut down synchronously without waiting for async operations
        DispatchQueue.global(qos: .userInitiated).async {
            // Shut down the event loop group
            app.eventLoopGroup.shutdownGracefully { _ in
                print("EMERGENCY: Event loop shutdown completed")
            }
            
            // Perform synchronous shutdown
            app.shutdown()
            print("EMERGENCY: Server shutdown completed")
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

extension HTTPServerManager: VideoEncoderDelegate {
    public func videoEncoder(_ encoder: VideoEncoder, didOutputSampleBuffer sampleBuffer: CMSampleBuffer) {
        // Handle encoded video samples
        print("Received encoded video sample")
    }
}

extension Data {
    /// Encode this data as a response
    func encodeResponse(for req: Request) -> Response {
        let res = Response()
        res.headers.contentType = .json
        res.body = .init(data: self)
        return res
    }
}
