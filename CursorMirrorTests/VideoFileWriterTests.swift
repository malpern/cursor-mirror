import XCTest
import AVFoundation
import CoreMedia
@testable import cursor_window

final class VideoFileWriterTests: XCTestCase {
    var tempURL: URL!
    var writer: VideoFileWriter!
    
    override func setUp() async throws {
        writer = VideoFileWriter()
        
        // Create a temporary URL for the test video file
        let tempDir = FileManager.default.temporaryDirectory
        tempURL = tempDir.appendingPathComponent("test_video_\(UUID().uuidString).mp4")
    }
    
    override func tearDown() async throws {
        // Clean up any test files
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testCreateFile() throws {
        // When creating a file
        try writer.createFile(at: tempURL, width: 640, height: 480, frameRate: 30)
        
        // Then the file should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
    }
    
    func testAppendEncodedData() throws {
        // Given a created file
        try writer.createFile(at: tempURL, width: 640, height: 480, frameRate: 30)
        
        // When appending encoded data
        let testData = createTestData(size: 1024)
        let presentationTime = CMTime(value: 0, timescale: 30)
        
        // Then it should not throw an error
        XCTAssertNoThrow(try writer.appendEncodedData(testData, presentationTime: presentationTime))
    }
    
    func testAppendMultipleFrames() throws {
        // Given a created file
        try writer.createFile(at: tempURL, width: 640, height: 480, frameRate: 30)
        
        // When appending multiple frames
        let testData = createTestData(size: 1024)
        
        for i in 0..<10 {
            let presentationTime = CMTime(value: CMTimeValue(i), timescale: 30)
            try writer.appendEncodedData(testData, presentationTime: presentationTime)
        }
        
        // Then finish writing should not throw
        XCTAssertNoThrow(try await writer.finishWriting())
        
        // And the file should exist with a size greater than 0
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let fileSize = attributes[.size] as! NSNumber
        XCTAssertGreaterThan(fileSize.intValue, 0)
    }
    
    func testCancelWriting() throws {
        // Given a created file
        try writer.createFile(at: tempURL, width: 640, height: 480, frameRate: 30)
        
        // When appending some data
        let testData = createTestData(size: 1024)
        let presentationTime = CMTime(value: 0, timescale: 30)
        try writer.appendEncodedData(testData, presentationTime: presentationTime)
        
        // And then canceling writing
        writer.cancelWriting()
        
        // Then the file should not exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path))
    }
    
    func testFinishWriting() async throws {
        // Given a created file with some data
        try writer.createFile(at: tempURL, width: 640, height: 480, frameRate: 30)
        
        let testData = createTestData(size: 1024)
        for i in 0..<5 {
            let presentationTime = CMTime(value: CMTimeValue(i), timescale: 30)
            try writer.appendEncodedData(testData, presentationTime: presentationTime)
        }
        
        // When finishing writing
        try await writer.finishWriting()
        
        // Then the file should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        // And it should be a valid video file
        let asset = AVAsset(url: tempURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertFalse(tracks.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func createTestData(size: Int) -> Data {
        // Create a simple H.264 NAL unit
        // This is a very simplified version and won't create valid H.264 data,
        // but it's sufficient for testing the file writer's ability to handle data
        
        var data = Data(capacity: size)
        
        // Start code
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        
        // NAL header (IDR frame)
        data.append(0x65)
        
        // Fill the rest with random data
        for _ in 0..<(size - 5) {
            data.append(UInt8.random(in: 0...255))
        }
        
        return data
    }
} 