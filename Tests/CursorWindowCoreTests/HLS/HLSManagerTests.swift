#if os(macOS)
import XCTest
import AVFoundation
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class HLSManagerTests: XCTestCase {
    var manager: HLSManager!
    let tempDirectory = NSTemporaryDirectory() + "hls_test"
    
    override func setUp() async throws {
        try await super.setUp()
        let configuration = HLSConfiguration(
            targetSegmentDuration: 6.0,
            playlistLength: 5,
            segmentDirectory: tempDirectory,
            baseURL: "http://example.com/hls"
        )
        manager = try await HLSManager(configuration: configuration)
    }
    
    override func tearDown() async throws {
        try? await manager.stopStreaming()
        try? FileManager.default.removeItem(atPath: tempDirectory)
        manager = nil
        try await super.tearDown()
    }
    
    func testStartStreaming() async throws {
        try await manager.startStreaming()
        
        let testData = "Test Data".data(using: .utf8)!
        try await manager.processEncodedData(testData, presentationTime: 0.0)
        
        let playlist = try await manager.getCurrentPlaylist()
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
    }
    
    func testStopStreaming() async throws {
        try await manager.startStreaming()
        try await manager.stopStreaming()
        
        do {
            let testData = "Test Data".data(using: .utf8)!
            try await manager.processEncodedData(testData, presentationTime: 0.0)
            XCTFail("Expected error to be thrown")
        } catch let error as HLSError {
            XCTAssertEqual(error, .streamingNotStarted)
        }
    }
    
    func testSegmentRotation() async throws {
        try await manager.startStreaming()
        
        // Create more segments than the playlist length
        for i in 0..<7 {
            let testData = "Test Data \(i)".data(using: .utf8)!
            try await manager.processEncodedData(testData, presentationTime: Double(i * 6))
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        // Clean up old segments
        try await manager.cleanupOldSegments()
        
        // Verify only the configured number of segments are kept
        let segments = try await manager.getActiveSegments()
        XCTAssertEqual(segments.count, 5)
        
        // Verify the oldest segments were removed
        let playlist = try await manager.getCurrentPlaylist()
        XCTAssertFalse(playlist.contains("Test Data 0"))
        XCTAssertFalse(playlist.contains("Test Data 1"))
    }
    
    func testVariantStreams() async throws {
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
        
        for variant in variants {
            await manager.addVariant(variant)
        }
        
        let masterPlaylist = try await manager.getMasterPlaylist()
        XCTAssertTrue(masterPlaylist.contains("#EXTM3U"))
        XCTAssertTrue(masterPlaylist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(masterPlaylist.contains("BANDWIDTH=2000000"))
        XCTAssertTrue(masterPlaylist.contains("RESOLUTION=1920x1080"))
        XCTAssertTrue(masterPlaylist.contains("stream_high.m3u8"))
        XCTAssertTrue(masterPlaylist.contains("BANDWIDTH=1000000"))
        XCTAssertTrue(masterPlaylist.contains("RESOLUTION=1280x720"))
        XCTAssertTrue(masterPlaylist.contains("stream_medium.m3u8"))
    }
    
    func testEventPlaylist() async throws {
        try await manager.startStreaming()
        
        let testData = "Test Data".data(using: .utf8)!
        try await manager.processEncodedData(testData, presentationTime: 0.0)
        
        let playlist = try await manager.getEventPlaylist()
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
        XCTAssertTrue(playlist.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
    }
    
    func testVODPlaylist() async throws {
        try await manager.startStreaming()
        
        let testData = "Test Data".data(using: .utf8)!
        try await manager.processEncodedData(testData, presentationTime: 0.0)
        
        let playlist = try await manager.getVODPlaylist()
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains("#EXT-X-VERSION:3"))
        XCTAssertTrue(playlist.contains("#EXT-X-TARGETDURATION:6"))
        XCTAssertTrue(playlist.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        XCTAssertTrue(playlist.contains("#EXT-X-ENDLIST"))
    }
}
#else
#error("HLSManagerTests is only available on macOS 14.0 or later")
#endif 