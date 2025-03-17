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
    case streamError(String)
}

/// Manages an HTTP server for streaming HLS content
public actor HTTPServerManager {
    private let config: HTTPServerConfig
    private var app: Application?
    internal private(set) var isRunning: Bool = false
    private let streamManager: HLSStreamManager
    
    public init(config: HTTPServerConfig = HTTPServerConfig()) {
        self.config = config
        self.streamManager = HLSStreamManager()
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
        
        // Stream access endpoint
        app.post("stream", "access") { [streamManager] req -> Response in
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
        
        // Master playlist endpoint
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
    }
} 