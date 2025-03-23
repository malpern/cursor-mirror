#if os(macOS)
import XCTest
import AVFoundation
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class BasicFrameProcessorTests: XCTestCase {
    var processor: BasicFrameProcessor!
    let testDimensions = CMVideoDimensions(width: 640, height: 480)
    
    override func setUp() async throws {
        processor = BasicFrameProcessor()
    }
    
    override func tearDown() async throws {
        processor = nil
    }
    
    func testDefaultConfiguration() {
        XCTAssertEqual(processor.configuration.targetFrameRate, 30)
        XCTAssertTrue(processor.configuration.collectStatistics)
        XCTAssertFalse(processor.configuration.enableImageProcessing)
    }
    
    func testCustomConfiguration() {
        let config = BasicFrameProcessor.Configuration(
            targetFrameRate: 60,
            collectStatistics: false,
            enableImageProcessing: true
        )
        processor = BasicFrameProcessor(configuration: config)
        
        XCTAssertEqual(processor.configuration.targetFrameRate, 60)
        XCTAssertFalse(processor.configuration.collectStatistics)
        XCTAssertTrue(processor.configuration.enableImageProcessing)
    }
    
    func testUpdateConfiguration() async {
        let newConfig = BasicFrameProcessor.Configuration(
            targetFrameRate: 60,
            collectStatistics: false,
            enableImageProcessing: true
        )
        
        processor.updateConfiguration(newConfig)
        // Allow time for async update
        try? await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(processor.configuration.targetFrameRate, 60)
        XCTAssertFalse(processor.configuration.collectStatistics)
        XCTAssertTrue(processor.configuration.enableImageProcessing)
    }
    
    func testStatisticsTracking() async throws {
        let expectation = XCTestExpectation(description: "Statistics updated")
        var updatedStats: BasicFrameProcessor.Statistics?
        
        processor.setStatisticsCallback { stats in
            updatedStats = stats
            expectation.fulfill()
        }
        
        let frame = try createTestFrame()
        processor.processFrame(frame)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(updatedStats)
        XCTAssertEqual(updatedStats?.processedFrameCount, 1)
        XCTAssertGreaterThan(updatedStats?.averageProcessingTime ?? 0, 0)
    }
    
    func testStatisticsReset() async throws {
        let frame = try createTestFrame()
        processor.processFrame(frame)
        
        // Allow time for processing
        try await Task.sleep(for: .milliseconds(100))
        
        // Get initial statistics
        let initialStats = await processor.getCurrentStatistics()
        XCTAssertGreaterThan(initialStats.processedFrameCount, 0)
        
        // Reset statistics
        await processor.resetStatistics()
        
        // Allow time for reset
        try await Task.sleep(for: .milliseconds(100))
        
        // Get final statistics
        let finalStats = await processor.getCurrentStatistics()
        XCTAssertEqual(finalStats.processedFrameCount, 0)
        XCTAssertEqual(finalStats.averageProcessingTime, 0)
        XCTAssertEqual(finalStats.droppedFrameCount, 0)
    }
    
    func testDroppedFrameDetection() async throws {
        let expectation = XCTestExpectation(description: "Dropped frames detected")
        
        let config = BasicFrameProcessor.Configuration(
            targetFrameRate: 30,
            collectStatistics: true,
            enableImageProcessing: false
        )
        processor = BasicFrameProcessor(configuration: config)
        
        processor.setStatisticsCallback { stats in
            if stats.droppedFrameCount > 0 {
                expectation.fulfill()
            }
        }
        
        let frame = try createTestFrame()
        processor.processFrame(frame)
        
        // Simulate a delay longer than expected frame interval (1/30 = ~33ms)
        // We'll wait 100ms to ensure it's detected as a dropped frame
        try await Task.sleep(for: .milliseconds(100))
        
        processor.processFrame(frame)
        
        // Wait for the statistics to be updated
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Verify that dropped frames were detected
        let stats = await processor.getCurrentStatistics()
        XCTAssertGreaterThan(stats.droppedFrameCount, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestFrame() throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(testDimensions.width),
            Int(testDimensions.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            throw XCTSkip("Failed to create pixel buffer")
        }
        
        var formatDescription: CMFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard formatStatus == noErr, let formatDescription = formatDescription else {
            throw XCTSkip("Failed to create format description")
        }
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: 0, timescale: 1),
            decodeTimeStamp: CMTime.invalid
        )
        
        let sampleStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard sampleStatus == noErr, let sampleBuffer = sampleBuffer else {
            throw XCTSkip("Failed to create sample buffer")
        }
        
        return sampleBuffer
    }
}
#endif 