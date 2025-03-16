import XCTest
import AVFoundation
@testable import CursorWindowCore

final class H264VideoEncoderTests: XCTestCase {
    var encoder: H264VideoEncoder!
    let testWidth = 393
    let testHeight = 852
    
    override func setUp() async throws {
        encoder = H264VideoEncoder()
    }
    
    override func tearDown() async throws {
        try? await encoder.stopEncoding()
        encoder = nil
    }
    
    func testStartEncoding() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.mp4")
        try await encoder.startEncoding(to: tempURL, width: testWidth, height: testHeight)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testProcessFrame() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.mp4")
        try await encoder.startEncoding(to: tempURL, width: testWidth, height: testHeight)
        
        // Create a test frame
        let frame = try createTestFrame()
        try await encoder.processFrame(frame)
        
        try await encoder.stopEncoding()
        
        // Verify the file exists and has content
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let fileSize = attributes[.size] as! Int64
        XCTAssertGreaterThan(fileSize, 0)
        
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testStopEncoding() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.mp4")
        try await encoder.startEncoding(to: tempURL, width: testWidth, height: testHeight)
        try await encoder.stopEncoding()
        
        // Try to process a frame after stopping - should throw
        let frame = try createTestFrame()
        await XCTAssertThrowsError(try await encoder.processFrame(frame))
        
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - Helper Methods
    
    private func createTestFrame() throws -> CMSampleBuffer {
        let pixelBuffer = try createTestPixelBuffer()
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard let formatDescription else {
            throw CursorWindowError.frameProcessingFailed("Failed to create format description")
        }
        
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let sampleBuffer else {
            throw CursorWindowError.frameProcessingFailed("Failed to create sample buffer")
        }
        
        return sampleBuffer
    }
    
    private func createTestPixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            testWidth,
            testHeight,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw CursorWindowError.frameProcessingFailed("Failed to create pixel buffer")
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        // Fill with a simple pattern
        if let baseAddress = baseAddress {
            for row in 0..<bufferHeight {
                let rowAddress = baseAddress.advanced(by: row * bytesPerRow)
                memset(rowAddress, UInt8((row * 255) / bufferHeight), bytesPerRow)
            }
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }
} 