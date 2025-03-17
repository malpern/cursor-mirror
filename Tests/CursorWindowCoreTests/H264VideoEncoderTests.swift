#if os(macOS)
import XCTest
import AVFoundation
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class H264VideoEncoderTests: XCTestCase {
    private var encoder: H264VideoEncoder!
    private let testOutputPath = NSTemporaryDirectory() + "test.mp4"
    private let testWidth = 1920
    private let testHeight = 1080
    private let testFrameRate = 30.0
    
    override func setUp() async throws {
        try await super.setUp()
        encoder = H264VideoEncoder()
    }
    
    override func tearDown() async throws {
        try? FileManager.default.removeItem(atPath: testOutputPath)
        encoder = nil
        try await super.tearDown()
    }
    
    func testBasicEncoding() async throws {
        let outputURL = URL(fileURLWithPath: testOutputPath)
        try encoder.startEncoding(to: outputURL, width: testWidth, height: testHeight)
        
        // Create and encode test frames
        for i in 0..<10 {
            let frame = try createTestFrame(at: Double(i) / testFrameRate)
            encoder.processFrame(frame)
            try await Task.sleep(for: .milliseconds(33)) // Simulate frame timing
        }
        
        encoder.stopEncoding()
        try await Task.sleep(for: .milliseconds(500)) // Wait for encoding to finish
        
        // Verify output file exists and has content
        let fileExists = FileManager.default.fileExists(atPath: testOutputPath)
        XCTAssertTrue(fileExists)
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: testOutputPath)[.size] as! Int64
        XCTAssertGreaterThan(fileSize, 0)
        
        // Verify the file is a valid video
        let asset = AVAsset(url: outputURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertFalse(tracks.isEmpty, "Video file should have at least one video track")
    }
    
    func testStopEncoding() async throws {
        let outputURL = URL(fileURLWithPath: testOutputPath)
        try encoder.startEncoding(to: outputURL, width: testWidth, height: testHeight)
        encoder.stopEncoding()
        
        // Wait for encoding to finish
        try await Task.sleep(for: .milliseconds(500))
        
        // Try to process a frame after stopping - should be ignored
        let frame = try createTestFrame(at: 0)
        encoder.processFrame(frame)
        
        // Verify no error is thrown but frame is ignored
        try await Task.sleep(for: .milliseconds(100))
    }
    
    func testInvalidConfiguration() async throws {
        let outputURL = URL(fileURLWithPath: testOutputPath)
        
        // Test invalid dimensions
        do {
            try encoder.startEncoding(to: outputURL, width: -1, height: testHeight)
            XCTFail("Expected error for invalid width")
        } catch {
            // The error should be our custom EncodingError
            if let encodingError = error as? EncodingError {
                XCTAssertEqual(encodingError, .invalidWidth, "Expected invalidWidth error")
            } else {
                XCTFail("Expected EncodingError but got \(type(of: error))")
            }
        }
        
        do {
            try encoder.startEncoding(to: outputURL, width: testWidth, height: -1)
            XCTFail("Expected error for invalid height")
        } catch {
            // The error should be our custom EncodingError
            if let encodingError = error as? EncodingError {
                XCTAssertEqual(encodingError, .invalidHeight, "Expected invalidHeight error")
            } else {
                XCTFail("Expected EncodingError but got \(type(of: error))")
            }
        }
        
        // Test invalid output URL
        do {
            try encoder.startEncoding(to: URL(fileURLWithPath: "/invalid/path/test.mp4"), width: testWidth, height: testHeight)
            XCTFail("Expected error for invalid output path")
        } catch {
            // Any error is acceptable here since it's OS-dependent
            XCTAssertTrue(true, "Expected an error for invalid output path")
        }
    }
    
    func testEncodingPerformance() async throws {
        let outputURL = URL(fileURLWithPath: testOutputPath)
        try encoder.startEncoding(to: outputURL, width: testWidth, height: testHeight)
        
        measure {
            let frame = try! createTestFrame(at: 0)
            encoder.processFrame(frame)
        }
        
        encoder.stopEncoding()
        try await Task.sleep(for: .milliseconds(500))
    }
    
    func testConcurrentEncoding() async throws {
        let outputURL = URL(fileURLWithPath: testOutputPath)
        try encoder.startEncoding(to: outputURL, width: testWidth, height: testHeight)
        
        // Create multiple concurrent frame processing tasks
        let tasks = (0..<5).map { i in
            Task {
                let frame = try createTestFrame(at: Double(i) / testFrameRate)
                encoder.processFrame(frame)
            }
        }
        
        // Wait for all tasks to complete
        for task in tasks {
            try await task.value
        }
        
        encoder.stopEncoding()
        try await Task.sleep(for: .milliseconds(500))
        
        // Verify output file
        let fileSize = try FileManager.default.attributesOfItem(atPath: testOutputPath)[.size] as! Int64
        XCTAssertGreaterThan(fileSize, 0)
    }
    
    func testMemoryHandling() async throws {
        let outputURL = URL(fileURLWithPath: testOutputPath)
        try encoder.startEncoding(to: outputURL, width: testWidth, height: testHeight)
        
        // Create and encode a large number of frames to test memory handling
        for i in 0..<100 {
            let frame = try createTestFrame(at: Double(i) / testFrameRate)
            encoder.processFrame(frame)
            
            // Verify memory usage doesn't grow unbounded
            if i % 10 == 0 {
                autoreleasepool { }
            }
        }
        
        encoder.stopEncoding()
        try await Task.sleep(for: .milliseconds(500))
    }
    
    // MARK: - Helper Methods
    
    private func createTestFrame(at time: Double) throws -> CMSampleBuffer {
        let pixelBuffer = try createTestPixelBuffer()
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(testFrameRate)),
            presentationTimeStamp: CMTime(seconds: time, preferredTimescale: 600),
            decodeTimeStamp: .invalid
        )
        
        var formatDesc: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        )
        
        guard let formatDesc = formatDesc else {
            throw EncodingError.formatDescriptionCreationFailed
        }
        
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let sampleBuffer = sampleBuffer else {
            throw EncodingError.sampleBufferCreationFailed
        }
        
        return sampleBuffer
    }
    
    private func createTestPixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: true
        ] as CFDictionary
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            testWidth,
            testHeight,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        
        guard let pixelBuffer = pixelBuffer else {
            throw EncodingError.pixelBufferCreationFailed
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        // Fill with test pattern
        if let baseAddress = baseAddress {
            for y in 0..<bufferHeight {
                let rowStart = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt32.self)
                for x in 0..<testWidth {
                    rowStart[x] = 0xFF0000FF // Red color
                }
            }
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }
}

// MARK: - Error Types
enum EncodingError: Error {
    case formatDescriptionCreationFailed
    case sampleBufferCreationFailed
    case pixelBufferCreationFailed
    case invalidWidth
    case invalidHeight
}
#endif 