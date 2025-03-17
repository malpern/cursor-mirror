import XCTest
@testable import CursorWindowCore
import Vapor
import XCTVapor

@available(macOS 14.0, *)
final class AuthMiddlewareTests: XCTestCase {
    
    func testAuthMiddlewareWithBasicAuth() async throws {
        // Create the app
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Create auth manager with basic auth enabled
        let authManager = AuthenticationManager(config: .basic(username: "testuser", password: "testpass"))
        
        // Add middleware and test route
        app.middleware.use(AuthMiddleware(authManager: authManager, methods: [.basic]))
        
        app.get("test") { req -> String in
            if let user = req.authenticatedUser {
                return "Authenticated as \(user.username)"
            } else {
                return "Not authenticated"
            }
        }
        
        // Test without authentication
        try app.test(.GET, "test", afterResponse: { response in
            XCTAssertEqual(response.body.string, "Not authenticated")
        })
        
        // Test with valid authentication
        try app.test(.GET, "test", beforeRequest: { req in
            req.headers.basicAuthorization = BasicAuthorization(username: "testuser", password: "testpass")
        }, afterResponse: { response in
            XCTAssertEqual(response.body.string, "Authenticated as testuser")
        })
        
        // Test with invalid authentication
        try app.test(.GET, "test", beforeRequest: { req in
            req.headers.basicAuthorization = BasicAuthorization(username: "wrong", password: "wrong")
        }, afterResponse: { response in
            XCTAssertEqual(response.body.string, "Not authenticated")
        })
    }
    
    func testAuthMiddlewareWithAPIKey() async throws {
        // Create the app
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Create auth manager with API key enabled
        let authManager = AuthenticationManager(config: .apiKey("test-api-key"))
        
        // Add middleware and test route
        app.middleware.use(AuthMiddleware(authManager: authManager, methods: [.apiKey]))
        
        app.get("test") { req -> String in
            if let user = req.authenticatedUser {
                return "Authenticated as \(user.username)"
            } else {
                return "Not authenticated"
            }
        }
        
        // Test without authentication
        try app.test(.GET, "test", afterResponse: { response in
            XCTAssertEqual(response.body.string, "Not authenticated")
        })
        
        // Test with valid authentication in header
        try app.test(.GET, "test", beforeRequest: { req in
            req.headers.add(name: "X-API-Key", value: "test-api-key")
        }, afterResponse: { response in
            XCTAssertEqual(response.body.string, "Authenticated as api-client")
        })
        
        // Test with valid authentication in query
        try app.test(.GET, "test?api_key=test-api-key", afterResponse: { response in
            XCTAssertEqual(response.body.string, "Authenticated as api-client")
        })
        
        // Test with invalid authentication
        try app.test(.GET, "test", beforeRequest: { req in
            req.headers.add(name: "X-API-Key", value: "wrong-key")
        }, afterResponse: { response in
            XCTAssertEqual(response.body.string, "Not authenticated")
        })
    }
    
    func testProtectedRouteMiddleware() async throws {
        // Create the app
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Create auth manager with API key enabled
        let authManager = AuthenticationManager(config: .apiKey("test-api-key"))
        
        // Add middleware and test route
        let protectedGroup = app.routes.grouped([
            AuthMiddleware(authManager: authManager, methods: [.apiKey, .token]),
            ProtectedRouteMiddleware(authManager: authManager, requiredMethods: [.apiKey, .token])
        ])
        
        protectedGroup.get("protected") { req -> String in
            return "Protected content"
        }
        
        // Test without authentication
        try app.test(.GET, "protected", afterResponse: { response in
            XCTAssertEqual(response.status, .unauthorized)
        })
        
        // Test with valid authentication
        try app.test(.GET, "protected", beforeRequest: { req in
            req.headers.add(name: "X-API-Key", value: "test-api-key")
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.string, "Protected content")
        })
        
        // Create a token and test with token auth
        let token = try await authManager.requestStreamingSession()
        
        try app.test(.GET, "protected?token=\(token.uuidString)", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.string, "Protected content")
        })
    }
    
    func testAuthHandlerChallenge() async throws {
        // Create the app
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Create auth manager with basic auth enabled
        let authManager = AuthenticationManager(config: .basic(username: "testuser", password: "testpass"))
        
        // Add middleware and test route with protected route middleware
        let protectedGroup = app.routes.grouped([
            AuthMiddleware(authManager: authManager, methods: [.basic]),
            ProtectedRouteMiddleware(authManager: authManager, requiredMethods: [.basic])
        ])
        
        protectedGroup.get("protected") { req -> String in
            return "Protected content"
        }
        
        // Test that we get a challenge header
        try app.test(.GET, "protected", afterResponse: { response in
            XCTAssertEqual(response.status, .unauthorized)
            XCTAssertEqual(response.headers["WWW-Authenticate"].first, "Basic realm=\"CursorWindow\"")
        })
    }
} 