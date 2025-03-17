import Foundation
import Vapor

/// Configuration options for the HTTP server
public struct HTTPServerConfig {
    /// The host address to bind to
    public let host: String
    
    /// The port to listen on
    public let port: Int
    
    /// Whether to enable SSL/TLS
    public let enableTLS: Bool
    
    /// The number of worker threads
    public let workerCount: Int
    
    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        enableTLS: Bool = false,
        workerCount: Int = System.coreCount
    ) {
        self.host = host
        self.port = port
        self.enableTLS = enableTLS
        self.workerCount = workerCount
    }
}

/// Errors that can occur during HTTP server operations
public enum HTTPServerError: Error, Equatable {
    /// The server is already running
    case serverAlreadyRunning
    /// The server is not running
    case serverNotRunning
    /// Invalid configuration
    case invalidConfiguration(String)
    /// Initialization error
    case initializationError(String)
    
    public static func == (lhs: HTTPServerError, rhs: HTTPServerError) -> Bool {
        switch (lhs, rhs) {
        case (.serverAlreadyRunning, .serverAlreadyRunning):
            return true
        case (.serverNotRunning, .serverNotRunning):
            return true
        case (.invalidConfiguration(let lhsMsg), .invalidConfiguration(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.initializationError(let lhsMsg), .initializationError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

/// Manages an HTTP server for streaming HLS content
public actor HTTPServerManager {
    /// The current server configuration
    private let config: HTTPServerConfig
    
    /// The Vapor application instance
    private var app: Application?
    
    /// Whether the server is currently running
    private(set) var isRunning: Bool = false
    
    /// Initialize a new HTTP server manager
    /// - Parameter config: The server configuration
    public init(config: HTTPServerConfig) {
        self.config = config
    }
    
    deinit {
        if let app = app {
            app.shutdown()
        }
    }
    
    /// Starts the HTTP server
    public func start() async throws {
        if isRunning {
            throw HTTPServerError.serverAlreadyRunning
        }
        
        // Create and configure the application
        let app = await withCheckedContinuation { continuation in
            let app = Application(.development)
            continuation.resume(returning: app)
        }
        
        do {
            // Configure server settings
            app.http.server.configuration.hostname = config.host
            app.http.server.configuration.port = config.port
            
            // Configure middleware
            app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
            app.middleware.use(ErrorMiddleware.default(environment: app.environment))
            
            // Configure routes
            try configureRoutes(app)
            
            self.app = app
            
            // Start the server
            try await app.server.start()
            isRunning = true
        } catch {
            app.shutdown()
            throw HTTPServerError.initializationError(error.localizedDescription)
        }
    }
    
    /// Stops the HTTP server
    public func stop() async throws {
        guard let app = self.app else {
            throw HTTPServerError.serverNotRunning
        }
        
        // Shutdown the server first
        try await app.server.shutdown()
        
        // Then shutdown the application
        await withCheckedContinuation { continuation in
            app.shutdown()
            continuation.resume()
        }
        
        self.app = nil
        isRunning = false
    }
    
    /// Configures the server routes
    private func configureRoutes(_ app: Application) throws {
        // Health check endpoint
        app.get("health") { req async -> String in
            "OK"
        }
        
        // Version endpoint
        app.get("version") { req async -> String in
            "1.0.0"
        }
        
        // Static files endpoint
        app.get("static", "**") { req async throws -> Response in
            let path = req.parameters.getCatchall().joined(separator: "/")
            return try await req.fileio.asyncStreamFile(at: path)
        }
    }
} 