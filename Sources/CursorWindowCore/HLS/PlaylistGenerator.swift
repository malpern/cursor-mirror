#if os(macOS)
import Foundation
import AVFoundation

/// Generates HLS playlists according to the M3U8 specification
public final class M3U8PlaylistGenerator: PlaylistGenerator {
    public init() {}
    
    /// Generate a master playlist containing stream variants
    /// - Parameter variants: Array of stream variants (quality levels)
    /// - Returns: M3U8 master playlist content
    public func generateMasterPlaylist(variants: [HLSVariant]) -> String {
        var playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        
        """
        
        for variant in variants {
            playlist += """
            #EXT-X-STREAM-INF:BANDWIDTH=\(variant.bandwidth),\
            RESOLUTION=\(variant.width)x\(variant.height),\
            FRAME-RATE=\(String(format: "%.3f", variant.frameRate))
            \(variant.playlistPath)
            
            """
        }
        
        return playlist
    }
    
    /// Generate a media playlist for a specific variant
    /// - Parameters:
    ///   - segments: Array of HLS segments to include
    ///   - configuration: HLS configuration options
    /// - Returns: M3U8 media playlist content
    public func generateMediaPlaylist(segments: [HLSSegment], configuration: HLSConfiguration) -> String {
        var playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:\(Int(ceil(configuration.targetSegmentDuration)))
        #EXT-X-MEDIA-SEQUENCE:\(segments.first?.sequenceNumber ?? 0)
        
        """
        
        for segment in segments {
            let segmentURL = configuration.baseURL.isEmpty ? 
                segment.filePath : 
                "\(configuration.baseURL)/\(segment.filePath)"
            
            playlist += """
            #EXTINF:\(String(format: "%.3f", segment.duration)),
            \(segmentURL)
            
            """
        }
        
        return playlist
    }
    
    /// Generate an event playlist that doesn't remove old segments
    /// - Parameters:
    ///   - segments: Array of HLS segments to include
    ///   - configuration: HLS configuration options
    /// - Returns: M3U8 event playlist content
    public func generateEventPlaylist(segments: [HLSSegment], configuration: HLSConfiguration) -> String {
        var playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:\(Int(ceil(configuration.targetSegmentDuration)))
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:EVENT
        
        """
        
        for segment in segments {
            let segmentURL = configuration.baseURL.isEmpty ? 
                segment.filePath : 
                "\(configuration.baseURL)/\(segment.filePath)"
            
            playlist += """
            #EXTINF:\(String(format: "%.3f", segment.duration)),
            \(segmentURL)
            
            """
        }
        
        return playlist
    }
    
    /// Generate a VOD (complete) playlist
    /// - Parameters:
    ///   - segments: Array of HLS segments to include
    ///   - configuration: HLS configuration options
    /// - Returns: M3U8 VOD playlist content
    public func generateVODPlaylist(segments: [HLSSegment], configuration: HLSConfiguration) -> String {
        var playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:\(Int(ceil(configuration.targetSegmentDuration)))
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        
        """
        
        for segment in segments {
            let segmentURL = configuration.baseURL.isEmpty ? 
                segment.filePath : 
                "\(configuration.baseURL)/\(segment.filePath)"
            
            playlist += """
            #EXTINF:\(String(format: "%.3f", segment.duration)),
            \(segmentURL)
            
            """
        }
        
        playlist += "#EXT-X-ENDLIST\n"
        
        return playlist
    }
}
#endif 