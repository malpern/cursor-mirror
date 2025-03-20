import Foundation
import Vapor

/// Represents an active stream connection
public struct StreamConnection: Sendable, Identifiable {
    /// Unique identifier for the connection
    public let id: UUID
    
    /// When the connection was established
    public let connectedAt: Date
    
    /// Client IP address
    public let clientIP: String
    
    /// Connection token
    public let token: UUID
}

/// Manages HLS stream access and state
public actor HLSStreamManager {
    /// Stream access error
    public enum StreamError: Error {
        /// Stream is already in use
        case streamInUse
        
        /// Invalid stream key
        case invalidStreamKey
        
        /// Stream not available
        case streamNotAvailable
    }
    
    /// Current active stream keys
    private var activeStreamKeys: Set<UUID> = []
    
    /// Whether anyone is currently streaming
    public var isStreaming: Bool {
        !activeStreamKeys.isEmpty
    }
    
    /// Number of active connections
    public var activeConnectionCount: Int {
        activeStreamKeys.count
    }
    
    /// Initialize an empty stream manager
    public init() {}
    
    /// Request access to the stream
    /// - Returns: A stream key UUID if access is granted
    /// - Throws: StreamError.streamInUse if the stream is already in use
    public func requestAccess() async throws -> UUID {
        // For now, we only allow a single active stream
        guard activeStreamKeys.isEmpty else {
            throw StreamError.streamInUse
        }
        
        // Generate a new stream key
        let streamKey = UUID()
        activeStreamKeys.insert(streamKey)
        
        return streamKey
    }
    
    /// Release access to the stream
    /// - Parameter streamKey: The stream key to release
    public func releaseAccess(_ streamKey: UUID) {
        activeStreamKeys.remove(streamKey)
    }
    
    /// Validate that a stream key exists and is valid
    /// - Parameter streamKey: The stream key to validate
    /// - Returns: True if the stream key is valid
    public func validateAccess(_ streamKey: UUID) -> Bool {
        activeStreamKeys.contains(streamKey)
    }
    
    /// Invalidate all stream keys
    public func invalidateAllStreams() {
        activeStreamKeys.removeAll()
    }
} 