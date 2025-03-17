import XCTest
@testable import CursorWindowCore
import Vapor
import XCTVapor

@available(macOS 14.0, *)
final class AuthHandlerTests: XCTestCase {
    
    func testBasicAuthenticationHandler() async {
        // Create the handler
        let handler = BasicAuthenticationHandler()
        
        // Create a mock request with basic auth
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let req = Request(application: app, method: .GET, url: URI("/test"))
        req.headers.basicAuthorization = BasicAuthorization(username: "testuser", password: "testpass")
        
        // Create a mock auth manager
        let authManager = AuthenticationManager(config: .basic(username: "testuser", password: "testpass"))
        
        // Test successful authentication
        let user = await handler.authenticate(request: req, authManager: authManager)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.method, .basic)
        XCTAssertEqual(user?.username, "testuser")
        
        // Test failed authentication
        let failReq = Request(application: app, method: .GET, url: URI("/test"))
        failReq.headers.basicAuthorization = BasicAuthorization(username: "wrong", password: "wrong")
        
        let failedUser = await handler.authenticate(request: failReq, authManager: authManager)
        XCTAssertNil(failedUser)
    }
    
    func testAPIKeyAuthenticationHandler() async {
        // Create the handler
        let handler = APIKeyAuthenticationHandler()
        
        // Create a mock request with API key
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Test with header
        let reqWithHeader = Request(application: app, method: .GET, url: URI("/test"))
        reqWithHeader.headers.add(name: "X-API-Key", value: "test-api-key")
        
        // Test with query parameter
        let reqWithQuery = Request(application: app, method: .GET, url: URI("/test?api_key=test-api-key"))
        
        // Create a mock auth manager
        let authManager = AuthenticationManager(config: .apiKey("test-api-key"))
        
        // Test successful authentication with header
        let userFromHeader = await handler.authenticate(request: reqWithHeader, authManager: authManager)
        XCTAssertNotNil(userFromHeader)
        XCTAssertEqual(userFromHeader?.method, .apiKey)
        
        // Test successful authentication with query
        let userFromQuery = await handler.authenticate(request: reqWithQuery, authManager: authManager)
        XCTAssertNotNil(userFromQuery)
        XCTAssertEqual(userFromQuery?.method, .apiKey)
        
        // Test failed authentication
        let failReq = Request(application: app, method: .GET, url: URI("/test"))
        failReq.headers.add(name: "X-API-Key", value: "wrong-key")
        
        let failedUser = await handler.authenticate(request: failReq, authManager: authManager)
        XCTAssertNil(failedUser)
    }
    
    func testTokenAuthenticationHandler() async {
        // Create the handler
        let handler = TokenAuthenticationHandler()
        
        // Create a mock request with token
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // Create a request with a valid UUID token
        let validToken = UUID()
        let reqWithToken = Request(application: app, method: .GET, url: URI("/test?token=\(validToken.uuidString)"))
        
        // Create a mock auth manager
        let authManager = AuthenticationManager()
        
        // Request a streaming session to create a token
        let sessionToken = try? await authManager.requestStreamingSession()
        XCTAssertNotNil(sessionToken)
        
        // Test successful authentication
        let reqWithValidSession = Request(application: app, method: .GET, url: URI("/test?token=\(sessionToken!.uuidString)"))
        let user = await handler.authenticate(request: reqWithValidSession, authManager: authManager)
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.method, .token)
        
        // Test failed authentication with invalid token
        let failedUser = await handler.authenticate(request: reqWithToken, authManager: authManager)
        XCTAssertNil(failedUser)
    }
    
    func testAuthHandlerFactory() {
        // Test creating handlers for all methods
        let allHandlers = AuthenticationHandlerFactory.createHandlers(for: [.basic, .apiKey, .jwt, .token])
        
        // We should have 4 handlers (plus CloudKit on macOS)
        #if os(macOS)
        XCTAssertEqual(allHandlers.count, 4) // We're not including iCloud in the test
        #else
        XCTAssertEqual(allHandlers.count, 4)
        #endif
        
        // Test creating handlers for specific methods
        let basicHandlers = AuthenticationHandlerFactory.createHandlers(for: [.basic])
        XCTAssertEqual(basicHandlers.count, 1)
        XCTAssertEqual(basicHandlers[0].method, .basic)
        
        // Test creating handlers for multiple methods
        let multiHandlers = AuthenticationHandlerFactory.createHandlers(for: [.basic, .apiKey])
        XCTAssertEqual(multiHandlers.count, 2)
        
        // Verify we have the right handlers in the array
        let methods = Set(multiHandlers.map { $0.method })
        XCTAssertTrue(methods.contains(.basic))
        XCTAssertTrue(methods.contains(.apiKey))
    }
} 