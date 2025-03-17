import Foundation

/// Manages HLS stream access and connection state
public actor HLSStreamManager {
    /// Error types for HLS stream operations
    public enum HLSStreamError: Error {
        case streamInUse
        case noActiveStream
        case invalidStreamKey
    }
    
    /// Represents a connected client
    private struct StreamConnection {
        let id: UUID
        let connectedAt: Date
        let lastAccessedAt: Date
        
        init(id: UUID = UUID()) {
            self.id = id
            self.connectedAt = Date()
            self.lastAccessedAt = Date()
        }
    }
    
    /// The currently active connection, if any
    private var activeConnection: StreamConnection?
    
    /// Timeout duration for inactive connections (5 minutes)
    private let connectionTimeout: TimeInterval = 300
    
    /// Task for checking connection timeouts
    private var timeoutTask: Task<Void, Never>?
    
    public init() {
        Task {
            await startTimeoutChecker()
        }
    }
    
    deinit {
        timeoutTask?.cancel()
    }
    
    /// Requests access to the stream
    /// - Returns: A stream key that must be included in subsequent requests
    public func requestAccess() async throws -> UUID {
        // Check if there's an active connection and it hasn't timed out
        if let connection = activeConnection {
            let timeSinceLastAccess = Date().timeIntervalSince(connection.lastAccessedAt)
            if timeSinceLastAccess < connectionTimeout {
                throw HLSStreamError.streamInUse
            }
        }
        
        // Create new connection
        let connection = StreamConnection()
        activeConnection = connection
        return connection.id
    }
    
    /// Validates a stream key and updates the last accessed time
    /// - Parameter streamKey: The stream key to validate
    /// - Returns: true if the key is valid
    public func validateAccess(_ streamKey: UUID) async -> Bool {
        guard let connection = activeConnection,
              connection.id == streamKey else {
            return false
        }
        
        // Update last accessed time
        activeConnection = StreamConnection(id: connection.id)
        return true
    }
    
    /// Releases access to the stream
    /// - Parameter streamKey: The stream key to release
    public func releaseAccess(_ streamKey: UUID) async {
        guard let connection = activeConnection,
              connection.id == streamKey else {
            return
        }
        
        activeConnection = nil
    }
    
    /// Starts the timeout checker
    private func startTimeoutChecker() async {
        timeoutTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 60 seconds
                await self?.checkTimeout()
            }
        }
    }
    
    /// Checks for connection timeout
    internal func checkTimeout() async {
        guard let connection = activeConnection else { return }
        
        let timeSinceLastAccess = Date().timeIntervalSince(connection.lastAccessedAt)
        if timeSinceLastAccess >= connectionTimeout {
            activeConnection = nil
        }
    }
} 