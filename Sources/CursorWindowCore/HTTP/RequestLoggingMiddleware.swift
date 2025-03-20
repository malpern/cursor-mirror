import Foundation
import Vapor
import Logging

/// Configuration for request logging
public struct RequestLoggingConfig {
    /// Whether to log request bodies
    public let logRequestBodies: Bool
    
    /// Whether to log response bodies
    public let logResponseBodies: Bool
    
    /// Maximum size of body to log (in bytes)
    public let maxBodyLogSize: Int
    
    /// Whether to log headers
    public let logHeaders: Bool
    
    /// Initialize with configuration
    /// - Parameters:
    ///   - logRequestBodies: Whether to log request bodies
    ///   - logResponseBodies: Whether to log response bodies
    ///   - maxBodyLogSize: Maximum size of body to log (in bytes)
    ///   - logHeaders: Whether to log headers
    public init(
        logRequestBodies: Bool = true,
        logResponseBodies: Bool = true,
        maxBodyLogSize: Int = 1024,
        logHeaders: Bool = false
    ) {
        self.logRequestBodies = logRequestBodies
        self.logResponseBodies = logResponseBodies
        self.maxBodyLogSize = maxBodyLogSize
        self.logHeaders = logHeaders
    }
}

/// Middleware for logging requests and responses
public struct RequestLoggingMiddleware: AsyncMiddleware {
    /// Logging configuration
    private let config: RequestLoggingConfig
    
    /// Logger
    private let logger: Logger
    
    /// Server manager (for recording requests)
    private weak var serverManager: HTTPServerManager?
    
    /// Initialize with config
    /// - Parameters:
    ///   - config: Logging configuration
    ///   - logger: Logger
    ///   - serverManager: HTTP server manager
    public init(
        config: RequestLoggingConfig = RequestLoggingConfig(),
        logger: Logger = Logger(label: "RequestLogger"),
        serverManager: HTTPServerManager? = nil
    ) {
        self.config = config
        self.logger = logger
        self.serverManager = serverManager
    }
    
    /// Handle the request and log it
    /// - Parameters:
    ///   - request: The request
    ///   - next: The next responder
    /// - Returns: The response
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Record the start time
        let startTime = Date()
        
        // Capture the request body if configured
        let requestBody = config.logRequestBodies ? await captureRequestBody(request) : nil
        
        // Process the request
        let response: Response
        do {
            response = try await next.respond(to: request)
        } catch {
            // Log any errors
            let duration = Date().timeIntervalSince(startTime)
            logger.error("Error processing request: \(error.localizedDescription)")
            
            // Record the request with error
            let statusCode = (error as? AbortError)?.status.code ?? 500
            await logRequest(
                request: request,
                statusCode: Int(statusCode),
                duration: duration,
                requestBody: requestBody,
                responseBody: nil
            )
            
            throw error
        }
        
        // Calculate request duration
        let duration = Date().timeIntervalSince(startTime)
        
        // Capture the response body if configured
        let responseBody = config.logResponseBodies ? captureResponseBody(response) : nil
        
        // Log the request
        await logRequest(
            request: request,
            statusCode: Int(response.status.code),
            duration: duration,
            requestBody: requestBody,
            responseBody: responseBody
        )
        
        return response
    }
    
    /// Capture the request body if it's text or JSON
    /// - Parameter request: The request
    /// - Returns: The request body as string
    private func captureRequestBody(_ request: Request) async -> String? {
        guard let contentType = request.headers.contentType,
              contentType.type == "application" || contentType.type == "text",
              contentType.subType.contains("json") || contentType.subType.contains("text") else {
            return nil
        }
        
        // Attempt to read the body
        let body: ByteBuffer
        do {
            body = try await request.body.collect(max: config.maxBodyLogSize).get()!
        } catch {
            return "Error reading body: \(error.localizedDescription)"
        }
        
        // Convert to string
        return String(buffer: body)
    }
    
    /// Capture the response body if it's text or JSON
    /// - Parameter response: The response
    /// - Returns: The response body as string
    private func captureResponseBody(_ response: Response) -> String? {
        guard let contentType = response.headers.contentType,
              contentType.type == "application" || contentType.type == "text",
              contentType.subType.contains("json") || contentType.subType.contains("text") else {
            return nil
        }
        
        // Get the body data
        // The body is not optional in Vapor 4, so we need to check if there's actual data
        if let buffer = response.body.buffer {
            // Convert to string, limiting size
            let data = buffer.readableBytesView.prefix(config.maxBodyLogSize)
            return String(data: Data(data), encoding: .utf8)
        }
        
        return nil
    }
    
    /// Log a request
    /// - Parameters:
    ///   - request: The request
    ///   - statusCode: The HTTP status code
    ///   - duration: Request duration
    ///   - requestBody: Request body
    ///   - responseBody: Response body
    private func logRequest(
        request: Request,
        statusCode: Int,
        duration: TimeInterval,
        requestBody: String?,
        responseBody: String?
    ) async {
        // Log to the server manager if available
        if let serverManager = serverManager {
            let log = RequestLog(
                method: request.method.rawValue,
                path: request.url.path,
                status: statusCode,
                timestamp: Date(),
                duration: duration,
                ipAddress: request.remoteAddress?.ipAddress ?? "unknown",
                requestBody: requestBody,
                responseBody: responseBody
            )
            
            await serverManager.recordRequest(log)
        }
        
        // Also log to the console
        logger.info("\(request.method.rawValue) \(request.url.path) - Status: \(statusCode) - Duration: \(String(format: "%.3f", duration))s")
    }
} 