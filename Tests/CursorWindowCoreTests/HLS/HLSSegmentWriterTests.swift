#if os(macOS)
import XCTest
import AVFoundation
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class HLSSegmentWriterTests: XCTestCase {
    var writer: TSSegmentWriter!
    var tempDirectory: String!
    
    override func setUp() async throws {
        tempDirectory = NSTemporaryDirectory().appending("HLSSegmentWriterTests")
        writer = try await TSSegmentWriter(segmentDirectory: tempDirectory)
    }
    
    override func tearDown() async throws {
        if let writer = writer {
            try? await writer.cleanup()
        }
        writer = nil
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(atPath: tempDirectory)
        }
        tempDirectory = nil
    }
    
    func testSegmentDirectoryCreation() throws {
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory))
    }
    
    func testStartNewSegment() async throws {
        let startTime = CMTime(seconds: 0, preferredTimescale: 1)
        let segment = try await writer.startNewSegment(startTime: startTime)
        
        XCTAssertEqual(segment.sequenceNumber, 0)
        XCTAssertEqual(segment.duration, 0.0)
        XCTAssertEqual(segment.filePath, "segment0.ts")
        XCTAssertEqual(segment.startTime, startTime)
        
        let segmentPath = (tempDirectory as NSString).appendingPathComponent(segment.filePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: segmentPath))
    }
    
    func testWriteEncodedData() async throws {
        let startTime = CMTime(seconds: 0, preferredTimescale: 1)
        _ = try await writer.startNewSegment(startTime: startTime)
        
        let testData = "Test Data".data(using: .utf8)!
        try await writer.writeEncodedData(testData)
        
        let segmentPath = (tempDirectory as NSString).appendingPathComponent("segment0.ts")
        let writtenData = try Data(contentsOf: URL(fileURLWithPath: segmentPath))
        
        XCTAssertEqual(writtenData, testData)
    }
    
    func testFinishCurrentSegment() async throws {
        let startTime = CMTime(seconds: 0, preferredTimescale: 1)
        _ = try await writer.startNewSegment(startTime: startTime)
        
        let testData = "Test Data".data(using: .utf8)!
        try await writer.writeEncodedData(testData)
        let segment = try await writer.finishCurrentSegment()
        
        XCTAssertGreaterThan(segment.duration, 0.0)
        XCTAssertEqual(segment.sequenceNumber, 0)
        XCTAssertEqual(segment.filePath, "segment0.ts")
        XCTAssertEqual(segment.startTime, startTime)
        
        // Verify we can start a new segment after finishing
        let newStartTime = CMTime(seconds: 6, preferredTimescale: 1)
        let newSegment = try await writer.startNewSegment(startTime: newStartTime)
        
        XCTAssertEqual(newSegment.sequenceNumber, 1)
        XCTAssertEqual(newSegment.filePath, "segment1.ts")
    }
    
    func testWriteWithoutActiveSegment() async throws {
        let testData = "Test Data".data(using: .utf8)!
        do {
            try await writer.writeEncodedData(testData)
            XCTFail("Expected error to be thrown")
        } catch let error as HLSError {
            XCTAssertEqual(error, .noActiveSegment)
        }
    }
    
    func testFinishWithoutActiveSegment() async throws {
        do {
            _ = try await writer.finishCurrentSegment()
            XCTFail("Expected error to be thrown")
        } catch let error as HLSError {
            XCTAssertEqual(error, .noActiveSegment)
        }
    }
    
    func testCleanup() async throws {
        let startTime = CMTime(seconds: 0, preferredTimescale: 1)
        _ = try await writer.startNewSegment(startTime: startTime)
        
        let testData = "Test Data".data(using: .utf8)!
        try await writer.writeEncodedData(testData)
        
        try await writer.cleanup()
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory))
    }
    
    func testMultipleSegments() async throws {
        // First segment
        let startTime1 = CMTime(seconds: 0, preferredTimescale: 1)
        let segment1 = try await writer.startNewSegment(startTime: startTime1)
        try await writer.writeEncodedData("Segment 1".data(using: .utf8)!)
        let finishedSegment1 = try await writer.finishCurrentSegment()
        
        // Second segment
        let startTime2 = CMTime(seconds: 6, preferredTimescale: 1)
        let segment2 = try await writer.startNewSegment(startTime: startTime2)
        try await writer.writeEncodedData("Segment 2".data(using: .utf8)!)
        let finishedSegment2 = try await writer.finishCurrentSegment()
        
        // Verify both segments exist
        let segment1Path = (tempDirectory as NSString).appendingPathComponent(segment1.filePath)
        let segment2Path = (tempDirectory as NSString).appendingPathComponent(segment2.filePath)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: segment1Path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: segment2Path))
        
        // Verify segment contents
        let segment1Data = try String(data: Data(contentsOf: URL(fileURLWithPath: segment1Path)), encoding: .utf8)
        let segment2Data = try String(data: Data(contentsOf: URL(fileURLWithPath: segment2Path)), encoding: .utf8)
        
        XCTAssertEqual(segment1Data, "Segment 1")
        XCTAssertEqual(segment2Data, "Segment 2")
        
        // Verify segment metadata
        XCTAssertGreaterThan(finishedSegment1.duration, 0.0)
        XCTAssertEqual(finishedSegment1.sequenceNumber, 0)
        XCTAssertEqual(finishedSegment1.startTime, startTime1)
        
        XCTAssertGreaterThan(finishedSegment2.duration, 0.0)
        XCTAssertEqual(finishedSegment2.sequenceNumber, 1)
        XCTAssertEqual(finishedSegment2.startTime, startTime2)
    }
}
#endif 