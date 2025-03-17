import Foundation

/// Represents a video quality option for HLS streaming
public struct HLSQualityOption: Equatable {
    /// The quality identifier (e.g., "high", "medium", "low")
    public let id: String
    
    /// The resolution width in pixels
    public let width: Int
    
    /// The resolution height in pixels
    public let height: Int
    
    /// The target bitrate in bits per second
    public let bitrate: Int
    
    /// The codec string (e.g., "avc1.4d001f,mp4a.40.2")
    public let codecs: String
    
    public init(id: String, width: Int, height: Int, bitrate: Int, codecs: String) {
        self.id = id
        self.width = width
        self.height = height
        self.bitrate = bitrate
        self.codecs = codecs
    }
}

/// Generates HLS playlists specifically for HTTP server delivery
/// 
/// This generator is designed for HTTP server use cases and differs from `M3U8PlaylistGenerator`
/// in several ways:
/// - It is optimized for quality-based streaming with multiple profiles
/// - It includes codec information in the master playlist
/// - It uses a different directory structure for segments (quality/segment.ts)
/// - It works with explicit base URLs for server-based delivery
/// - It handles segment path construction differently, normalizing URLs 
///
/// This generator is complementary to `M3U8PlaylistGenerator` which is used for
/// more general HLS playlist generation in the core HLS implementation.
@available(macOS 14.0, *)
public struct HLSPlaylistGenerator {
    /// The base URL for the stream
    private let baseURL: String
    
    /// The available quality options
    private let qualities: [HLSQualityOption]
    
    /// The target segment duration in seconds
    private let targetDuration: Int
    
    public init(baseURL: String, qualities: [HLSQualityOption], targetDuration: Int = 2) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.qualities = qualities
        self.targetDuration = targetDuration
    }
    
    /// Generates a master playlist containing all available quality options
    /// - Returns: The master playlist content
    public func generateMasterPlaylist() -> String {
        var playlist = "#EXTM3U\n"
        playlist += "#EXT-X-VERSION:3\n"
        
        for quality in qualities {
            // Add stream info
            playlist += "#EXT-X-STREAM-INF:BANDWIDTH=\(quality.bitrate),"
            playlist += "RESOLUTION=\(quality.width)x\(quality.height),"
            playlist += "CODECS=\"\(quality.codecs)\"\n"
            
            // Add playlist URL
            playlist += "\(baseURL)/\(quality.id)/playlist.m3u8\n"
        }
        
        return playlist
    }
    
    /// Generates a media playlist for a specific quality option
    /// - Parameters:
    ///   - quality: The quality option to generate the playlist for
    ///   - segments: The available segments
    ///   - isEndOfStream: Whether this is the final playlist update
    /// - Returns: The media playlist content
    public func generateMediaPlaylist(quality: HLSQualityOption, segments: [TSSegment], isEndOfStream: Bool = false) -> String {
        var playlist = "#EXTM3U\n"
        playlist += "#EXT-X-VERSION:3\n"
        playlist += "#EXT-X-TARGETDURATION:\(targetDuration)\n"
        
        if let firstSegment = segments.first {
            let sequenceNumber = Int(firstSegment.path.components(separatedBy: "_").last?.components(separatedBy: ".").first ?? "0") ?? 0
            playlist += "#EXT-X-MEDIA-SEQUENCE:\(sequenceNumber)\n"
        }
        
        // Add segments
        for segment in segments {
            playlist += "#EXTINF:\(String(format: "%.3f", segment.duration)),\n"
            playlist += "\(baseURL)/\(quality.id)/\(segment.path.components(separatedBy: "/").last ?? "")\n"
        }
        
        // Add end marker if this is the final playlist
        if isEndOfStream {
            playlist += "#EXT-X-ENDLIST\n"
        }
        
        return playlist
    }
} 