import XCTest
@testable import CursorWindowCore
import Vapor
import XCTVapor

@available(macOS 14.0, *)
final class AuthenticationTests: XCTestCase {
    private var vaporHelper: VaporTestHelper!
    private var authManager: AuthenticationManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize the Vapor helper with debug logging
        vaporHelper = try await VaporTestHelper(
            environment: .testing,
            hostname: "localhost",
            port: 8080,
            logLevel: .debug
        )
        
        // Create authentication manager with basic auth enabled
        authManager = AuthenticationManager(config: .basic(username: "testuser", password: "testpass"))
        
        // Configure middleware and routes for testing
        await MainActor.run {
            vaporHelper.app.middleware.use(AuthMiddleware(authManager: authManager))
            configureTestRoutes(vaporHelper.app)
        }
        
        // Start the server
        try await vaporHelper.startServer()
    }
    
    override func tearDown() async throws {
        // Shut down the server
        try await vaporHelper.shutdown()
        vaporHelper = nil
        authManager = nil
        
        try await super.tearDown()
    }
    
    func testBasicAuthentication() async throws {
        // Test successful authentication
        try await MainActor.run {
            try vaporHelper.app.test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["username": "testuser", "password": "testpass"])
            }, afterResponse: { response in
                XCTAssertEqual(response.status, .ok)
                
                // Decode the response
                let data = try response.content.decode([String: String].self)
                XCTAssertNotNil(data["token"])
                XCTAssertEqual(data["username"], "testuser")
            })
        }
        
        // Test failed authentication
        try await MainActor.run {
            try vaporHelper.app.test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["username": "wronguser", "password": "wrongpass"])
            }, afterResponse: { response in
                XCTAssertEqual(response.status, .unauthorized)
            })
        }
    }
    
    func testAPIKeyAuthentication() async throws {
        // Update authentication config to use API key
        await authManager.updateConfig(.apiKey("test-api-key"))
        
        // Test successful authentication
        try await MainActor.run {
            try vaporHelper.app.test(.POST, "auth/verify", beforeRequest: { req in
                try req.content.encode(["apiKey": "test-api-key"])
            }, afterResponse: { response in
                XCTAssertEqual(response.status, .ok)
                
                // Decode the response
                let data = try response.content.decode([String: String].self)
                XCTAssertNotNil(data["token"])
                XCTAssertEqual(data["username"], "api-client")
            })
        }
        
        // Test failed authentication
        try await MainActor.run {
            try vaporHelper.app.test(.POST, "auth/verify", beforeRequest: { req in
                try req.content.encode(["apiKey": "wrong-api-key"])
            }, afterResponse: { response in
                XCTAssertEqual(response.status, .unauthorized)
            })
        }
    }
    
    func testProtectedRoute() async throws {
        // First authenticate to get a token
        var token: String = ""
        
        try await MainActor.run {
            try vaporHelper.app.test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["username": "testuser", "password": "testpass"])
            }, afterResponse: { response in
                XCTAssertEqual(response.status, .ok)
                let data = try response.content.decode([String: String].self)
                token = data["token"] ?? ""
                XCTAssertFalse(token.isEmpty)
            })
        }
        
        // Test accessing protected route with valid token
        try await MainActor.run {
            try vaporHelper.app.test(.GET, "protected?token=\(token)", afterResponse: { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.body.string, "Protected content")
            })
        }
        
        // Test accessing protected route without token
        try await MainActor.run {
            try vaporHelper.app.test(.GET, "protected", afterResponse: { response in
                XCTAssertEqual(response.status, .unauthorized)
            })
        }
        
        // Test accessing protected route with invalid token
        try await MainActor.run {
            try vaporHelper.app.test(.GET, "protected?token=00000000-0000-0000-0000-000000000000", afterResponse: { response in
                XCTAssertEqual(response.status, .unauthorized)
            })
        }
    }
    
    func testSessionExpiration() async throws {
        // Create authentication manager with short session duration
        let shortSessionConfig = AuthenticationConfig(
            enabled: true,
            username: "testuser",
            password: "testpass",
            sessionDuration: 1 // 1 second
        )
        await authManager.updateConfig(shortSessionConfig)
        
        // Get a token
        var token: String = ""
        
        try await MainActor.run {
            try vaporHelper.app.test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(["username": "testuser", "password": "testpass"])
            }, afterResponse: { response in
                XCTAssertEqual(response.status, .ok)
                let data = try response.content.decode([String: String].self)
                token = data["token"] ?? ""
                XCTAssertFalse(token.isEmpty)
            })
        }
        
        // Test access works immediately
        try await MainActor.run {
            try vaporHelper.app.test(.GET, "protected?token=\(token)", afterResponse: { response in
                XCTAssertEqual(response.status, .ok)
            })
        }
        
        // Wait for session to expire
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Clean up expired sessions
        await authManager.cleanupExpiredSessions()
        
        // Test that access fails after expiration
        try await MainActor.run {
            try vaporHelper.app.test(.GET, "protected?token=\(token)", afterResponse: { response in
                XCTAssertEqual(response.status, .unauthorized)
            })
        }
    }
    
    /// Configure routes for testing
    @MainActor
    private func configureTestRoutes(_ app: Application) {
        // Protected route
        let protectedRoutes = app.routes.grouped().protected(using: authManager)
        protectedRoutes.get("protected") { req -> String in
            "Protected content"
        }
        
        // Authentication routes for login and verify
        app.post("auth", "login") { req -> Response in
            guard let credentials = try? req.content.decode(LoginCredentials.self) else {
                throw Abort(.badRequest)
            }
            
            do {
                let user = try await self.authManager.authenticateBasic(
                    username: credentials.username,
                    password: credentials.password
                )
                
                let response = Response(status: .ok)
                response.headers.contentType = .json
                try response.content.encode([
                    "token": user.id.uuidString,
                    "username": user.username,
                    "expiresAt": ISO8601DateFormatter().string(from: user.expiresAt)
                ])
                return response
            } catch {
                throw Abort(.unauthorized)
            }
        }
        
        app.post("auth", "verify") { req -> Response in
            guard let apiKeyData = try? req.content.decode(APIKeyData.self) else {
                throw Abort(.badRequest)
            }
            
            do {
                let user = try await self.authManager.authenticateApiKey(apiKeyData.apiKey)
                
                let response = Response(status: .ok)
                response.headers.contentType = .json
                try response.content.encode([
                    "token": user.id.uuidString,
                    "username": user.username,
                    "expiresAt": ISO8601DateFormatter().string(from: user.expiresAt)
                ])
                return response
            } catch {
                throw Abort(.unauthorized)
            }
        }
    }
}

// Helper structures for testing
private struct LoginCredentials: Content {
    let username: String
    let password: String
}

private struct APIKeyData: Content {
    let apiKey: String
} 