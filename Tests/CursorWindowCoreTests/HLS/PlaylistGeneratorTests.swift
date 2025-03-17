#if os(macOS)
import XCTest
import AVFoundation
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class PlaylistGeneratorTests: XCTestCase {
    var generator: M3U8PlaylistGenerator!
    var configuration: HLSConfiguration!
    
    override func setUp() {
        super.setUp()
        generator = M3U8PlaylistGenerator()
        configuration = HLSConfiguration(
            targetSegmentDuration: 6.0,
            playlistLength: 5,
            segmentDirectory: "/tmp/hls",
            baseURL: "http://example.com/hls"
        )
    }
    
    override func tearDown() {
        generator = nil
        configuration = nil
        super.tearDown()
    }
    
    func testGenerateMasterPlaylist() throws {
        let variants = [
            HLSVariant(
                bandwidth: 2_000_000,
                width: 1920,
                height: 1080,
                frameRate: 30.0,
                playlistPath: "stream_high.m3u8"
            ),
            HLSVariant(
                bandwidth: 1_000_000,
                width: 1280,
                height: 720,
                frameRate: 30.0,
                playlistPath: "stream_medium.m3u8"
            )
        ]
        
        let playlist = try generator.generateMasterPlaylist(variants: variants, baseURL: configuration.baseURL)
        
        // Verify playlist contains required tags
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        
        // Verify variant streams are included
        XCTAssertTrue(playlist.contains("BANDWIDTH=2000000"))
        XCTAssertTrue(playlist.contains("RESOLUTION=1920x1080"))
        XCTAssertTrue(playlist.contains("FRAME-RATE=30.000"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/stream_high.m3u8"))
        
        XCTAssertTrue(playlist.contains("BANDWIDTH=1000000"))
        XCTAssertTrue(playlist.contains("RESOLUTION=1280x720"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/stream_medium.m3u8"))
    }
    
    func testGenerateMediaPlaylist() throws {
        let segments = [
            TSSegment(id: "1", path: "segment1.ts", duration: 6.0, startTime: 0.0),
            TSSegment(id: "2", path: "segment2.ts", duration: 6.0, startTime: 6.0),
            TSSegment(id: "3", path: "segment3.ts", duration: 6.0, startTime: 12.0)
        ]
        
        let playlist = try generator.generateMediaPlaylist(
            segments: segments,
            targetDuration: Int(configuration.targetSegmentDuration),
            baseURL: configuration.baseURL
        )
        
        // Verify playlist contains required tags
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
        XCTAssertTrue(playlist.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        
        // Verify segments are included with correct URLs
        XCTAssertTrue(playlist.contains("#EXTINF:6.000,"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/segment1.ts"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/segment2.ts"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/segment3.ts"))
    }
    
    func testGenerateEventPlaylist() throws {
        let segments = [
            TSSegment(id: "1", path: "segment1.ts", duration: 6.0, startTime: 0.0),
            TSSegment(id: "2", path: "segment2.ts", duration: 6.0, startTime: 6.0)
        ]
        
        let playlist = try generator.generateEventPlaylist(
            segments: segments,
            targetDuration: Int(configuration.targetSegmentDuration),
            baseURL: configuration.baseURL
        )
        
        // Verify playlist contains required tags
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
        XCTAssertTrue(playlist.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        XCTAssertTrue(playlist.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
        
        // Verify segments are included
        XCTAssertTrue(playlist.contains("#EXTINF:6.000,"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/segment1.ts"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/segment2.ts"))
    }
    
    func testGenerateVODPlaylist() throws {
        let segments = [
            TSSegment(id: "1", path: "segment1.ts", duration: 6.0, startTime: 0.0),
            TSSegment(id: "2", path: "segment2.ts", duration: 6.0, startTime: 6.0)
        ]
        
        let playlist = try generator.generateVODPlaylist(
            segments: segments,
            targetDuration: Int(configuration.targetSegmentDuration),
            baseURL: configuration.baseURL
        )
        
        // Verify playlist contains required tags
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
        XCTAssertTrue(playlist.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        XCTAssertTrue(playlist.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        XCTAssertTrue(playlist.contains("#EXT-X-ENDLIST"))
        
        // Verify segments are included
        XCTAssertTrue(playlist.contains("#EXTINF:6.000,"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/segment1.ts"))
        XCTAssertTrue(playlist.contains("http://example.com/hls/segment2.ts"))
    }
    
    func testPlaylistWithoutBaseURL() throws {
        let segments = [
            TSSegment(id: "1", path: "segment1.ts", duration: 6.0, startTime: 0.0)
        ]
        
        let playlist = try generator.generateMediaPlaylist(
            segments: segments,
            targetDuration: Int(configuration.targetSegmentDuration),
            baseURL: nil
        )
        
        // Verify segment URL doesn't include base URL
        XCTAssertTrue(playlist.contains("segment1.ts"))
        XCTAssertFalse(playlist.contains("http://example.com/hls/segment1.ts"))
    }
}
#else
#error("PlaylistGeneratorTests is only available on macOS 14.0 or later")
#endif 