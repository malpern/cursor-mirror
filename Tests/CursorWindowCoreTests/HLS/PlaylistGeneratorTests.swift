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
            baseURL: "http://localhost:8080"
        )
    }
    
    override func tearDown() {
        generator = nil
        configuration = nil
        super.tearDown()
    }
    
    func testMasterPlaylistGeneration() throws {
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
        
        let playlist = generator.generateMasterPlaylist(variants: variants)
        
        // Verify playlist contains required tags
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        
        // Verify variant streams
        XCTAssertTrue(playlist.contains("BANDWIDTH=2000000"))
        XCTAssertTrue(playlist.contains("RESOLUTION=1920x1080"))
        XCTAssertTrue(playlist.contains("stream_high.m3u8"))
        
        XCTAssertTrue(playlist.contains("BANDWIDTH=1000000"))
        XCTAssertTrue(playlist.contains("RESOLUTION=1280x720"))
        XCTAssertTrue(playlist.contains("stream_medium.m3u8"))
    }
    
    func testMediaPlaylistGeneration() throws {
        let segments = [
            HLSSegment(
                duration: 6.0,
                sequenceNumber: 0,
                filePath: "segment0.ts",
                startTime: CMTime(seconds: 0, preferredTimescale: 1)
            ),
            HLSSegment(
                duration: 6.0,
                sequenceNumber: 1,
                filePath: "segment1.ts",
                startTime: CMTime(seconds: 6, preferredTimescale: 1)
            )
        ]
        
        let playlist = generator.generateMediaPlaylist(segments: segments, configuration: configuration)
        
        // Verify playlist contains required tags
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
        XCTAssertTrue(playlist.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        
        // Verify segments
        XCTAssertTrue(playlist.contains("#EXTINF:6.000,"))
        XCTAssertTrue(playlist.contains("http://localhost:8080/segment0.ts"))
        XCTAssertTrue(playlist.contains("http://localhost:8080/segment1.ts"))
    }
    
    func testEventPlaylistGeneration() throws {
        let segments = [
            HLSSegment(
                duration: 6.0,
                sequenceNumber: 0,
                filePath: "segment0.ts",
                startTime: CMTime(seconds: 0, preferredTimescale: 1)
            )
        ]
        
        let playlist = generator.generateEventPlaylist(segments: segments, configuration: configuration)
        
        // Verify playlist contains required tags
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
        XCTAssertTrue(playlist.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        XCTAssertTrue(playlist.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
        
        // Verify segments
        XCTAssertTrue(playlist.contains("#EXTINF:6.000,"))
        XCTAssertTrue(playlist.contains("http://localhost:8080/segment0.ts"))
    }
    
    func testVODPlaylistGeneration() throws {
        let segments = [
            HLSSegment(
                duration: 6.0,
                sequenceNumber: 0,
                filePath: "segment0.ts",
                startTime: CMTime(seconds: 0, preferredTimescale: 1)
            ),
            HLSSegment(
                duration: 6.0,
                sequenceNumber: 1,
                filePath: "segment1.ts",
                startTime: CMTime(seconds: 6, preferredTimescale: 1)
            )
        ]
        
        let playlist = generator.generateVODPlaylist(segments: segments, configuration: configuration)
        
        // Verify playlist contains required tags
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
        XCTAssertTrue(playlist.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        XCTAssertTrue(playlist.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        
        // Verify segments
        XCTAssertTrue(playlist.contains("#EXTINF:6.000,"))
        XCTAssertTrue(playlist.contains("http://localhost:8080/segment0.ts"))
        XCTAssertTrue(playlist.contains("http://localhost:8080/segment1.ts"))
        
        // Verify playlist end marker
        XCTAssertTrue(playlist.contains("#EXT-X-ENDLIST"))
    }
    
    func testEmptyBaseURL() throws {
        let configuration = HLSConfiguration(
            targetSegmentDuration: 6.0,
            playlistLength: 5,
            segmentDirectory: "/tmp/hls",
            baseURL: ""
        )
        
        let segments = [
            HLSSegment(
                duration: 6.0,
                sequenceNumber: 0,
                filePath: "segment0.ts",
                startTime: CMTime(seconds: 0, preferredTimescale: 1)
            )
        ]
        
        let playlist = generator.generateMediaPlaylist(segments: segments, configuration: configuration)
        
        // Verify segment URL doesn't include base URL
        XCTAssertTrue(playlist.contains("\nsegment0.ts\n"))
        XCTAssertFalse(playlist.contains("http://"))
    }
}
#endif 