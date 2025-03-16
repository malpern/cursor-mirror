import XCTest
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif
@testable import CursorWindowCore

final class ScreenCaptureManagerTests: XCTestCase {
    var manager: ScreenCaptureManager!
    
    override func setUp() async throws {
        manager = await ScreenCaptureManager()
    }
    
    override func tearDown() async throws {
        manager = nil
    }
    
    func testInitialPermissionStatus() async throws {
        let isGranted = await manager.isScreenCapturePermissionGranted
        XCTAssertNotNil(isGranted, "Permission status should not be nil")
    }
    
    func testStartCapture() async throws {
        let expectation = XCTestExpectation(description: "Capture started")
        
        let processor = MockFrameProcessor()
        try await manager.startCapture(frameProcessor: processor)
        
        // Wait for the first frame to be processed
        try await Task.sleep(for: .seconds(1))
        
        let count = processor.processedFrameCount
        XCTAssertTrue(count > 0, "Should have processed at least one frame")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2)
        
        try await manager.stopCapture()
    }
}

// MARK: - Mock Objects
private final class MockFrameProcessor: BasicFrameProcessorProtocol {
    private var _processedFrameCount = 0
    var processedFrameCount: Int { _processedFrameCount }
    
    nonisolated func processFrame(_ frame: CMSampleBuffer) {
        Task { @MainActor in
            _processedFrameCount += 1
        }
    }
} 