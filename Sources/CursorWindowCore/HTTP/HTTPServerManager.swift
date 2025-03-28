import Foundation
import Network
import CloudKit
import Vapor
import Logging
import NIO
import SwiftUI
import Leaf
import CoreMedia
import NIOFoundationCompat

/// Manages the HTTP server for cursor window
@MainActor
public class HTTPServerManager: ObservableObject {
    // MARK: - Types
    
    public enum HTTPServerError: Error {
        case initializationFailed
        case serverNotRunning
        case encoderNotConnected
    }
    
    // MARK: - Properties
    
    /// Shared instance
    public static let shared = HTTPServerManager()
    
    /// The HTTP server instance
    private var server: Application?
    
    /// The device registration service for CloudKit integration
    private var deviceRegistrationService: DeviceRegistrationService?
    
    /// The server configuration
    var config: ServerConfig
    
    /// Whether CloudKit integration is enabled
    private var cloudKitEnabled: Bool
    
    /// Whether the server is currently running
    @Published public private(set) var isRunning: Bool = false
    
    /// Whether the server is currently streaming
    @Published public private(set) var isStreaming: Bool = false
    
    private var app: Application?
    private var adminController: AdminController?
    private var videoEncoder: (any VideoEncoder)?
    
    // MARK: - Initialization
    
    /// Initialize the server manager
    /// - Parameters:
    ///   - config: Server configuration
    ///   - cloudKitEnabled: Whether to enable CloudKit integration
    ///   - deviceRegistrationService: Optional service for device registration
    public init(
        config: ServerConfig = ServerConfig(),
        cloudKitEnabled: Bool = true,
        deviceRegistrationService: DeviceRegistrationService? = nil
    ) {
        self.config = config
        self.cloudKitEnabled = cloudKitEnabled
        self.deviceRegistrationService = deviceRegistrationService
    }
    
    // MARK: - Server Management
    
    /// Start the HTTP server
    /// - Returns: True if server started successfully, false otherwise
    public func start() async throws {
        guard !isRunning else { return }
        
        // Initialize deviceRegistrationService if needed
        if deviceRegistrationService == nil {
            deviceRegistrationService = await DeviceRegistrationService()
        }
        
        // Initialize Vapor application
        app = try await Application.make(.development)
        guard let app = app else {
            throw HTTPServerError.initializationFailed
        }
        
        // Configure admin dashboard if enabled
        if config.enableAdmin {
            let streamManager = HLSStreamManager()
            let authManager = AuthenticationManager(config: config.authentication.toAuthConfig())
            adminController = AdminController(
                serverManager: self,
                streamManager: streamManager,
                authManager: authManager
            )
            try await adminController?.setupRoutes(app)
        }
        
        // Start the server
        try app.server.start()  // Remove await as it's not an async operation
        isRunning = true
    }
    
    /// Stop the HTTP server
    public func stop() async throws {
        guard isRunning, let app = server else { return }
        
        // Stop streaming if active
        if isStreaming {
            try await stopStreaming()
        }
        
        // Shutdown server in background to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async {
            app.shutdown()
        }
        
        // Wait a bit for server to shut down
        try await Task.sleep(nanoseconds: 500_000_000)
        server = nil
        isRunning = false
    }
    
    public func startStreaming() async throws {
        guard isRunning, !isStreaming else { return }
        isStreaming = true
    }
    
    public func stopStreaming() async throws {
        guard isRunning, isStreaming else { return }
        isStreaming = false
    }
    
    // MARK: - Private Methods
    
    /// Configure the Vapor server
    private func configureServer(_ app: Application) async throws {
        // Configure server settings
        app.http.server.configuration.hostname = config.hostname
        app.http.server.configuration.port = config.port
        
        // Configure middleware
        app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
        
        // Configure routes
        try await configureRoutes(app)
    }
    
    /// Configure server routes
    private func configureRoutes(_ app: Application) async throws {
        // Configure admin routes if enabled
        if config.enableAdmin {
            let streamManager = HLSStreamManager()
            let authManager = AuthenticationManager(config: config.authentication.toAuthConfig())
            let adminController = AdminController(
                serverManager: self,
                streamManager: streamManager,
                authManager: authManager
            )
            await adminController.setupRoutes(app)
        }
        
        // Add other routes here
    }
    
    /// Record a request log
    /// - Parameter log: Request log to record
    public func recordRequest(_ log: RequestLog) async {
        // Forward to admin controller if available
        if let adminController = server?.adminController {
            await adminController.recordRequest(log)
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
    nonisolated public func videoEncoder(_ encoder: VideoEncoder, didOutputSampleBuffer sampleBuffer: CMSampleBuffer) async {
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
