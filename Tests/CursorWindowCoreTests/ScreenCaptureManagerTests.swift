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
        
        // Set permission to false for this test
        await MainActor.run {
            manager.isScreenCapturePermissionGranted = false
        }
        
        let processor = MockFrameProcessor()
        
        // Since permission is not granted, we expect this to fail with a permission error
        do {
            try await manager.startCapture(frameProcessor: processor)
            XCTFail("Expected startCapture to fail with permission error")
        } catch {
            XCTAssertEqual((error as NSError).domain, "com.cursor-window")
            XCTAssertEqual((error as NSError).code, 403)
            XCTAssertEqual((error as NSError).localizedDescription, "Screen recording permission is required to capture the screen.")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 2)
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