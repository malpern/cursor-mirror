import XCTest
import ScreenCaptureKit
@testable import CursorWindowCore

protocol FrameProcessor {
    func processFrame(_ frame: CMSampleBuffer)
}

class MockFrameProcessor: FrameProcessor {
    var processedFrameCount = 0
    
    func processFrame(_ frame: CMSampleBuffer) {
        processedFrameCount += 1
    }
}

@available(macOS 14.0, *)
class MockSCStream: SCStream {
    var streamOutput: SCStreamOutput?
    var addStreamOutputCalled = false
    var startCaptureCalled = false
    var stopCaptureCalled = false
    var mockError: Error?
    var filter: SCContentFilter
    var configuration: SCStreamConfiguration
    
    init(filter: SCContentFilter, configuration: SCStreamConfiguration, mockError: Error? = nil) {
        self.filter = filter
        self.configuration = configuration
        self.mockError = mockError
    }
    
    override func startCapture() async throws {
        if let error = mockError {
            throw error
        }
        startCaptureCalled = true
        try simulateFrameOutput(to: streamOutput!)
    }
    
    override func stopCapture() async throws {
        if let error = mockError {
            throw error
        }
        stopCaptureCalled = true
    }
    
    override func addStreamOutput(_ output: SCStreamOutput, type: SCStreamOutputType, sampleHandlerQueue: DispatchQueue?) throws {
        streamOutput = output
        addStreamOutputCalled = true
    }
    
    func simulateFrameOutput(to output: SCStreamOutput) throws {
        // Create a mock format description
        var formatDescription: CMFormatDescription?
        let dimensions = CMVideoDimensions(width: 1920, height: 1080)
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_H264,
            width: dimensions.width,
            height: dimensions.height,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )
        
        guard status == noErr, let formatDescription = formatDescription else {
            throw NSError(domain: "MockSCStream", code: Int(status))
        }
        
        // Create a mock block buffer
        var blockBuffer: CMBlockBuffer?
        let length = Int(1920 * 1080 * 4)  // RGBA data
        let status2 = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: length,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: length,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard status2 == noErr, let buffer = blockBuffer else {
            throw NSError(domain: "MockSCStream", code: Int(status2))
        }
        
        // Create timing info
        let timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: 0, timescale: 1),
            decodeTimeStamp: CMTime(value: 0, timescale: 1)
        )
        
        // Create a mock sample buffer
        var sampleBuffer: CMSampleBuffer?
        let status3 = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard status3 == noErr, let sampleBuffer = sampleBuffer else {
            throw NSError(domain: "MockSCStream", code: Int(status3))
        }
        
        output.stream(self, didOutputSampleBuffer: sampleBuffer, of: .screen)
    }
}

