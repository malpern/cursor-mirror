#if os(macOS)
import XCTest
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class HLSSegmentWriterTests: XCTestCase {
    private let tempDirectory = NSTemporaryDirectory() + "hls_test_segments"
    private var writer: TSSegmentWriter!
    
    override func setUp() async throws {
        try await super.setUp()
        writer = try await TSSegmentWriter(segmentDirectory: tempDirectory)
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: tempDirectory)
        writer = nil
        try await super.tearDown()
    }
    
    func testStartNewSegment() async throws {
        try await writer.startNewSegment()
        
        let segment = try await writer.getCurrentSegment()
        XCTAssertNotNil(segment)
        XCTAssertTrue(FileManager.default.fileExists(atPath: segment!.path))
    }
    
    func testWriteEncodedData() async throws {
        try await writer.startNewSegment()
        
        let testData = "Test Data".data(using: .utf8)!
        try await writer.writeEncodedData(testData, presentationTime: 0.0)
        
        let segment = try await writer.getCurrentSegment()
        XCTAssertNotNil(segment)
        XCTAssertTrue(FileManager.default.fileExists(atPath: segment!.path))
    }
    
    func testWriteWithoutActiveSegment() async throws {
        let testData = "Test Data".data(using: .utf8)!
        
        do {
            try await writer.writeEncodedData(testData, presentationTime: 0.0)
            XCTFail("Expected error to be thrown")
        } catch let error as HLSError {
            XCTAssertEqual(error, .noActiveSegment)
        }
    }
    
    func testMultipleSegments() async throws {
        // First segment
        try await writer.startNewSegment()
        try await writer.writeEncodedData("Segment 1".data(using: .utf8)!, presentationTime: 0.0)
        
        // Second segment
        try await writer.startNewSegment()
        try await writer.writeEncodedData("Segment 2".data(using: .utf8)!, presentationTime: 1.0)
        
        // Get all segments
        let segments = try await writer.getSegments()
        XCTAssertEqual(segments.count, 2)
        
        // Verify both segments exist
        for segment in segments {
            XCTAssertTrue(FileManager.default.fileExists(atPath: segment.path))
        }
    }
    
    func testCleanup() async throws {
        // Create segments
        try await writer.startNewSegment()
        try await writer.writeEncodedData("Segment 1".data(using: .utf8)!, presentationTime: 0.0)
        try await writer.startNewSegment()
        try await writer.writeEncodedData("Segment 2".data(using: .utf8)!, presentationTime: 1.0)
        
        // Get segments before cleanup
        var segments = try await writer.getSegments()
        XCTAssertEqual(segments.count, 2)
        
        // Cleanup
        try await writer.cleanup()
        
        // Verify segments are removed
        segments = try await writer.getSegments()
        XCTAssertEqual(segments.count, 0)
        
        // Verify files are deleted
        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDirectory)
        XCTAssertEqual(contents.count, 0)
    }
    
    func testRemoveSegment() async throws {
        try await writer.startNewSegment()
        try await writer.writeEncodedData("Test Data".data(using: .utf8)!, presentationTime: 0.0)
        
        let segments = try await writer.getSegments()
        XCTAssertEqual(segments.count, 1)
        
        let segment = segments[0]
        try await writer.removeSegment(segment)
        
        let remainingSegments = try await writer.getSegments()
        XCTAssertEqual(remainingSegments.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: segment.path))
    }
}
#else
#error("HLSSegmentWriterTests is only available on macOS 14.0 or later")
#endif 