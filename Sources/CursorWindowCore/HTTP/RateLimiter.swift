import Vapor
import Foundation

/// Configuration for the rate limiter
public struct RateLimitConfiguration: Equatable {
    /// Type of rate limiting to apply
    public enum LimitType: Equatable {
        /// Limit by IP address
        case ip
        
        /// Limit by custom identifier (e.g., user ID, API key)
        case custom(keyPath: String)
        
        /// Limit by both IP and a custom identifier
        case combined(keyPath: String)
    }
    
    /// Maximum number of requests allowed in the window
    public let maxRequests: Int
    
    /// Time window in seconds
    public let windowSeconds: Int
    
    /// Rate limit type
    public let limitType: LimitType
    
    /// Request paths to exclude from rate limiting
    public let excludedPaths: [String]
    
    /// Response status code when rate limit is exceeded
    public let limitExceededStatus: HTTPStatus
    
    /// Whether to include rate limit headers in responses
    public let includeHeaders: Bool
    
    /// Whether rate limiting is enabled
    public let isEnabled: Bool
    
    /// Creates a new rate limit configuration
    public init(
        maxRequests: Int = 100,
        windowSeconds: Int = 60,
        limitType: LimitType = .ip,
        excludedPaths: [String] = ["/health", "/version"],
        limitExceededStatus: HTTPStatus = .tooManyRequests,
        includeHeaders: Bool = true,
        isEnabled: Bool = true
    ) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
        self.limitType = limitType
        self.excludedPaths = excludedPaths
        self.limitExceededStatus = limitExceededStatus
        self.includeHeaders = includeHeaders
        self.isEnabled = isEnabled
    }
    
    /// Standard rate limiting for APIs
    public static let standard = RateLimitConfiguration()
    
    /// Strict rate limiting for authentication endpoints
    public static let strict = RateLimitConfiguration(
        maxRequests: 5,
        windowSeconds: 60,
        limitType: .ip,
        excludedPaths: ["/health", "/version"]
    )
    
    /// Disabled rate limiting
    public static let disabled = RateLimitConfiguration(isEnabled: false)
}

/// Actor that manages rate limiting for HTTP requests
public actor RateLimiter {
    /// Represents a request bucket for rate limiting
    private struct RequestBucket {
        /// Timestamps of requests made
        var timestamps: [Date]
        
        /// Limit for this bucket
        let limit: Int
        
        /// Window in seconds for this bucket
        let windowSeconds: Int
        
        /// Creates a new request bucket
        init(limit: Int, windowSeconds: Int) {
            self.timestamps = []
            self.limit = limit
            self.windowSeconds = windowSeconds
        }
        
        /// Checks if a request is allowed and updates the bucket if it is
        mutating func checkAndUpdate() -> Bool {
            let now = Date()
            
            // Remove expired timestamps
            let cutoff = now.addingTimeInterval(-Double(windowSeconds))
            timestamps = timestamps.filter { $0 > cutoff }
            
            // Check if adding a new request would exceed the limit
            guard timestamps.count < limit else {
                return false
            }
            
            // Add new timestamp
            timestamps.append(now)
            return true
        }
        
        /// Returns the number of remaining requests in the current window
        var remaining: Int {
            let now = Date()
            let cutoff = now.addingTimeInterval(-Double(windowSeconds))
            let activeCount = timestamps.filter { $0 > cutoff }.count
            return max(0, limit - activeCount)
        }
        
        /// Returns the reset time in seconds
        var resetSeconds: Int {
            guard let oldestTimestamp = timestamps.min() else {
                return 0
            }
            
            let resetTime = oldestTimestamp.addingTimeInterval(Double(windowSeconds))
            let secondsToReset = max(0, Int(resetTime.timeIntervalSince(Date())))
            return secondsToReset
        }
    }
    
    /// Configuration for the rate limiter
    private let configuration: RateLimitConfiguration
    
    /// Buckets for rate limiting, keyed by identifier
    private var buckets: [String: RequestBucket] = [:]
    
    /// Initializes the rate limiter with the specified configuration
    public init(configuration: RateLimitConfiguration = .standard) {
        self.configuration = configuration
    }
    
    /// Checks if a request is allowed based on the rate limit configuration
    /// - Parameter req: The request to check
    /// - Returns: A tuple containing whether the request is allowed and rate limit information
    public func isAllowed(_ req: Request) -> (allowed: Bool, limit: Int, remaining: Int, resetSeconds: Int) {
        // Skip rate limiting for excluded paths
        if configuration.excludedPaths.contains(req.url.path) {
            return (true, configuration.maxRequests, configuration.maxRequests, 0)
        }
        
        // Get identifier based on limit type
        let identifier = getIdentifier(for: req)
        
        // Get or create bucket
        var bucket = buckets[identifier] ?? RequestBucket(
            limit: configuration.maxRequests,
            windowSeconds: configuration.windowSeconds
        )
        
        // Check if allowed and update
        let allowed = bucket.checkAndUpdate()
        
        // Update bucket in dictionary
        buckets[identifier] = bucket
        
        return (allowed, configuration.maxRequests, bucket.remaining, bucket.resetSeconds)
    }
    
    /// Cleans up expired buckets to prevent memory leaks
    public func cleanupExpiredBuckets() {
        let now = Date()
        
        // Remove buckets with no timestamps in the window
        buckets = buckets.filter { identifier, bucket in
            let cutoff = now.addingTimeInterval(-Double(configuration.windowSeconds))
            let activeCount = bucket.timestamps.filter { $0 > cutoff }.count
            return activeCount > 0
        }
    }
    
    /// Gets the identifier for a request based on the limit type
    private func getIdentifier(for req: Request) -> String {
        switch configuration.limitType {
        case .ip:
            return req.remoteAddress?.ipAddress ?? "unknown"
            
        case .custom(let keyPath):
            // Try to get the custom identifier from the request
            if let customValue = req.headers.first(name: keyPath) {
                return customValue
            } else if let token = req.query[String.self, at: keyPath] {
                return token
            } else {
                return "unknown"
            }
            
        case .combined(let keyPath):
            let ip = req.remoteAddress?.ipAddress ?? "unknown"
            let custom = req.headers.first(name: keyPath) ?? req.query[String.self, at: keyPath] ?? "unknown"
            return "\(ip):\(custom)"
        }
    }
}

