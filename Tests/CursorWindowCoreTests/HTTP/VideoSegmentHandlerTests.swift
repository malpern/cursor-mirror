import XCTest
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class VideoSegmentHandlerTests: XCTestCase {
    private var handler: VideoSegmentHandler!
    private var mockSegmentWriter: MockTSSegmentWriter!
    private var tempDirectory: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for segments
        let fileManager = FileManager.default
        tempDirectory = NSTemporaryDirectory().appending("test_segments_\(UUID().uuidString)")
        try fileManager.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        
        // Create test data file
        let testDataPath = (tempDirectory as NSString).appendingPathComponent("segment_0.ts")
        let testData = "Test segment data".data(using: .utf8)!
        try testData.write(to: URL(fileURLWithPath: testDataPath))
        
        // Set up mock writer and handler
        mockSegmentWriter = MockTSSegmentWriter()
        let config = VideoSegmentConfig(
            targetSegmentDuration: 2.0,
            maxSegments: 3,
            segmentDirectory: tempDirectory
        )
        handler = VideoSegmentHandler(config: config, segmentWriter: mockSegmentWriter)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(atPath: tempDirectory)
        }
        
        handler = nil
        mockSegmentWriter = nil
        tempDirectory = nil
    }
    
    func testProcessVideoData() async throws {
        // Prepare test data
        let testData = "Test video data".data(using: .utf8)!
        let presentationTime = 0.0
        let quality = "high"
        
        // Configure mock writer
        await mockSegmentWriter.setCurrentSegment(TSSegment(
            id: "test_0",
            path: "segment_0.ts",
            duration: 2.0,
            startTime: 0.0
        ))
        
        // Process video data
        try await handler.processVideoData(testData, presentationTime: presentationTime, quality: quality)
        
        // Verify segment was written
        let writtenData = await mockSegmentWriter.writtenData
        let writtenPresentationTime = await mockSegmentWriter.writtenPresentationTime
        XCTAssertEqual(writtenData, testData)
        XCTAssertEqual(writtenPresentationTime, presentationTime)
        
        // Verify new segment was started
        let newSegmentStarted = await mockSegmentWriter.newSegmentStarted
        XCTAssertTrue(newSegmentStarted)
        
        // Verify segment was added to active segments
        let segments = await handler.getSegments(for: quality)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.path, "segment_0.ts")
    }
    
    func testSegmentCleanup() async throws {
        let quality = "high"
        
        // Add multiple segments
        for i in 0..<5 {
            await mockSegmentWriter.setCurrentSegment(TSSegment(
                id: "test_\(i)",
                path: "segment_\(i).ts",
                duration: 2.0,
                startTime: Double(i) * 2.0
            ))
            
            try await handler.processVideoData(
                "Test data \(i)".data(using: .utf8)!,
                presentationTime: Double(i) * 2.0,
                quality: quality
            )
        }
        
        // Verify only the configured maximum number of segments are kept
        let segments = await handler.getSegments(for: quality)
        XCTAssertEqual(segments.count, 3) // maxSegments from config
        XCTAssertEqual(segments.first?.path, "segment_2.ts") // Oldest remaining segment
        XCTAssertEqual(segments.last?.path, "segment_4.ts") // Newest segment
    }
    
    func testGetSegmentData() async throws {
        let quality = "high"
        let filename = "segment_0.ts"
        
        // Add a test segment
        await mockSegmentWriter.setCurrentSegment(TSSegment(
            id: "test_0",
            path: filename,
            duration: 2.0,
            startTime: 0.0
        ))
        
        try await handler.processVideoData(
            "Test data".data(using: .utf8)!,
            presentationTime: 0.0,
            quality: quality
        )
        
        // Get segment data
        let (data, headers) = try await handler.getSegmentData(quality: quality, filename: filename)
        
        // Verify data and headers
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(headers["Content-Type"], "video/mp2t")
        XCTAssertEqual(headers["Cache-Control"], "no-cache")
        XCTAssertEqual(headers["Access-Control-Allow-Origin"], "*")
        XCTAssertEqual(headers["Content-Length"], "\(data.count)")
    }
    
    func testGetSegmentDataNotFound() async throws {
        let quality = "high"
        let filename = "nonexistent.ts"
        
        do {
            _ = try await handler.getSegmentData(quality: quality, filename: filename)
            XCTFail("Expected error for nonexistent segment")
        } catch let error as HLSError {
            XCTAssertEqual(error.errorDescription, "File operation failed: Segment not found: nonexistent.ts")
        }
    }
}

// MARK: - Mock TSSegmentWriter
@available(macOS 14.0, *)
private actor MockTSSegmentWriter: TSSegmentWriterProtocol {
    private(set) var currentSegment: TSSegment?
    private(set) var writtenData: Data?
    private(set) var writtenPresentationTime: Double?
    private(set) var newSegmentStarted = false
    
    func setCurrentSegment(_ segment: TSSegment) {
        currentSegment = segment
    }
    
    func startNewSegment() async throws {
        newSegmentStarted = true
    }
    
    func writeEncodedData(_ data: Data, presentationTime: Double) async throws {
        writtenData = data
        writtenPresentationTime = presentationTime
    }
    
    func getCurrentSegment() async throws -> TSSegment? {
        return currentSegment
    }
    
    func getSegments() async throws -> [TSSegment] {
        return currentSegment.map { [$0] } ?? []
    }
    
    func removeSegment(_ segment: TSSegment) async throws {
        if currentSegment?.id == segment.id {
            currentSegment = nil
        }
    }
    
    func cleanup() async throws {
        currentSegment = nil
        writtenData = nil
        writtenPresentationTime = nil
        newSegmentStarted = false
    }
} 