@available(macOS 14.0, *)
final class ScreenCaptureManagerTests: XCTestCase {
    var manager: ScreenCaptureManager!
    var mockStream: MockSCStream!
    var mockProcessor: MockFrameProcessor!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a minimal filter and configuration for testing
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            XCTFail("No display available for testing")
            return
        }
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        
        mockStream = MockSCStream(filter: filter, configuration: config)
        mockProcessor = MockFrameProcessor()
        manager = await ScreenCaptureManager()
        
        // Ensure UserDefaults is clean for each test
        UserDefaults.standard.removeObject(forKey: "com.cursor-window.permissionChecked")
        UserDefaults.standard.removeObject(forKey: "com.cursor-window.lastKnownPermissionStatus")
        
        #if DEBUG
        // Set permission to granted by default for tests and wait for it to take effect
        await manager.setPermissionStatusForTesting(true)
        await manager.injectMockStream(mockStream)
        await manager.checkPermission() // Ensure permission status is updated
        #endif
    }
    
    override func tearDown() async throws {
        #if DEBUG
        // Reset permission status and wait for it to take effect
        await manager.setPermissionStatusForTesting(false)
        await manager.checkPermission()
        #endif
        
        if let manager = manager {
            try await manager.stopCapture()
        }
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "com.cursor-window.permissionChecked")
        UserDefaults.standard.removeObject(forKey: "com.cursor-window.lastKnownPermissionStatus")
        
        manager = nil
        mockStream = nil
        mockProcessor = nil
        try await super.tearDown()
    }
    
    func testInitialPermissionStatus() async throws {
        #if DEBUG
        // Test starts with permission granted from setUp
        let status = await manager.isScreenCapturePermissionGranted
        XCTAssertTrue(status, "Permission should be granted after setup")
        
        // Test changing permission to denied
        await manager.setPermissionStatusForTesting(false)
        await manager.checkPermission() // Ensure change takes effect
        let newStatus = await manager.isScreenCapturePermissionGranted
        XCTAssertFalse(newStatus, "Permission should be denied after change")
        #endif
    }
    
    func testStartCapture() async throws {
        // Given
        let initialProcessor = await manager.getFrameProcessorForTesting()
        XCTAssertNil(initialProcessor, "Initial processor should be nil")
        
        // When
        try await manager.startCapture(frameProcessor: mockProcessor)
        
        // Then
        XCTAssertTrue(mockStream.startCaptureCalled, "Start capture should be called")
        XCTAssertTrue(mockStream.addStreamOutputCalled, "Add stream output should be called")
        
        let currentProcessor = await manager.getFrameProcessorForTesting()
        XCTAssertNotNil(currentProcessor, "Processor should be set after start")
        
        #if DEBUG
        let currentStream = await manager.getStreamForTesting()
        XCTAssertIdentical(currentStream, mockStream, "Current stream should be mock stream")
        #endif
    }
    
    func testStopCapture() async throws {
        // Given
        try await manager.startCapture(frameProcessor: mockProcessor)
        let initialProcessor = await manager.getFrameProcessorForTesting()
        XCTAssertNotNil(initialProcessor, "Processor should be set after start")
        
        // When
        try await manager.stopCapture()
        
        // Then
        XCTAssertTrue(mockStream.stopCaptureCalled, "Stop capture should be called")
        let currentProcessor = await manager.getFrameProcessorForTesting()
        XCTAssertNil(currentProcessor, "Processor should be nil after stop")
        
        #if DEBUG
        let currentStream = await manager.getStreamForTesting()
        XCTAssertNil(currentStream, "Stream should be nil after stop")
        #endif
    }
    
    func testStartCaptureWithoutPermission() async throws {
        // Given
        #if DEBUG
        await manager.setPermissionStatusForTesting(false)
        await manager.checkPermission() // Ensure change takes effect
        await manager.injectMockStream(nil) // Simulate no permission by removing mock stream
        #endif
        
        // When/Then
        do {
            try await manager.startCapture(frameProcessor: mockProcessor)
            XCTFail("Expected permission denied error")
        } catch ScreenCaptureError.permissionDenied {
            // Expected error
        }
    }
    
    func testStartCaptureWithError() async throws {
        // Given
        let mockError = NSError(domain: "TestError", code: -1, userInfo: nil)
        let errorStream = MockSCStream(filter: mockStream.filter, configuration: mockStream.configuration, mockError: mockError)
        
        #if DEBUG
        await manager.injectMockStream(errorStream)
        #endif
        
        // When/Then
        do {
            try await manager.startCapture(frameProcessor: mockProcessor)
            XCTFail("Expected error to be thrown")
        } catch ScreenCaptureError.captureError {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFrameProcessing() async throws {
        // Given
        try await manager.startCapture(frameProcessor: mockProcessor)
        
        // Wait for stream to start
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // When
        mockStream.simulateFrameOutput(to: mockStream.streamOutput!)
        
        // Then
        let processor = await manager.getFrameProcessorForTesting()
        XCTAssertNotNil(processor, "Processor should be set")
        
        // Wait for frame processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Verify frame was processed
        XCTAssertEqual(mockProcessor.processedFrameCount, 1, "Frame should be processed")
    }
    
    func testCleanupAfterCapture() async throws {
        // Given
        try await manager.startCapture(frameProcessor: mockProcessor)
        
        // Wait for stream to start
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let processor = await manager.getFrameProcessorForTesting()
        XCTAssertNotNil(processor, "Processor should be set")
        let stream = await manager.getStreamForTesting()
        XCTAssertNotNil(stream, "Stream should be set")
        
        // When
        try await manager.stopCapture()
        
        // Then
        let finalProcessor = await manager.getFrameProcessorForTesting()
        XCTAssertNil(finalProcessor, "Processor should be cleaned up")
        let finalStream = await manager.getStreamForTesting()
        XCTAssertNil(finalStream, "Stream should be cleaned up")
        XCTAssertTrue(mockStream.stopCaptureCalled, "Stop capture should be called")
    }
    
    func testConfigurationValidation() async throws {
        // Given
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            XCTFail("No display available for testing")
            return
        }
        
        // When - Create invalid configuration
        let invalidConfig = SCStreamConfiguration()
        invalidConfig.width = 0  // Invalid width
        invalidConfig.height = Int(display.height)
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let invalidStream = MockSCStream(filter: filter, configuration: invalidConfig, mockError: ScreenCaptureError.invalidConfiguration)
        
        #if DEBUG
        await manager.injectMockStream(invalidStream)
        #endif
        
        // Then
        do {
            try await manager.startCapture(frameProcessor: mockProcessor)
            XCTFail("Expected invalid configuration error")
        } catch ScreenCaptureError.invalidConfiguration {
            // Expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testMultipleStartStop() async throws {
        for _ in 1...3 {
            // Start capture
            try await manager.startCapture(frameProcessor: mockProcessor)
            
            // Wait for stream to start
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            let processor = await manager.getFrameProcessorForTesting()
            XCTAssertNotNil(processor, "Processor should be set")
            XCTAssertTrue(mockStream.startCaptureCalled, "Start capture should be called")
            
            // Stop capture
            try await manager.stopCapture()
            let finalProcessor = await manager.getFrameProcessorForTesting()
            XCTAssertNil(finalProcessor, "Processor should be cleaned up")
            XCTAssertTrue(mockStream.stopCaptureCalled, "Stop capture should be called")
            
            // Reset mock state for next iteration
            mockStream.startCaptureCalled = false
            mockStream.stopCaptureCalled = false
        }
    }
    
    func testFrameProcessorReceivesFrames() async throws {
        // Given
        let mockStream = MockSCStream(filter: .init(display: .main), configuration: .init())
        let mockProcessor = MockFrameProcessor()
        let manager = ScreenCaptureManager(frameProcessor: mockProcessor)
        
        // When
        try await manager.startCapture()
        try mockStream.simulateFrameOutput(to: mockStream.streamOutput!)
        
        // Then
        XCTAssertTrue(mockProcessor.processFrameCalled)
    }
}

// MARK: - Mock Objects
private final class MockBasicFrameProcessor: BasicFrameProcessorProtocol {
    private let lock = NSLock()
    private var _processedFrameCount = 0
    
    var processedFrameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _processedFrameCount
    }
    
    nonisolated func processFrame(_ frame: CMSampleBuffer) {
        lock.lock()
        defer { lock.unlock() }
        _processedFrameCount += 1
    }
}

final class MockViewportManager: ViewportManagerProtocol {
    var position: CGPoint = .zero
    static var viewportSize: CGSize = CGSize(width: 800, height: 600)
    var mockBounds: CGRect = .zero
    
    var bounds: CGRect {
        get { mockBounds }
        set { mockBounds = newValue }
    }
}