#if os(macOS)
import Foundation
import AVFoundation

/// Generates HLS playlists according to the M3U8 specification
@available(macOS 14.0, *)
public final class M3U8PlaylistGenerator: PlaylistGeneratorProtocol {
    public init() {}
    
    /// Generate a master playlist containing stream variants
    /// - Parameter variants: Array of stream variants (quality levels)
    /// - Returns: M3U8 master playlist content
    public func generateMasterPlaylist(variants: [HLSVariant], baseURL: String?) throws -> String {
        var playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        
        """
        
        for variant in variants {
            let variantPath = baseURL?.isEmpty ?? true ? 
                variant.playlistPath : 
                "\(baseURL!)/\(variant.playlistPath)"
            
            playlist += """
            #EXT-X-STREAM-INF:BANDWIDTH=\(variant.bandwidth),\
            RESOLUTION=\(variant.width)x\(variant.height),\
            FRAME-RATE=\(String(format: "%.3f", variant.frameRate))
            \(variantPath)
            
            """
        }
        
        return playlist
    }
    
    /// Generate a media playlist for a specific variant
    /// - Parameters:
    ///   - segments: Array of HLS segments to include
    ///   - targetDuration: Target duration for segments
    ///   - baseURL: Optional base URL for segment paths
    /// - Returns: M3U8 media playlist content
    public func generateMediaPlaylist(segments: [TSSegment], targetDuration: Int, baseURL: String?) throws -> String {
        var playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:\(targetDuration)
        #EXT-X-MEDIA-SEQUENCE:0
        
        """
        
        for segment in segments {
            let segmentURL = baseURL?.isEmpty ?? true ? 
                segment.path : 
                "\(baseURL!)/\(segment.path)"
            
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
    ///   - targetDuration: Target duration for segments
    ///   - baseURL: Optional base URL for segment paths
    /// - Returns: M3U8 event playlist content
    public func generateEventPlaylist(segments: [TSSegment], targetDuration: Int, baseURL: String?) throws -> String {
        var playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:\(targetDuration)
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:EVENT
        
        """
        
        for segment in segments {
            let segmentURL = baseURL?.isEmpty ?? true ? 
                segment.path : 
                "\(baseURL!)/\(segment.path)"
            
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
    ///   - targetDuration: Target duration for segments
    ///   - baseURL: Optional base URL for segment paths
    /// - Returns: M3U8 VOD playlist content
    public func generateVODPlaylist(segments: [TSSegment], targetDuration: Int, baseURL: String?) throws -> String {
        var playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:\(targetDuration)
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        
        """
        
        for segment in segments {
            let segmentURL = baseURL?.isEmpty ?? true ? 
                segment.path : 
                "\(baseURL!)/\(segment.path)"
            
            playlist += """
            #EXTINF:\(String(format: "%.3f", segment.duration)),
            \(segmentURL)
            
            """
        }
        
        playlist += "#EXT-X-ENDLIST\n"
        
        return playlist
    }
}
#else
#error("M3U8PlaylistGenerator is only available on macOS 14.0 or later")
#endif 