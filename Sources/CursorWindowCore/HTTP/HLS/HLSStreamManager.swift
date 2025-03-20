import Foundation
import os.log

/// Manages HLS streaming sessions and timeouts
public actor HLSStreamManager {
    /// Errors that can occur during streaming
    public enum StreamError: Error, LocalizedError {
        /// Stream is already in use
        case streamInUse
        
        /// Stream is not available
        case streamNotAvailable
        
        /// Stream has timed out
        case streamTimeout
        
        /// Error description
        public var errorDescription: String? {
            switch self {
            case .streamInUse:
                return "Stream is already in use by another client"
            case .streamNotAvailable:
                return "Stream is not available"
            case .streamTimeout:
                return "Stream has timed out due to inactivity"
            }
        }
    }
    
    /// Whether the stream is active
    public private(set) var isStreaming = false
    
    /// Time of last activity
    private var lastActivity: Date?
    
    /// Stream access token
    private var streamToken: String?
    
    /// Timeout interval in seconds
    private let timeoutInterval: TimeInterval
    
    /// Logger
    private let logger = Logger(subsystem: "com.cursor-window", category: "HLSStreamManager")
    
    /// Initialize with timeout
    /// - Parameter timeoutInterval: Stream timeout interval in seconds
    public init(timeoutInterval: TimeInterval = 60.0) {
        self.timeoutInterval = timeoutInterval
    }
    
    /// Start streaming with a unique token
    /// - Parameter token: Stream access token
    /// - Returns: Token for stream access
    /// - Throws: StreamError if stream is already in use
    public func startStreaming() throws -> String {
        if isStreaming {
            throw StreamError.streamInUse
        }
        
        // Generate a random token
        let token = UUID().uuidString
        self.streamToken = token
        self.isStreaming = true
        self.lastActivity = Date()
        
        logger.info("Streaming started with token: \(token)")
        
        return token
    }
    
    /// Stop streaming
    public func stopStreaming() {
        isStreaming = false
        lastActivity = nil
        streamToken = nil
        
        logger.info("Streaming stopped")
    }
    
    /// Update stream activity timestamp
    /// - Parameter token: Stream access token
    /// - Throws: StreamError if token is invalid
    public func updateActivity(token: String?) throws {
        // If no token provided but streaming is active, just update
        if token == nil && isStreaming {
            lastActivity = Date()
            return
        }
        
        // Validate token
        guard isStreaming, let streamToken = streamToken, token == streamToken else {
            throw StreamError.streamNotAvailable
        }
        
        // Update activity timestamp
        lastActivity = Date()
    }
    
    /// Check if stream has timed out
    /// - Returns: Whether the stream has timed out
    public func hasTimedOut() -> Bool {
        guard isStreaming, let lastActivity = lastActivity else {
            return false
        }
        
        let elapsed = Date().timeIntervalSince(lastActivity)
        return elapsed > timeoutInterval
    }
    
    /// Check stream and handle timeout if needed
    /// - Returns: Whether the stream was timed out and stopped
    public func checkTimeout() -> Bool {
        if hasTimedOut() {
            logger.warning("Stream timed out after \(timeoutInterval) seconds of inactivity")
            stopStreaming()
            return true
        }
        
        return false
    }
    
    /// Get current stream status information
    /// - Returns: Dictionary with stream status
    public func getStreamStatus() -> [String: Any] {
        var status: [String: Any] = [
            "isStreaming": isStreaming
        ]
        
        if let lastActivity = lastActivity {
            status["lastActivity"] = lastActivity.timeIntervalSince1970
            status["timeSinceLastActivity"] = Date().timeIntervalSince(lastActivity)
        }
        
        return status
    }
} 