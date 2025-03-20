import Foundation
import Vapor

/// Represents a logged HTTP request
public struct RequestLog: Content {
    /// Unique identifier
    public let id: UUID
    
    /// HTTP method (GET, POST, etc.)
    public let method: String
    
    /// Request path
    public let path: String
    
    /// HTTP status code
    public let status: Int
    
    /// When the request was made
    public let timestamp: Date
    
    /// Request duration in seconds
    public let duration: Double
    
    /// Client IP address
    public let ipAddress: String
    
    /// Request body (if logged)
    public let requestBody: String?
    
    /// Response body (if logged)
    public let responseBody: String?
    
    /// Initialize a request log
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - method: HTTP method
    ///   - path: Request path
    ///   - status: HTTP status code
    ///   - timestamp: Request timestamp
    ///   - duration: Request duration
    ///   - ipAddress: Client IP address
    ///   - requestBody: Request body content
    ///   - responseBody: Response body content
    public init(
        id: UUID = UUID(),
        method: String,
        path: String,
        status: Int,
        timestamp: Date = Date(),
        duration: Double,
        ipAddress: String,
        requestBody: String? = nil,
        responseBody: String? = nil
    ) {
        self.id = id
        self.method = method
        self.path = path
        self.status = status
        self.timestamp = timestamp
        self.duration = duration
        self.ipAddress = ipAddress
        self.requestBody = requestBody
        self.responseBody = responseBody
    }
} 