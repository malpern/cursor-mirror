import XCTest
@testable import CursorWindowCore
import Vapor
import XCTVapor

@available(macOS 14.0, *)
final class CORSTests: XCTestCase {
    private var vaporHelper: VaporTestHelper!
    private var httpServer: HTTPServerManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create HTTP server with CORS enabled
        let corsConfig = CORSConfiguration(
            allowedOrigin: "https://example.com",
            allowedMethods: [.GET, .POST, .OPTIONS],
            allowedHeaders: [.contentType, .authorization, "X-Test-Header"],
            allowCredentials: true,
            cacheExpiration: 3600
        )
        
        let config = HTTPServerConfig(
            host: "localhost",
            port: 8081,
            authentication: .disabled,
            cors: corsConfig
        )
        
        // Initialize the Vapor helper
        vaporHelper = try await VaporTestHelper(
            environment: .testing,
            hostname: config.host,
            port: config.port
        )
        
        // Set up routes for testing
        await MainActor.run {
            configureTestRoutes(vaporHelper.app)
        }
        
        // Start the server
        try await vaporHelper.startServer()
    }
    
    override func tearDown() async throws {
        try await vaporHelper.shutdown()
        vaporHelper = nil
        try await super.tearDown()
    }
    
    func testCORSHeaders() async throws {
        try await MainActor.run {
            // Test preflight request
            try vaporHelper.app.test(.OPTIONS, "test", beforeRequest: { req in
                req.headers.add(name: "Origin", value: "https://example.com")
                req.headers.add(name: "Access-Control-Request-Method", value: "POST")
                req.headers.add(name: "Access-Control-Request-Headers", value: "X-Test-Header")
            }, afterResponse: { response in
                // Verify HTTP status
                XCTAssertEqual(response.status, .ok)
                
                // Verify CORS headers
                XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "https://example.com")
                XCTAssertEqual(response.headers["Access-Control-Allow-Headers"].first, "X-Test-Header, Content-Type, Authorization")
                XCTAssertEqual(response.headers["Access-Control-Allow-Methods"].first, "GET, POST, OPTIONS")
                XCTAssertEqual(response.headers["Access-Control-Allow-Credentials"].first, "true")
                XCTAssertEqual(response.headers["Access-Control-Max-Age"].first, "3600")
            })
            
            // Test actual request with CORS headers
            try vaporHelper.app.test(.GET, "test", beforeRequest: { req in
                req.headers.add(name: "Origin", value: "https://example.com")
            }, afterResponse: { response in
                // Verify HTTP status
                XCTAssertEqual(response.status, .ok)
                
                // Verify CORS headers on actual response
                XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "https://example.com")
                XCTAssertEqual(response.headers["Access-Control-Allow-Credentials"].first, "true")
                
                // Verify content
                XCTAssertEqual(response.body.string, "Test endpoint")
            })
            
            // Test non-allowed origin
            try vaporHelper.app.test(.GET, "test", beforeRequest: { req in
                req.headers.add(name: "Origin", value: "https://attacker.com")
            }, afterResponse: { response in
                // Request should succeed but CORS headers should not match the request origin
                XCTAssertEqual(response.status, .ok)
                XCTAssertNotEqual(response.headers["Access-Control-Allow-Origin"].first, "https://attacker.com")
                XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "https://example.com")
            })
        }
    }
    
    func testPermissiveCORSConfiguration() async throws {
        // Reconfigure server with permissive CORS
        await MainActor.run {
            let corsConfiguration = CORSMiddleware.Configuration(
                allowedOrigin: .all,
                allowedMethods: [.GET, .POST, .OPTIONS],
                allowedHeaders: [.contentType, "X-Test-Header"],
                allowCredentials: false
            )
            let corsMiddleware = CORSMiddleware(configuration: corsConfiguration)
            
            // Replace existing middlewares
            vaporHelper.app.middleware = .init()
            vaporHelper.app.middleware.use(corsMiddleware)
            
            configureTestRoutes(vaporHelper.app)
        }
        
        // Test that any origin is allowed
        await MainActor.run {
            do {
                try vaporHelper.app.test(.GET, "test", beforeRequest: { req in
                    req.headers.add(name: "Origin", value: "https://any-origin.com")
                }, afterResponse: { response in
                    XCTAssertEqual(response.status, .ok)
                    XCTAssertEqual(response.headers["Access-Control-Allow-Origin"].first, "*")
                    XCTAssertNil(response.headers["Access-Control-Allow-Credentials"].first)
                })
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
    }
    
    @MainActor
    private func configureTestRoutes(_ app: Application) {
        app.get("test") { req -> String in
            "Test endpoint"
        }
        
        app.post("test") { req -> Response in
            return Response(status: .ok, body: .init(string: "Posted data"))
        }
    }
} 