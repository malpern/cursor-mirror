import XCTest
import AVFoundation
import CoreMedia
@testable import cursor_window

/// Mock video encoder for testing
class MockVideoEncoder: VideoEncoderProtocol {
    var startSessionCalled = false
    var encodeFrameCalled = false
    var endSessionCalled = false
    
    var shouldThrowOnStartSession = false
    var shouldThrowOnEncodeFrame = false
    
    var lastEncodedImage: NSImage?
    var lastPresentationTimeStamp: CMTime?
    
    func startSession(width: Int, height: Int, frameRate: Int) throws {
        startSessionCalled = true
        if shouldThrowOnStartSession {
            throw VideoEncodingError.sessionSetupFailed
        }
    }
    
    func encodeFrame(_ image: NSImage, presentationTimeStamp: CMTime) throws -> Data? {
        encodeFrameCalled = true
        lastEncodedImage = image
        lastPresentationTimeStamp = presentationTimeStamp
        
        if shouldThrowOnEncodeFrame {
            throw VideoEncodingError.encodingFailed
        }
        
        // Return some dummy data
        return "test_encoded_data".data(using: .utf8)
    }
    
    func endSession() {
        endSessionCalled = true
    }
    
    func reset() {
        startSessionCalled = false
        encodeFrameCalled = false
        endSessionCalled = false
        lastEncodedImage = nil
        lastPresentationTimeStamp = nil
    }
}

@MainActor
final class EncodingFrameProcessorTests: XCTestCase {
    var mockEncoder: MockVideoEncoder!
    var processor: EncodingFrameProcessor!
    
    override func setUp() async throws {
        mockEncoder = MockVideoEncoder()
        processor = EncodingFrameProcessor(encoder: mockEncoder, frameRate: 30)
    }
    
    override func tearDown() async throws {
        processor.stopEncoding()
        processor = nil
        mockEncoder = nil
    }
    
    func testInitialState() async throws {
        // When the processor is initialized
        // Then it should have nil for latestImage and error
        XCTAssertNil(processor.latestImage)
        XCTAssertNil(processor.error)
    }
    
    func testStartEncoding() async throws {
        // When starting encoding
        try processor.startEncoding(width: 640, height: 480)
        
        // Then it should call startSession on the encoder
        XCTAssertTrue(mockEncoder.startSessionCalled)
    }
    
    func testStartEncodingWithError() async throws {
        // Given an encoder that throws on startSession
        mockEncoder.shouldThrowOnStartSession = true
        
        // When starting encoding
        XCTAssertThrowsError(try processor.startEncoding(width: 640, height: 480))
        
        // Then it should call startSession on the encoder
        XCTAssertTrue(mockEncoder.startSessionCalled)
    }
    
    func testStopEncoding() async throws {
        // Given a started encoding session
        try processor.startEncoding(width: 640, height: 480)
        
        // When stopping encoding
        processor.stopEncoding()
        
        // Then it should call endSession on the encoder
        XCTAssertTrue(mockEncoder.endSessionCalled)
    }
    
    func testProcessFrame() async throws {
        // Given a started encoding session
        try processor.startEncoding(width: 640, height: 480)
        
        // And a sample buffer
        let sampleBuffer = createSampleBuffer(width: 640, height: 480)
        
        // When processing a frame
        processor.processFrame(sampleBuffer)
        
        // Then it should update the latest image
        XCTAssertNotNil(processor.latestImage)
        
        // And it should call encodeFrame on the encoder
        XCTAssertTrue(mockEncoder.encodeFrameCalled)
        XCTAssertNotNil(mockEncoder.lastEncodedImage)
        XCTAssertNotNil(mockEncoder.lastPresentationTimeStamp)
    }
    
    func testProcessFrameWithEncodingError() async throws {
        // Given a started encoding session
        try processor.startEncoding(width: 640, height: 480)
        
        // And an encoder that throws on encodeFrame
        mockEncoder.shouldThrowOnEncodeFrame = true
        
        // And a sample buffer
        let sampleBuffer = createSampleBuffer(width: 640, height: 480)
        
        // When processing a frame
        processor.processFrame(sampleBuffer)
        
        // Then it should update the latest image
        XCTAssertNotNil(processor.latestImage)
        
        // And it should call encodeFrame on the encoder
        XCTAssertTrue(mockEncoder.encodeFrameCalled)
        
        // And it should store the error
        XCTAssertNotNil(processor.error)
        XCTAssertEqual(processor.error as? VideoEncodingError, VideoEncodingError.encodingFailed)
    }
    
    func testEncodedFrameCallback() async throws {
        // Given a started encoding session
        try processor.startEncoding(width: 640, height: 480)
        
        // And a callback
        var callbackCalled = false
        var callbackData: Data?
        var callbackTime: CMTime?
        
        processor.setEncodedFrameCallback { data, time in
            callbackCalled = true
            callbackData = data
            callbackTime = time
        }
        
        // And a sample buffer
        let sampleBuffer = createSampleBuffer(width: 640, height: 480)
        
        // When processing a frame
        processor.processFrame(sampleBuffer)
        
        // Then the callback should be called
        XCTAssertTrue(callbackCalled)
        XCTAssertNotNil(callbackData)
        XCTAssertNotNil(callbackTime)
        XCTAssertEqual(callbackData, "test_encoded_data".data(using: .utf8))
    }
    
    func testHandleError() async throws {
        // When handling an error
        let testError = CaptureError.frameConversionFailed
        processor.handleError(testError)
        
        // Then it should store the error
        XCTAssertNotNil(processor.error)
        XCTAssertEqual(processor.error as? CaptureError, testError)
    }
    
    // MARK: - Helper Methods
    
    private func createSampleBuffer(width: Int, height: Int) -> CMSampleBuffer {
        // Create a CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard let pixelBuffer = pixelBuffer else {
            fatalError("Failed to create pixel buffer")
        }
        
        // Fill the pixel buffer with a color
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        context?.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        // Create a CMSampleBuffer from the CVPixelBuffer
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: 0, timescale: 30),
            decodeTimeStamp: CMTime.invalid
        )
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        return sampleBuffer!
    }
} 