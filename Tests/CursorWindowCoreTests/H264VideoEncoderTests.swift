import XCTest
@testable import CursorWindowCore
import CoreMedia
import AVFoundation

@available(macOS 14.0, *)
final class H264VideoEncoderTests: XCTestCase {
    var encoder: H264VideoEncoder!
    let testWidth = 1920
    let testHeight = 1080
    
    override func setUp() {
        super.setUp()
        encoder = H264VideoEncoder()
    }
    
    override func tearDown() {
        encoder = nil
        super.tearDown()
    }
    
    func testBasicEncoding() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.mp4")
        // Remove any existing file
        try? FileManager.default.removeItem(at: tempURL)
        
        print("Starting encoding test to: \(tempURL.path)")
        try encoder.startEncoding(to: tempURL, width: testWidth, height: testHeight)
        
        // Process 10 frames with precise timing
        for i in 0..<10 {
            let frame = try createTestFrame(at: Double(i) / 30.0)
            print("Processing frame \(i) at time: \(Double(i) / 30.0)")
            encoder.processFrame(frame)
            // Use precise timing between frames
            try await Task.sleep(for: .milliseconds(33))
        }
        
        print("All frames processed, stopping encoder")
        encoder.stopEncoding()
        
        // Wait for encoding to finish and file to be written
        for attempt in 1...10 {
            try await Task.sleep(for: .milliseconds(500))
            if FileManager.default.fileExists(atPath: tempURL.path),
               let attributes = try? FileManager.default.attributesOfItem(atPath: tempURL.path),
               let fileSize = attributes[.size] as? NSNumber,
               fileSize.intValue > 0 {
                print("File created successfully after \(attempt * 500)ms with size: \(fileSize.intValue) bytes")
                break
            }
            if attempt == 10 {
                XCTFail("File not created after 5 seconds")
            }
        }
        
        // Verify the file exists and has content
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
        print("Final file size: \(fileSize)")
        XCTAssertGreaterThan(fileSize, 0)
        
        // Try to read the file with AVAsset to verify it's a valid video
        let asset = AVAsset(url: tempURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertFalse(tracks.isEmpty, "Video file should have at least one video track")
        
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    func testStopEncoding() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.mp4")
        try encoder.startEncoding(to: tempURL, width: testWidth, height: testHeight)
        encoder.stopEncoding()
        
        // Wait for encoding to finish
        try await Task.sleep(for: .seconds(1))
        
        // Try to process a frame after stopping - should be ignored
        let frame = try createTestFrame(at: 0)
        encoder.processFrame(frame)
        
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // Helper function to create a test frame
    private func createTestFrame(at time: Double) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                           testWidth,
                           testHeight,
                           kCVPixelFormatType_32BGRA,
                           nil,
                           &pixelBuffer)
        
        guard let pixelBuffer = pixelBuffer else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"])
        }
        
        // Lock the buffer and fill it with a test pattern
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
            let bufferSize = bytesPerRow * bufferHeight
            memset(baseAddress, Int32(time * 255), bufferSize)  // Fill with increasing values
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        // Create format description
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard let formatDescription = formatDescription else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create format description"])
        }
        
        // Create timing info
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(seconds: time, preferredTimescale: 600),
            decodeTimeStamp: .invalid
        )
        
        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let sampleBuffer = sampleBuffer else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create sample buffer"])
        }
        
        return sampleBuffer
    }
} 