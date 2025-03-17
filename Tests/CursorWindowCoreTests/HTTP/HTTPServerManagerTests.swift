import XCTest
import Vapor
import XCTVapor
@testable import CursorWindowCore

@MainActor
final class HTTPServerManagerTests: XCTestCase {
    private var vaporHelper: VaporTestHelper!
    
    override func setUp() async throws {
        try await super.setUp()
        vaporHelper = try await VaporTestHelper(logLevel: .debug)
    }
    
    override func tearDown() async throws {
        if let helper = vaporHelper {
            try await helper.shutdown()
        }
        vaporHelper = nil
        try await super.tearDown()
    }

    func testBasicServerConfiguration() async throws {
        // Set up basic routes
        vaporHelper.app.get("test") { req -> String in
            return "Hello, world!"
        }
        
        // Start the server
        try await vaporHelper.startServer()
        
        // Test that the server is responding
        let response = try await vaporHelper.app.client.get("http://localhost:8080/test")
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(try response.content.decode(String.self), "Hello, world!")
        
        // Verify default settings
        XCTAssertEqual(vaporHelper.app.http.server.configuration.hostname, "127.0.0.1")
        XCTAssertEqual(vaporHelper.app.http.server.configuration.port, 8080)
    }
    
    func testCustomPortConfiguration() async throws {
        // Create new helper with custom port
        let customHelper = try await VaporTestHelper(
            hostname: "localhost", 
            port: 9000, 
            logLevel: .debug
        )
        
        // Set up a test route
        customHelper.app.get("test") { req -> String in
            return "Custom port test"
        }
        
        // Start the server
        try await customHelper.startServer()
        
        // Test that the server is responding on the custom port
        let response = try await customHelper.app.client.get("http://localhost:9000/test")
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(try response.content.decode(String.self), "Custom port test")
        
        // Verify custom settings
        XCTAssertEqual(customHelper.app.http.server.configuration.hostname, "127.0.0.1")
        XCTAssertEqual(customHelper.app.http.server.configuration.port, 9000)
        
        // Explicitly shutdown
        try await customHelper.shutdown()
    }
} 