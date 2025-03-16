#if os(macOS)
import Foundation
import AVFoundation

@available(macOS 14.0, *)
public struct HLSSegment: Identifiable {
    /// Unique identifier for the segment
    public let id: UUID
    /// Segment duration in seconds
    public let duration: Double
    /// Segment sequence number
    public let sequenceNumber: UInt
    /// Path to the segment file
    public let filePath: String
    /// Segment start time in the overall stream
    public let startTime: CMTime
    
    public init(id: UUID = UUID(), duration: Double, sequenceNumber: UInt, filePath: String, startTime: CMTime) {
        self.id = id
        self.duration = duration
        self.sequenceNumber = sequenceNumber
        self.filePath = filePath
        self.startTime = startTime
    }
}

/// Configuration options for HLS streaming
@available(macOS 14.0, *)
public struct HLSConfiguration {
    /// Target segment duration in seconds
    public let targetSegmentDuration: Double
    /// Number of segments to keep in the playlist
    public let playlistLength: Int
    /// Directory where segments will be stored
    public let segmentDirectory: String
    /// Base URL for segments in the playlist
    public let baseURL: String
    
    public init(targetSegmentDuration: Double, playlistLength: Int, segmentDirectory: String, baseURL: String) {
        self.targetSegmentDuration = targetSegmentDuration
        self.playlistLength = playlistLength
        self.segmentDirectory = segmentDirectory
        self.baseURL = baseURL
    }
}

/// Protocol for managing HLS segments and playlists
@available(macOS 14.0, *)
public protocol HLSManagerProtocol: Actor {
    /// Start HLS streaming with the given configuration
    func startStreaming() async throws
    
    /// Stop HLS streaming and cleanup resources
    func stopStreaming() async throws
    
    /// Process encoded video data
    func processEncodedData(_ data: Data, presentationTime: CMTime) async throws
    
    /// Get the current M3U8 playlist content
    func getCurrentPlaylist() async throws -> String
    
    /// Get the list of active segments
    func getActiveSegments() async -> [HLSSegment]
    
    /// Clean up old segments that are no longer needed
    func cleanupOldSegments() async throws
    
    /// Add a variant stream
    func addVariant(_ variant: HLSVariant) async
    
    /// Remove a variant stream
    func removeVariant(_ variant: HLSVariant) async
    
    /// Get the master playlist
    func getMasterPlaylist() async -> String
    
    /// Get the event playlist
    func getEventPlaylist() async -> String
    
    /// Get the VOD playlist
    func getVODPlaylist() async -> String
}

/// Protocol for writing HLS segments
@available(macOS 14.0, *)
public protocol HLSSegmentWriter: Actor {
    /// Start a new segment
    func startNewSegment(startTime: CMTime) async throws -> HLSSegment
    
    /// Write encoded video data to the current segment
    func writeEncodedData(_ data: Data) async throws
    
    /// Finish the current segment
    func finishCurrentSegment() async throws -> HLSSegment
    
    /// Clean up resources
    func cleanup() async throws
}

/// Protocol for generating M3U8 playlists
@available(macOS 14.0, *)
public protocol PlaylistGenerator {
    /// Generate a master playlist containing all variants
    func generateMasterPlaylist(variants: [HLSVariant]) -> String
    
    /// Generate a media playlist for a specific variant
    func generateMediaPlaylist(segments: [HLSSegment], configuration: HLSConfiguration) -> String
    
    /// Generate an event playlist that retains old segments
    func generateEventPlaylist(segments: [HLSSegment], configuration: HLSConfiguration) -> String
    
    /// Generate a VOD playlist with an end marker
    func generateVODPlaylist(segments: [HLSSegment], configuration: HLSConfiguration) -> String
}

/// Represents an HLS stream variant (quality level)
@available(macOS 14.0, *)
public struct HLSVariant: Equatable {
    /// Bandwidth in bits per second
    public let bandwidth: Int
    /// Resolution width
    public let width: Int
    /// Resolution height
    public let height: Int
    /// Frame rate
    public let frameRate: Double
    /// Path to the variant's playlist file
    public let playlistPath: String
    
    public init(bandwidth: Int, width: Int, height: Int, frameRate: Double, playlistPath: String) {
        self.bandwidth = bandwidth
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.playlistPath = playlistPath
    }
    
    public static func == (lhs: HLSVariant, rhs: HLSVariant) -> Bool {
        return lhs.bandwidth == rhs.bandwidth &&
               lhs.width == rhs.width &&
               lhs.height == rhs.height &&
               lhs.frameRate == rhs.frameRate &&
               lhs.playlistPath == rhs.playlistPath
    }
}

/// Errors that can occur during HLS streaming
@available(macOS 14.0, *)
public enum HLSError: LocalizedError, Equatable {
    /// Failed to create or write to a segment file
    case segmentWriteError(Error)
    /// Failed to create or access the segment directory
    case directoryError(String)
    /// Invalid configuration
    case invalidConfiguration
    /// Segment duration too short
    case segmentDurationTooShort
    /// No active segment available
    case noActiveSegment
    /// Failed to generate playlist
    case playlistGenerationError(String)
    /// Streaming has not been started
    case streamingNotStarted
    /// Invalid segment directory path
    case invalidSegmentDirectory
    /// File operation failed
    case fileOperationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .segmentWriteError(let error):
            return "Failed to write segment: \(error.localizedDescription)"
        case .directoryError(let message):
            return "Directory error: \(message)"
        case .invalidConfiguration:
            return "Invalid HLS configuration"
        case .segmentDurationTooShort:
            return "Segment duration is too short (minimum 2 seconds)"
        case .noActiveSegment:
            return "No active segment available"
        case .playlistGenerationError(let message):
            return "Failed to generate playlist: \(message)"
        case .streamingNotStarted:
            return "HLS streaming has not been started"
        case .invalidSegmentDirectory:
            return "Invalid segment directory path"
        case .fileOperationFailed(let message):
            return "File operation failed: \(message)"
        }
    }
    
    public static func == (lhs: HLSError, rhs: HLSError) -> Bool {
        switch (lhs, rhs) {
        case (.noActiveSegment, .noActiveSegment):
            return true
        case (.invalidConfiguration, .invalidConfiguration):
            return true
        case (.streamingNotStarted, .streamingNotStarted):
            return true
        case (.segmentWriteError(let lhsError), .segmentWriteError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.directoryError(let lhsMessage), .directoryError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.playlistGenerationError(let lhsMessage), .playlistGenerationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
#endif 