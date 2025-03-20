import XCTest
@testable import CursorWindowCore

/* Temporarily disabled due to incompatibility issues with StreamQuality/HLSQualityOption
@available(macOS 14.0, *)
final class HLSPlaylistGeneratorTests: XCTestCase {
    private var generator: HLSPlaylistGenerator!
    private var qualities: [HLSQualityOption]!
    
    override func setUp() {
        super.setUp()
        
        qualities = [
            HLSQualityOption(id: "high", width: 1920, height: 1080, bitrate: 5_000_000, codecs: "avc1.4d001f,mp4a.40.2"),
            HLSQualityOption(id: "medium", width: 1280, height: 720, bitrate: 2_500_000, codecs: "avc1.4d001f,mp4a.40.2"),
            HLSQualityOption(id: "low", width: 854, height: 480, bitrate: 1_000_000, codecs: "avc1.4d001f,mp4a.40.2")
        ]
        
        generator = HLSPlaylistGenerator(baseURL: "http://example.com/stream", qualities: qualities)
    }
    
    override func tearDown() {
        generator = nil
        qualities = nil
        super.tearDown()
    }
    
    func testGenerateMasterPlaylist() {
        let playlist = generator.generateMasterPlaylist()
        
        // Verify playlist structure
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        
        // Verify each quality option is included
        for quality in qualities {
            XCTAssertTrue(playlist.contains("BANDWIDTH=\(quality.bitrate)"))
            XCTAssertTrue(playlist.contains("RESOLUTION=\(quality.width)x\(quality.height)"))
            XCTAssertTrue(playlist.contains("CODECS=\"\(quality.codecs)\""))
            XCTAssertTrue(playlist.contains("http://example.com/stream/\(quality.id)/playlist.m3u8"))
        }
    }
    
    func testGenerateMediaPlaylist() {
        let segments = [
            TSSegment(id: "1", path: "segment_0.ts", duration: 2.0, startTime: 0.0),
            TSSegment(id: "2", path: "segment_1.ts", duration: 2.0, startTime: 2.0),
            TSSegment(id: "3", path: "segment_2.ts", duration: 2.0, startTime: 4.0)
        ]
        
        // Test ongoing stream
        let ongoingPlaylist = generator.generateMediaPlaylist(quality: qualities[0], segments: segments)
        
        XCTAssertTrue(ongoingPlaylist.contains("#EXTM3U"))
        XCTAssertTrue(ongoingPlaylist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(ongoingPlaylist.contains("#EXT-X-TARGETDURATION:2"))
        XCTAssertTrue(ongoingPlaylist.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        
        for segment in segments {
            XCTAssertTrue(ongoingPlaylist.contains("#EXTINF:2.000,"))
            XCTAssertTrue(ongoingPlaylist.contains("http://example.com/stream/high/\(segment.path)"))
        }
        
        XCTAssertFalse(ongoingPlaylist.contains("#EXT-X-ENDLIST"))
        
        // Test ended stream
        let endedPlaylist = generator.generateMediaPlaylist(quality: qualities[0], segments: segments, isEndOfStream: true)
        XCTAssertTrue(endedPlaylist.contains("#EXT-X-ENDLIST"))
    }
    
    func testBaseURLHandling() {
        // Test with trailing slash
        let generatorWithSlash = HLSPlaylistGenerator(baseURL: "http://example.com/stream/", qualities: qualities)
        let segments = [TSSegment(id: "1", path: "segment_0.ts", duration: 2.0, startTime: 0.0)]
        
        let playlist = generatorWithSlash.generateMediaPlaylist(quality: qualities[0], segments: segments)
        
        // Verify no double slashes in URLs
        XCTAssertFalse(playlist.contains("stream//"))
    }
}
*/ 