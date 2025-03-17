import XCTest
import Vapor
import Logging
import Foundation

/// Helper class for managing Vapor application lifecycle in tests
@MainActor
public class VaporTestHelper {
    /// The Vapor application instance
    private(set) var app: Application
    
    /// Logger for debugging
    private var logger: Logger
    
    /// Strong reference storage to prevent premature deallocation
    private var strongReferences: [Any] = []
    
    /// Creates a new Vapor test helper with an initialized application
    /// - Parameters:
    ///   - environment: The environment to use (.testing by default)
    ///   - hostname: The hostname to bind to ("localhost" by default)
    ///   - port: The port to bind to (8080 by default)
    ///   - logLevel: The log level to use (.debug by default)
    public init(
        environment: Environment = .testing,
        hostname: String = "localhost",
        port: Int = 8080,
        logLevel: Logger.Level = .debug
    ) async throws {
        logger = Logger(label: "vapor.test.helper")
        logger.logLevel = logLevel
        
        // Create application
        app = try await Application.make(environment)
        app.logger.logLevel = logLevel
        
        // Keep strong reference
        strongReferences.append(app)
        
        // Configure server
        app.http.server.configuration.hostname = hostname
        app.http.server.configuration.port = port
    }
    
    /// Starts the server
    public func startServer() async throws {
        logger.debug("Starting server...")
        try app.server.start()
        logger.debug("Server started successfully")
    }
    
    /// Properly shuts down the application and server
    public func shutdown() async throws {
        logger.debug("Beginning shutdown sequence")
        
        // First stop the server
        logger.debug("Shutting down server...")
        await app.server.shutdown()
        
        // Wait for server to fully shut down
        try await Task.sleep(for: .seconds(1))
        
        // Shutdown application on main thread
        logger.debug("Shutting down application...")
        await MainActor.run {
            app.shutdown()
        }
        
        // Give time for resources to be freed
        try await Task.sleep(for: .milliseconds(500))
        
        // Clear strong references
        strongReferences.removeAll()
        
        logger.debug("Shutdown complete")
    }
    
    /// Configure HLS-specific content types
    public func configureHLSContentTypes() {
        let mediaType = HTTPMediaType(type: "application", subType: "vnd.apple.mpegurl")
        ContentConfiguration.global.use(decoder: PlainTextDecoder(), for: mediaType)
        ContentConfiguration.global.use(encoder: PlainTextEncoder(), for: mediaType)
    }
    
    /// Creates a temporary directory for test resources
    /// - Returns: URL to the temporary directory
    public func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    /// Removes a directory
    /// - Parameter url: The URL of the directory to remove
    public func removeDirectory(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

// Helper types for content configuration
struct PlainTextDecoder: ContentDecoder {
    func decode<D>(_ decodable: D.Type, from body: ByteBuffer, headers: HTTPHeaders) throws -> D where D: Decodable {
        guard let string = body.getString(at: body.readerIndex, length: body.readableBytes) else {
            throw Abort(.badRequest)
        }
        if D.self == String.self {
            return string as! D
        }
        throw Abort(.badRequest)
    }
}

struct PlainTextEncoder: ContentEncoder {
    func encode<E>(_ encodable: E, to body: inout ByteBuffer, headers: inout HTTPHeaders) throws where E: Encodable {
        let string = String(describing: encodable)
        headers.contentType = .init(type: "application", subType: "vnd.apple.mpegurl")
        body.writeString(string)
    }
} 