/// Middleware for rate limiting requests
public struct RateLimitMiddleware: AsyncMiddleware {
    private let rateLimiter: RateLimiter
    
    /// Initializes the middleware with a rate limiter
    public init(rateLimiter: RateLimiter) {
        self.rateLimiter = rateLimiter
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check rate limit
        let (allowed, limit, remaining, resetSeconds) = await rateLimiter.isAllowed(request)
        
        // If not allowed, return 429 Too Many Requests
        guard allowed else {
            let response = Response(status: .tooManyRequests)
            
            // Add rate limit headers
            response.headers.add(name: "X-RateLimit-Limit", value: "\(limit)")
            response.headers.add(name: "X-RateLimit-Remaining", value: "0")
            response.headers.add(name: "X-RateLimit-Reset", value: "\(resetSeconds)")
            response.headers.add(name: "Retry-After", value: "\(resetSeconds)")
            
            return response
        }
        
        // Process the request
        let response = try await next.respond(to: request)
        
        // Add rate limit headers to response
        response.headers.add(name: "X-RateLimit-Limit", value: "\(limit)")
        response.headers.add(name: "X-RateLimit-Remaining", value: "\(remaining)")
        response.headers.add(name: "X-RateLimit-Reset", value: "\(resetSeconds)")
        
        return response
    }
}

// Extension for setting up rate limiting on routes
extension Application {
    /// Adds rate limiting to routes with the specified configuration
    /// - Parameter configuration: The rate limit configuration to use
    /// - Returns: The rate limiter instance
    @discardableResult
    public func enableRateLimiting(
        _ configuration: RateLimitConfiguration = .standard
    ) -> RateLimiter {
        let rateLimiter = RateLimiter(configuration: configuration)
        
        if configuration.isEnabled {
            middleware.use(RateLimitMiddleware(rateLimiter: rateLimiter))
        }
        
        return rateLimiter
    }
}

// Extension for applying rate limits to specific route groups
extension RoutesBuilder {
    /// Adds rate limiting to a route group
    /// - Parameter rateLimiter: The rate limiter to use
    /// - Returns: A routes builder with rate limiting applied
    public func rateLimited(using rateLimiter: RateLimiter) -> RoutesBuilder {
        return self.grouped(RateLimitMiddleware(rateLimiter: rateLimiter))
    }
} 