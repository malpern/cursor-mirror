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
public class HTTPServerManager {
    // MARK: - Properties
    
    /// The HTTP server instance
    private var server: Application?
    
    /// The device registration service for CloudKit integration
    private var deviceRegistrationService: (any DeviceRegistrationServiceProtocol)?
    
    /// The server configuration
    var config: ServerConfig
    
    /// Whether CloudKit integration is enabled
    private var cloudKitEnabled: Bool
    
    /// Whether the server is currently running
    public private(set) var isRunning: Bool = false
    
    // MARK: - Initialization
    
    /// Initialize the server manager
    /// - Parameters:
    ///   - config: Server configuration
    ///   - cloudKitEnabled: Whether to enable CloudKit integration
    ///   - deviceRegistrationService: Optional service for device registration
    public init(
        config: ServerConfig = ServerConfig(),
        cloudKitEnabled: Bool = true,
        deviceRegistrationService: (any DeviceRegistrationServiceProtocol)? = nil
    ) {
        self.config = config
        self.cloudKitEnabled = cloudKitEnabled
        self.deviceRegistrationService = deviceRegistrationService
    }
    
    // MARK: - Server Management
    
    /// Start the HTTP server
    /// - Returns: True if server started successfully, false otherwise
    public func start() async throws -> Bool {
        print("Starting HTTP server on port \(config.port)")
        
        // Create and start the server
        let app = Application(.development)
        app.http.server.configuration.port = config.port
        app.http.server.configuration.hostname = config.hostname
        try await app.startup()
        self.server = app
        isRunning = true
        
        // Register with CloudKit if enabled
        if cloudKitEnabled {
            return try await registerWithCloudKit()
        }
        
        return true
    }
    
    /// Register the device with CloudKit
    /// - Returns: True if registration was successful, false otherwise
    private func registerWithCloudKit() async throws -> Bool {
        guard let deviceService = deviceRegistrationService else {
            print("CloudKit enabled but no device registration service provided")
            return false
        }
        
        do {
            return try await deviceService.registerDevice(serverIP: ServerConfig.getLocalIPAddress())
        } catch {
            print("Failed to register with CloudKit: \(error.localizedDescription)")
            throw HTTPServerError.internalError("CloudKit registration failed: \(error.localizedDescription)")
        }
    }
    
    /// Stop the HTTP server
    /// - Parameter skipCloudKit: Whether to skip updating CloudKit status
    public func stop(skipCloudKit: Bool = false) {
        print("Stopping HTTP server")
        
        // Stop the server first
        if let app = server {
            app.shutdown()
        }
        server = nil
        isRunning = false
        
        // Update CloudKit status if enabled and not skipped
        if cloudKitEnabled && !skipCloudKit {
            // Use a background queue to avoid blocking
            DispatchQueue.global(qos: .background).async {
                Task {
                    do {
                        _ = try await DeviceRegistrationService.markOffline()
                    } catch {
                        print("Failed to mark device as offline in CloudKit: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// Emergency shutdown of the server
    /// This is called when the application is terminating
    public func emergencyShutdown() {
        stop(skipCloudKit: true)
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
