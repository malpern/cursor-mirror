import Vapor
import Foundation

/// Configuration options for the HTTP server
public struct HTTPServerConfig: Equatable {
    let host: String
    let port: Int
    let enableTLS: Bool
    let workerCount: Int
    
    public init(host: String = "127.0.0.1", port: Int = 8080, enableTLS: Bool = false, workerCount: Int = System.coreCount) {
        self.host = host
        self.port = port
        self.enableTLS = enableTLS
        self.workerCount = workerCount
    }
}

/// Errors that can occur during HTTP server operations
public enum HTTPServerError: Error, Equatable {
    case serverAlreadyRunning
    case serverNotRunning
    case invalidConfiguration
}

/// Manages an HTTP server for streaming HLS content
public actor HTTPServerManager {
    private let config: HTTPServerConfig
    private var app: Application?
    internal private(set) var isRunning: Bool = false
    
    public init(config: HTTPServerConfig = HTTPServerConfig()) {
        self.config = config
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
        
        // Configure routes
        try configureRoutes(app)
        
        // Start the server
        try await app.startup()
        self.app = app
        self.isRunning = true
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
    
    /// Configure server routes
    private func configureRoutes(_ app: Application) throws {
        // Health check endpoint
        app.get("health") { req -> String in
            "OK"
        }
        
        // Version endpoint
        app.get("version") { req -> String in
            "1.0.0"
        }
        
        // Static files endpoint
        app.get("static", "**") { req async throws -> Response in
            let path = req.parameters.getCatchall().joined(separator: "/")
            return try await req.fileio.asyncStreamFile(at: path)
        }
    }
} 