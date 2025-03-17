import XCTest
@testable import CursorWindowCore
import Vapor
import XCTVapor

@available(macOS 14.0, *)
final class RateLimitTests: XCTestCase {
    private var vaporHelper: VaporTestHelper!
    private var rateLimiter: RateLimiter!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create rate limiter with test configuration (low limits for easier testing)
        let rateLimitConfig = RateLimitConfiguration(
            maxRequests: 3,
            windowSeconds: 60,
            limitType: .ip,
            excludedPaths: ["/excluded"],
            limitExceededStatus: .tooManyRequests
        )
        
        rateLimiter = RateLimiter(configuration: rateLimitConfig)
        
        // Initialize the Vapor helper
        vaporHelper = try await VaporTestHelper(
            environment: .testing,
            hostname: "localhost",
            port: 8083,
            logLevel: .debug
        )
        
        // Set up routes for testing
        await MainActor.run {
            // Add rate limiting middleware
            vaporHelper.app.middleware.use(RateLimitMiddleware(rateLimiter: rateLimiter))
            
            // Configure test routes
            configureTestRoutes(vaporHelper.app)
        }
        
        // Start the server
        try await vaporHelper.startServer()
    }
    
    override func tearDown() async throws {
        try await vaporHelper.shutdown()
        vaporHelper = nil
        rateLimiter = nil
        try await super.tearDown()
    }
    
    func testRateLimiting() async throws {
        // Make 3 successful requests (within limit)
        await MainActor.run {
            do {
                for i in 1...3 {
                    try vaporHelper.app.test(.GET, "test", afterResponse: { response in
                        XCTAssertEqual(response.status, .ok)
                        
                        // Verify rate limit headers
                        XCTAssertEqual(response.headers["X-RateLimit-Limit"].first, "3")
                        XCTAssertEqual(response.headers["X-RateLimit-Remaining"].first, "\(3 - i)")
                        XCTAssertNotNil(response.headers["X-RateLimit-Reset"].first)
                    })
                }
                
                // Fourth request should be rate limited
                try vaporHelper.app.test(.GET, "test", afterResponse: { response in
                    XCTAssertEqual(response.status, .tooManyRequests)
                    
                    // Verify rate limit headers
                    XCTAssertEqual(response.headers["X-RateLimit-Limit"].first, "3")
                    XCTAssertEqual(response.headers["X-RateLimit-Remaining"].first, "0")
                    XCTAssertNotNil(response.headers["X-RateLimit-Reset"].first)
                    XCTAssertNotNil(response.headers["Retry-After"].first)
                })
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
    }
    
    func testExcludedPaths() async throws {
        // Excluded paths should not be rate limited
        await MainActor.run {
            do {
                // Make many requests to excluded path, should all succeed
                for _ in 1...10 {
                    try vaporHelper.app.test(.GET, "excluded", afterResponse: { response in
                        XCTAssertEqual(response.status, .ok)
                    })
                }
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
    }
    
    func testGroupedRateLimiter() async throws {
        await MainActor.run {
            do {
                // Group has a different rate limiter with even stricter limits (max 2 requests)
                
                // Two requests should succeed
                for _ in 1...2 {
                    try vaporHelper.app.test(.GET, "strict/test", afterResponse: { response in
                        XCTAssertEqual(response.status, .ok)
                    })
                }
                
                // Third request should fail with 429
                try vaporHelper.app.test(.GET, "strict/test", afterResponse: { response in
                    XCTAssertEqual(response.status, .tooManyRequests)
                })
                
                // But we should still be able to make requests to non-strict endpoints
                // (since we didn't exceed the global rate limiter's 3 requests limit yet)
                try vaporHelper.app.test(.GET, "test", afterResponse: { response in
                    XCTAssertEqual(response.status, .ok)
                })
            } catch {
                XCTFail("Test failed with error: \(error)")
            }
        }
    }
    
    @MainActor
    private func configureTestRoutes(_ app: Application) {
        // Regular endpoint
        app.get("test") { req -> String in
            return "Test endpoint"
        }
        
        // Excluded from rate limiting
        app.get("excluded") { req -> String in
            return "Excluded endpoint"
        }
        
        // Create a stricter rate limiter for a specific group of routes
        let strictRateLimiter = RateLimiter(configuration: RateLimitConfiguration(
            maxRequests: 2,
            windowSeconds: 60
        ))
        
        // Strict rate limited group
        let strictGroup = app.grouped("strict").rateLimited(using: strictRateLimiter)
        
        strictGroup.get("test") { req -> String in
            return "Strict rate limited endpoint"
        }
    }
} 