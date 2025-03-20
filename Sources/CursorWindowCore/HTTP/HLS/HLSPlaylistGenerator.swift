import Foundation

/// Generator for HLS playlists (both master and media playlists)
public class HLSPlaylistGenerator {
    /// Information about a segment in the playlist
    public struct SegmentInfo {
        /// Filename of segment
        public let filename: String
        
        /// Duration in seconds
        public let duration: Double
        
        /// Whether this segment represents a discontinuity
        public let isDiscontinuity: Bool
        
        /// Initialize segment info
        /// - Parameters:
        ///   - filename: Segment filename
        ///   - duration: Duration in seconds
        ///   - isDiscontinuity: Whether this represents a discontinuity
        public init(filename: String, duration: Double, isDiscontinuity: Bool = false) {
            self.filename = filename
            self.duration = duration
            self.isDiscontinuity = isDiscontinuity
        }
    }
    
    /// Base URL for stream
    private let baseURL: String
    
    /// Available stream qualities
    private let qualities: [StreamQuality]
    
    /// Number of segments to include in playlist
    private let playlistLength: Int
    
    /// Target segment duration
    private let targetSegmentDuration: Double
    
    /// Initialize the playlist generator
    /// - Parameters:
    ///   - baseURL: Server base URL including protocol
    ///   - qualities: Array of available stream qualities
    ///   - playlistLength: Number of segments to include in playlist
    ///   - targetSegmentDuration: Target segment duration
    public init(
        baseURL: String,
        qualities: [StreamQuality],
        playlistLength: Int = 5,
        targetSegmentDuration: Double = 4.0
    ) {
        self.baseURL = baseURL
        self.qualities = qualities
        self.playlistLength = playlistLength
        self.targetSegmentDuration = targetSegmentDuration
    }
    
    /// Generate a master playlist for adaptive streaming
    /// - Returns: Master playlist as string
    public func generateMasterPlaylist() -> String {
        var playlist = "#EXTM3U\n"
        playlist += "#EXT-X-VERSION:3\n"
        
        // Add each quality variant
        for quality in qualities {
            // Use resolution and bandwidth from the existing enum
            let resolution = "\(Int(quality.encoderSettings.resolution.width))x\(Int(quality.encoderSettings.resolution.height))"
            playlist += "#EXT-X-STREAM-INF:BANDWIDTH=\(quality.bandwidth),RESOLUTION=\(resolution)\n"
            playlist += "stream/\(quality.rawValue)/index.m3u8\n"
        }
        
        return playlist
    }
    
    /// Generate a media playlist for a specific quality
    /// - Parameters:
    ///   - quality: Stream quality
    ///   - segments: Available segments
    ///   - sequenceNumber: Media sequence number
    /// - Returns: Media playlist as string
    public func generateMediaPlaylist(
        quality: StreamQuality,
        segments: [SegmentInfo],
        sequenceNumber: Int = 0
    ) -> String {
        var playlist = "#EXTM3U\n"
        playlist += "#EXT-X-VERSION:3\n"
        playlist += "#EXT-X-TARGETDURATION:\(Int(ceil(targetSegmentDuration)))\n"
        playlist += "#EXT-X-MEDIA-SEQUENCE:\(sequenceNumber)\n"
        
        // Add each segment
        for segment in segments {
            if segment.isDiscontinuity {
                playlist += "#EXT-X-DISCONTINUITY\n"
            }
            
            playlist += "#EXTINF:\(String(format: "%.3f", segment.duration)),\n"
            playlist += "\(segment.filename)\n"
        }
        
        return playlist
    }
} 