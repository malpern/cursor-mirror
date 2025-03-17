import XCTest
import Vapor
import XCTVapor
@testable import CursorWindowCore

final class AdminDashboardTests: XCTestCase {
    var app: Application!
    var serverConfig: HTTPServerConfig!
    var serverManager: HTTPServerManager!
    var authManager: AuthenticationManager!
    var hlsManager: HLSStreamManager!
    var adminController: AdminController!
    
    override func setUp() async throws {
        app = Application(.testing)
        
        // Configure Auth Manager with test credentials
        authManager = AuthenticationManager(method: .basic, username: "admin", password: "password")
        authManager.adminAuthRequired = true
        
        // Configure HLS Manager
        hlsManager = HLSStreamManager(timeoutMinutes: 5)
        
        // Configure HTTP Server with admin dashboard enabled
        serverConfig = HTTPServerConfig(
            hostname: "localhost",
            port: 8080,
            auth: AuthConfig(method: .basic, username: "admin", password: "password", adminAuthRequired: true),
            admin: HTTPServerConfig.AdminDashboard(enabled: true)
        )
        
        serverManager = HTTPServerManager(config: serverConfig)
        
        // Create the admin controller manually for testing
        adminController = AdminController(httpServer: serverManager, hlsManager: hlsManager, authManager: authManager)
        
        // Configure routes for testing
        adminController.setupRoutes(app)
        
        try app.start()
    }
    
    override func tearDown() {
        app.shutdown()
    }
    
