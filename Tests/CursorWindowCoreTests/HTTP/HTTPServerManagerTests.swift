import XCTest
import XCTVapor
@testable import CursorWindowCore

final class HTTPServerManagerTests: XCTestCase {
    private var manager: HTTPServerManager!
    private let testPort = 8081
    private var client: HTTPClient!
    
    override func setUp() async throws {
        try await super.setUp()
        let config = HTTPServerConfig(port: testPort)
        manager = HTTPServerManager(config: config)
        client = HTTPClient(eventLoopGroupProvider: .singleton)
    }
    
    override func tearDown() async throws {
        if manager != nil {
            try? await manager.stop()
            manager = nil
        }
        if client != nil {
            try await client.shutdown()
            client = nil
        }
        try await super.tearDown()
    }
    
    func testServerStartStop() async throws {
        // Test server start
        try await manager.start()
        var isRunning = await manager.isRunning
        XCTAssertTrue(isRunning, "Server should be running after start")
        
        // Verify server is accessible
        let response = try await client.get(url: "http://localhost:\(testPort)/health").get()
        XCTAssertEqual(response.status, .ok)
        
        // Test server stop
        try await manager.stop()
        isRunning = await manager.isRunning
        XCTAssertFalse(isRunning, "Server should not be running after stop")
    }
    
    func testServerAlreadyRunning() async throws {
        // Start server
        try await manager.start()
        
        // Try to start again
        do {
            try await manager.start()
            XCTFail("Expected error when starting already running server")
        } catch let error as HTTPServerError {
            XCTAssertEqual(error, .serverAlreadyRunning)
        }
        
        try await manager.stop()
    }
    
    func testServerNotRunning() async throws {
        // Try to stop server that isn't running
        do {
            try await manager.stop()
            XCTFail("Expected error when stopping server that isn't running")
        } catch let error as HTTPServerError {
            XCTAssertEqual(error, .serverNotRunning)
        }
    }
    
    func testHealthEndpoint() async throws {
        try await manager.start()
        
        let response = try await client.get(url: "http://localhost:\(testPort)/health").get()
        XCTAssertEqual(response.status, .ok)
        
        let body = try XCTUnwrap(response.body)
        let responseString = String(buffer: body)
        XCTAssertEqual(responseString, "OK")
        
        try await manager.stop()
    }
    
    func testVersionEndpoint() async throws {
        try await manager.start()
        
        let response = try await client.get(url: "http://localhost:\(testPort)/version").get()
        XCTAssertEqual(response.status, .ok)
        
        let body = try XCTUnwrap(response.body)
        let responseString = String(buffer: body)
        XCTAssertEqual(responseString, "1.0.0")
        
        try await manager.stop()
    }
    
    func testCustomConfiguration() async throws {
        let customConfig = HTTPServerConfig(
            host: "127.0.0.1",
            port: 8082,
            enableTLS: false,
            workerCount: 4
        )
        
        let customManager = HTTPServerManager(config: customConfig)
        try await customManager.start()
        
        let response = try await client.get(url: "http://localhost:8082/health").get()
        XCTAssertEqual(response.status, .ok)
        
        try await customManager.stop()
    }
} 