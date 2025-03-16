import XCTest
@testable import CursorWindowCore
import ScreenCaptureKit

final class ScreenCaptureManagerTests: XCTestCase {
    var manager: ScreenCaptureManager!
    
    override func setUp() async throws {
        manager = ScreenCaptureManager()
    }
    
    override func tearDown() async throws {
        manager = nil
    }
    
    func testInitialPermissionStatus() async throws {
        let status = await manager.permissionStatus
        XCTAssertNotNil(status, "Permission status should not be nil")
    }
    
    func testPermissionRequest() async throws {
        // This test requires user interaction, so we'll just verify the method exists
        // and returns without throwing
        try await manager.requestPermission()
    }
    
    func testStartCapture() async throws {
        let expectation = XCTestExpectation(description: "Capture started")
        
        let processor = MockFrameProcessor()
        try await manager.startCapture(frameProcessor: processor)
        
        // Wait for the first frame to be processed
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                continuation.resume(returning: processor.processedFrameCount > 0)
            }
        }
        
        XCTAssertTrue(result, "Should have processed at least one frame")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2)
    }
}

// MARK: - Mock Objects
private class MockFrameProcessor: BasicFrameProcessorProtocol {
    var processedFrameCount = 0
    
    func processFrame(_ frame: CMSampleBuffer) {
        processedFrameCount += 1
    }
} 