    func testLoginPage() throws {
        try app.test(.GET, "/admin/login", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertContains(response.body.string, "CursorWindow Admin")
            XCTAssertContains(response.body.string, "Username")
            XCTAssertContains(response.body.string, "Password")
        })
    }
    
    func testLoginSuccess() throws {
        // Test login with valid credentials
        try app.test(.POST, "/admin/login", beforeRequest: { req in
            try req.content.encode([
                "username": "admin",
                "password": "password"
            ])
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .seeOther)
            XCTAssertEqual(response.headers[.location].first, "/admin")
            XCTAssertNotNil(response.headers.setCookie)
            
            // Verify the cookie was set
            let cookie = response.headers.setCookie!
            XCTAssertTrue(cookie.contains("admin_token="))
            XCTAssertTrue(cookie.contains("HttpOnly"))
        })
    }
    
    func testLoginFailure() throws {
        // Test login with invalid credentials
        try app.test(.POST, "/admin/login", beforeRequest: { req in
            try req.content.encode([
                "username": "admin",
                "password": "wrongpassword"
            ])
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .seeOther)
            XCTAssertEqual(response.headers[.location].first, "/admin/login?error=Invalid+credentials")
        })
    }
    
    func testProtectedRoutes() throws {
        // First, try to access protected route without authentication
        try app.test(.GET, "/admin", afterResponse: { response in
            XCTAssertEqual(response.status, .seeOther)
            XCTAssertEqual(response.headers[.location].first, "/admin/login")
        })
        
        // Login to get the token
        var adminToken: String?
        try app.test(.POST, "/admin/login", beforeRequest: { req in
            try req.content.encode([
                "username": "admin",
                "password": "password"
            ])
        }, afterResponse: { response in
            // Extract token from cookie for next request
            let cookieString = response.headers.setCookie!
            let tokenStart = cookieString.range(of: "admin_token=")!.upperBound
            let tokenEnd = cookieString.range(of: ";", range: tokenStart..<cookieString.endIndex)!.lowerBound
            adminToken = String(cookieString[tokenStart..<tokenEnd])
        })
        
        // Now try to access the protected route with authentication
        try app.test(.GET, "/admin", beforeRequest: { req in
            req.headers.cookie = "admin_token=\(adminToken!)"
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertContains(response.body.string, "Dashboard")
        })
    }
    
    func testDashboardData() throws {
        // Login first
        var adminToken: String?
        try app.test(.POST, "/admin/login", beforeRequest: { req in
            try req.content.encode([
                "username": "admin",
                "password": "password"
            ])
        }, afterResponse: { response in
            // Extract token from cookie for next request
            let cookieString = response.headers.setCookie!
            let tokenStart = cookieString.range(of: "admin_token=")!.upperBound
            let tokenEnd = cookieString.range(of: ";", range: tokenStart..<cookieString.endIndex)!.lowerBound
            adminToken = String(cookieString[tokenStart..<tokenEnd])
        })
        
        // Add some mock request logs
        for i in 0..<5 {
            let requestLog = AdminController.RequestLog(
                id: UUID(),
                timestamp: Date().addingTimeInterval(-Double(i * 60)),
                method: "GET",
                path: "/test/\(i)",
                statusCode: 200,
                ipAddress: "127.0.0.1",
                duration: 0.01,
                details: nil
            )
            adminController.recordRequest(requestLog)
        }
        
        // Check dashboard with logs
        try app.test(.GET, "/admin", beforeRequest: { req in
            req.headers.cookie = "admin_token=\(adminToken!)"
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertContains(response.body.string, "Dashboard")
            XCTAssertContains(response.body.string, "/test/")
        })
    }
    
    func testLogout() throws {
        // Login first
        var adminToken: String?
        try app.test(.POST, "/admin/login", beforeRequest: { req in
            try req.content.encode([
                "username": "admin",
                "password": "password"
            ])
        }, afterResponse: { response in
            // Extract token for next request
            let cookieString = response.headers.setCookie!
            let tokenStart = cookieString.range(of: "admin_token=")!.upperBound
            let tokenEnd = cookieString.range(of: ";", range: tokenStart..<cookieString.endIndex)!.lowerBound
            adminToken = String(cookieString[tokenStart..<tokenEnd])
        })
        
        // Perform logout
        try app.test(.GET, "/admin/logout", beforeRequest: { req in
            req.headers.cookie = "admin_token=\(adminToken!)"
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .seeOther)
            XCTAssertEqual(response.headers[.location].first, "/admin/login")
            
            // Verify the cookie was invalidated
            let cookie = response.headers.setCookie!
            XCTAssertTrue(cookie.contains("admin_token="))
            XCTAssertTrue(cookie.contains("Expires=Thu, 01 Jan 1970"))
        })
        
        // Verify we can't access protected route after logout
        try app.test(.GET, "/admin", beforeRequest: { req in
            req.headers.cookie = "admin_token=\(adminToken!)"
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .seeOther)
            XCTAssertEqual(response.headers[.location].first, "/admin/login")
        })
    }
    
    func testApiEndpoints() throws {
        // Login first
        var adminToken: String?
        try app.test(.POST, "/admin/login", beforeRequest: { req in
            try req.content.encode([
                "username": "admin",
                "password": "password"
            ])
        }, afterResponse: { response in
            // Extract token for next request
            let cookieString = response.headers.setCookie!
            let tokenStart = cookieString.range(of: "admin_token=")!.upperBound
            let tokenEnd = cookieString.range(of: ";", range: tokenStart..<cookieString.endIndex)!.lowerBound
            adminToken = String(cookieString[tokenStart..<tokenEnd])
        })
        
        // Test API key generation
        try app.test(.POST, "/admin/api/generate-api-key", beforeRequest: { req in
            req.headers.cookie = "admin_token=\(adminToken!)"
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            
            // Verify the response contains a success flag and API key
            let data = try JSONSerialization.jsonObject(with: response.body.data!, options: []) as! [String: String]
            XCTAssertEqual(data["success"], "true")
            XCTAssertNotNil(data["apiKey"])
        })
        
        // Test server status API
        try app.test(.GET, "/admin/api/server-status", beforeRequest: { req in
            req.headers.cookie = "admin_token=\(adminToken!)"
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
            
            // Verify the response contains the expected fields
            let data = try JSONSerialization.jsonObject(with: response.body.data!, options: []) as! [String: Any]
            XCTAssertNotNil(data["running"])
            XCTAssertNotNil(data["uptime"])
        })
    }
} 