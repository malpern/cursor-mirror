#if os(macOS)
import XCTest
import AVFoundation
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class HLSManagerTests: XCTestCase {
    var manager: HLSManager!
    var tempDirectory: String!
    var configuration: HLSConfiguration!
    
    override func setUp() async throws {
        tempDirectory = NSTemporaryDirectory().appending("HLSManagerTests")
        configuration = HLSConfiguration(
            targetSegmentDuration: 6.0,
            playlistLength: 5,
            segmentDirectory: tempDirectory,
            baseURL: "http://localhost:8080"
        )
        manager = try await HLSManager(configuration: configuration)
    }
    
    override func tearDown() async throws {
        if let manager = manager {
            try? await manager.stopStreaming()
        }
        manager = nil
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(atPath: tempDirectory)
        }
        tempDirectory = nil
    }
    
    func testStartStreaming() async throws {
        try await manager.startStreaming()
        let playlist = try await manager.getCurrentPlaylist()
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory))
    }
    
    func testStopStreaming() async throws {
        try await manager.startStreaming()
        try await manager.stopStreaming()
        
        let segmentDirectory = (tempDirectory as NSString).appendingPathComponent("segments")
        XCTAssertFalse(FileManager.default.fileExists(atPath: segmentDirectory))
    }
    
    func testProcessEncodedData() async throws {
        try await manager.startStreaming()
        
        let testData = "Test Data".data(using: .utf8)!
        let sampleTime = CMTime(seconds: 0, preferredTimescale: 1)
        try await manager.processEncodedData(testData, presentationTime: sampleTime)
        
        let playlist = try await manager.getCurrentPlaylist()
        XCTAssertTrue(playlist.contains("#EXTM3U"))
        XCTAssertTrue(playlist.contains(".ts"))
    }
    
    func testSegmentRotation() async throws {
        try await manager.startStreaming()
        
        // Create more segments than the playlist length
        for i in 0..<(configuration.playlistLength + 2) {
            let testData = "Test Data \(i)".data(using: .utf8)!
            let sampleTime = CMTime(seconds: Double(i * 6), preferredTimescale: 1)
            try await manager.processEncodedData(testData, presentationTime: sampleTime)
            
            // Wait a bit to ensure segment duration is met
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        let playlist = try await manager.getCurrentPlaylist()
        let segmentCount = playlist.components(separatedBy: ".ts").count - 1
        XCTAssertEqual(segmentCount, configuration.playlistLength)
    }
    
    func testCleanupOldSegments() async throws {
        try await manager.startStreaming()
        
        // Create segments
        for i in 0..<3 {
            let testData = "Test Data \(i)".data(using: .utf8)!
            let sampleTime = CMTime(seconds: Double(i * 6), preferredTimescale: 1)
            try await manager.processEncodedData(testData, presentationTime: sampleTime)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        try await manager.stopStreaming()
        
        // Verify segments directory is cleaned up
        let segmentDirectory = (tempDirectory as NSString).appendingPathComponent("segments")
        XCTAssertFalse(FileManager.default.fileExists(atPath: segmentDirectory))
    }
}
#endif 