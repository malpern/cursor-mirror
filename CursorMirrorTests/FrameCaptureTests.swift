import XCTest
import ScreenCaptureKit
@testable import cursor_window

@MainActor
final class FrameCaptureTests: XCTestCase {
    var captureManager: FrameCaptureManager!
    var frameProcessor: MockFrameProcessor!
    var displayConfig: DisplayConfiguration!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up display configuration
        displayConfig = DisplayConfiguration()
        try await displayConfig.updateDisplays()
        
        guard let display = displayConfig.displays.first else {
            XCTFail("No display available for testing")
            return
        }
        
        // Create a content filter
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Create a mock frame processor
        frameProcessor = MockFrameProcessor()
        
        // Create the frame capture manager
        captureManager = FrameCaptureManager(contentFilter: filter, frameProcessor: frameProcessor, frameRate: 30)
    }
    
    override func tearDown() async throws {
        captureManager.stopCapture()
        captureManager = nil
        frameProcessor = nil
        displayConfig = nil
        try await super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(captureManager.isCapturing)
        XCTAssertNil(captureManager.error)
        XCTAssertEqual(captureManager.frameRate, 30)
    }
    
    func testFrameRateChange() {
        // Change the frame rate
        captureManager.frameRate = 60
        
        // Verify the frame rate was updated
        XCTAssertEqual(captureManager.frameRate, 60)
    }
    
    func testStartCapture() async throws {
        // Start capture
        try await captureManager.startCapture()
        
        // Verify capture started
        XCTAssertTrue(captureManager.isCapturing)
        XCTAssertNil(captureManager.error)
        
        // Wait a short time to allow frames to be captured
        try await Task.sleep(for: .seconds(1))
        
        // Verify frames were processed
        XCTAssertGreaterThan(frameProcessor.processedFrameCount, 0)
    }
    
    func testStopCapture() async throws {
        // Start capture
        try await captureManager.startCapture()
        
        // Verify capture started
        XCTAssertTrue(captureManager.isCapturing)
        
        // Stop capture
        captureManager.stopCapture()
        
        // Wait for the stop to complete
        try await Task.sleep(for: .seconds(0.5))
        
        // Verify capture stopped
        XCTAssertFalse(captureManager.isCapturing)
    }
    
    func testUpdateContentFilter() async throws {
        // Start capture
        try await captureManager.startCapture()
        
        // Verify capture started
        XCTAssertTrue(captureManager.isCapturing)
        
        // Get a new filter
        guard let display = displayConfig.displays.first else {
            XCTFail("No display available for testing")
            return
        }
        
        let newFilter = SCContentFilter(display: display, excludingWindows: [])
        
        // Update the filter and await the completion
        try await captureManager.updateContentFilter(newFilter).value
        
        // Verify the filter was updated
        XCTAssertEqual(captureManager.contentFilter, newFilter)
        
        // Verify capture is active again after the update
        XCTAssertTrue(captureManager.isCapturing, "Capture should be active again after filter update")
        XCTAssertNil(captureManager.error, "There should be no errors after filter update")
    }
    
    func testSetFrameProcessor() async throws {
        // Start capture
        try await captureManager.startCapture()
        
        // Create a new frame processor
        let newProcessor = MockFrameProcessor()
        
        // Set the new processor
        captureManager.setFrameProcessor(newProcessor)
        
        // Wait for frames to be processed
        try await Task.sleep(for: .seconds(1))
        
        // Verify the new processor received frames
        XCTAssertGreaterThan(newProcessor.processedFrameCount, 0)
        
        // Verify the old processor stopped receiving frames
        let oldCount = frameProcessor.processedFrameCount
        
        // Wait a bit more
        try await Task.sleep(for: .seconds(1))
        
        // The old processor's count should not have increased
        XCTAssertEqual(frameProcessor.processedFrameCount, oldCount)
    }
}

// Mock frame processor for testing
class MockFrameProcessor: NSObject, FrameProcessor {
    var processedFrameCount = 0
    var lastProcessedFrame: CMSampleBuffer?
    var error: Error?
    
    func processFrame(_ frame: CMSampleBuffer) {
        processedFrameCount += 1
        lastProcessedFrame = frame
    }
    
    func handleError(_ error: Error) {
        self.error = error
    }
} 