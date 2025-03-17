import Foundation
import Vapor
import Logging

/// Configuration for request logging middleware
public struct RequestLoggingConfiguration {
    /// Whether to log HTTP requests
    public var logRequests: Bool
    
    /// Log level for requests
    public var level: Logger.Level
    
    /// Paths to exclude from logging (wildcard patterns supported)
    public var excludedPaths: [String]
    
    /// Whether to log request bodies
    public var logRequestBody: Bool
    
    /// Whether to log response bodies
    public var logResponseBody: Bool
    
    /// Whether to log performance metrics
    public var logPerformance: Bool
    
    /// Initialize request logging configuration
    public init(
        logRequests: Bool = true,
        level: Logger.Level = .info,
        excludedPaths: [String] = ["/health", "/metrics", "*.ico", "*.png", "*.jpg", "*.css", "*.js"],
        logRequestBody: Bool = false,
        logResponseBody: Bool = false,
        logPerformance: Bool = true
    ) {
        self.logRequests = logRequests
        self.level = level
        self.excludedPaths = excludedPaths
        self.logRequestBody = logRequestBody
        self.logResponseBody = logResponseBody
        self.logPerformance = logPerformance
    }
    
    /// Predefined basic configuration
    public static let basic = RequestLoggingConfiguration()
    
    /// Predefined verbose configuration
    public static let verbose = RequestLoggingConfiguration(
        logRequests: true,
        level: .debug,
        excludedPaths: ["/health", "/metrics"],
        logRequestBody: true,
        logResponseBody: true,
        logPerformance: true
    )
    
    /// Predefined disabled configuration
    public static let disabled = RequestLoggingConfiguration(
        logRequests: false
    )
    
    /// Check if a path should be excluded from logging
    func shouldExcludePath(_ path: String) -> Bool {
        guard logRequests else { return true }
        
        return excludedPaths.contains { pattern in
            if pattern.contains("*") {
                return path.matches(wildcard: pattern)
            } else {
                return path.starts(with: pattern)
            }
        }
    }
}

/// Middleware for logging HTTP requests
final class RequestLoggingMiddleware: Middleware {
    private let config: RequestLoggingConfiguration
    private let logger: Logger
    private weak var httpServerManager: HTTPServerManager?
    
    init(config: RequestLoggingConfiguration, logger: Logger, httpServerManager: HTTPServerManager? = nil) {
        self.config = config
        self.logger = logger
        self.httpServerManager = httpServerManager
    }
    
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Check if this path should be excluded from logging
        if config.shouldExcludePath(request.url.path) {
            return next.respond(to: request)
        }
        
        let startTime = Date()
        
        // Record request body if configured to do so
        var requestBody: String?
        if config.logRequestBody, let bodyData = request.body.data {
            requestBody = String(data: bodyData, encoding: .utf8) ?? "Unable to decode request body"
        }
        
        return next.respond(to: request).map { response in
            // Calculate duration
            let duration = Date().timeIntervalSince(startTime)
            
            // Record response body if configured to do so
            var responseBody: String?
            if self.config.logResponseBody, let bodyData = response.body.data {
                responseBody = String(data: bodyData, encoding: .utf8) ?? "Unable to decode response body"
            }
            
            // Log the request
            let logLevel = self.determineLogLevel(statusCode: response.status.code)
            let logMessage = "\(request.method.string) \(request.url.path) -> \(response.status.code)"
            
            var metadata: Logger.Metadata = [
                "method": .string(request.method.string),
                "path": .string(request.url.path),
                "status": .string(String(response.status.code)),
                "duration_ms": .string(String(format: "%.2f", duration * 1000))
            ]
            
            if let clientIp = request.headers.first(name: "X-Forwarded-For") ?? request.remoteAddress?.ipAddress {
                metadata["client_ip"] = .string(clientIp)
            }
            
            if let requestBody = requestBody {
                metadata["request_body"] = .string(requestBody)
            }
            
            if let responseBody = responseBody {
                metadata["response_body"] = .string(responseBody)
            }
            
            if self.config.logPerformance {
                metadata["performance"] = .dictionary([
                    "duration_ms": .string(String(format: "%.2f", duration * 1000)),
                    "timestamp": .string(ISO8601DateFormatter().string(from: startTime))
                ])
            }
            
            self.logger.log(level: logLevel, "\(logMessage)", metadata: metadata)
            
            // Record request for admin dashboard if available
            let clientIp = request.headers.first(name: "X-Forwarded-For") ?? request.remoteAddress?.ipAddress ?? "unknown"
            
            Task {
                await self.httpServerManager?.recordRequest(
                    method: request.method.string,
                    path: request.url.path,
                    statusCode: response.status.code,
                    ipAddress: clientIp,
                    duration: duration,
                    details: requestBody
                )
            }
            
            return response
        }
    }
    
    /// Determine log level based on status code
    private func determineLogLevel(statusCode: Int) -> Logger.Level {
        if statusCode >= 500 {
            return .error
        } else if statusCode >= 400 {
            return .warning
        } else {
            return config.level
        }
    }
}

private extension String {
    /// Check if string matches a wildcard pattern
    func matches(wildcard pattern: String) -> Bool {
        let patternComponents = pattern.split(separator: "*")
        var remaining = self
        
        for (index, component) in patternComponents.enumerated() {
            let componentStr = String(component)
            
            if index == 0 {
                if !remaining.hasPrefix(componentStr) {
                    return false
                }
                remaining = String(remaining.dropFirst(componentStr.count))
            } else if index == patternComponents.count - 1 {
                return remaining.hasSuffix(componentStr)
            } else {
                guard let range = remaining.range(of: componentStr) else {
                    return false
                }
                remaining = String(remaining[range.upperBound...])
            }
        }
        
        return true
    }
} 