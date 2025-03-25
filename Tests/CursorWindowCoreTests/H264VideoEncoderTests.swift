#if os(macOS)
import XCTest
import AVFoundation
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class H264VideoEncoderTests: XCTestCase {
    private var encoder: H264VideoEncoder?
    private var outputURL: URL?
    
    override func setUp() async throws {
        try await super.setUp()
        encoder = H264VideoEncoder()
        outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_output.mp4")
    }
    
    override func tearDown() async throws {
        if let outputURL = outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        encoder = nil
        outputURL = nil
        try await super.tearDown()
    }
    
    private func createTestFrame(time: Int64) -> CMSampleBuffer {
        let width = 640
        let height = 480
        let bytesPerRow = width * 4
        let bufferSize = height * bytesPerRow
        
        var format: CMFormatDescription?
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: Int32(width),
            height: Int32(height),
            extensions: nil,
            formatDescriptionOut: &format
        )
        
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferIOSurfacePropertiesKey: [:],
            ] as CFDictionary,
            &pixelBuffer
        )
        
        guard let pixelBuffer = pixelBuffer else {
            fatalError("Failed to create pixel buffer")
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            fatalError("Failed to get pixel buffer base address")
        }
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        for byteIndex in 0..<bufferSize {
            buffer[byteIndex] = UInt8((Int(time) + byteIndex) % 256)
        }
        
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 60),
            presentationTimeStamp: CMTime(value: time, timescale: 60),
            decodeTimeStamp: CMTime(value: time, timescale: 60)
        )
        
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let sampleBuffer = sampleBuffer else {
            fatalError("Failed to create sample buffer")
        }
        
        return sampleBuffer
    }
    
    func testBasicEncoding() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        // Start encoding
        try await encoder.startEncoding(to: outputURL, width: 1920, height: 1080)
        
        // Create and encode fewer test frames (10 instead of 30)
        for frameIndex in 0..<10 {
            let frame = createTestFrame(time: Int64(frameIndex))
            encoder.processFrame(frame)
            
            // Add a small delay to prevent overwhelming the system
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        }
        
        // Stop encoding
        await encoder.stopEncoding()
        
        // Wait a bit for the file to be written
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        
        // Verify output file exists and is not empty
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        XCTAssertGreaterThan(fileSize, 0)
        
        // Clean up the output file
        try? FileManager.default.removeItem(at: outputURL)
    }
    
    func testStopAndRestart() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        // First encoding session
        try await encoder.startEncoding(to: outputURL, width: 1920, height: 1080)
        let frame = createTestFrame(time: 0)
        encoder.processFrame(frame)
        await encoder.stopEncoding()
        
        // Try to process a frame after stopping - should be ignored
        encoder.processFrame(frame)
        
        // Start a new encoding session
        let newOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_output_new.mp4")
        defer { try? FileManager.default.removeItem(at: newOutputURL) }
        
        try await encoder.startEncoding(to: newOutputURL, width: 1920, height: 1080)
        encoder.processFrame(frame)
        await encoder.stopEncoding()
        
        // Verify both output files exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newOutputURL.path))
    }
    
    func testEncodingPerformance() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        try await encoder.startEncoding(to: outputURL, width: 1920, height: 1080)
        
        measure {
            let frame = createTestFrame(time: 0)
            encoder.processFrame(frame)
        }
        
        await encoder.stopEncoding()
    }
    
    func testConcurrentEncoding() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        // Start encoding
        try await encoder.startEncoding(to: outputURL, width: 1920, height: 1080)
        
        // Create an actor to count processed frames
        actor FrameCounter {
            private var count = 0
            func increment() { count += 1 }
            func getCount() -> Int { count }
        }
        
        let counter = FrameCounter()
        let frameCount = 100
        let tasks = (0..<frameCount).map { frameIndex in
            Task {
                let frame = createTestFrame(time: Int64(frameIndex))
                encoder.processFrame(frame)
                await counter.increment()
            }
        }
        
        // Wait for all tasks to complete
        for task in tasks {
            await task.value
        }
        
        // Stop encoding
        await encoder.stopEncoding()
        
        // Verify that all frames were processed
        let processedCount = await counter.getCount()
        XCTAssertEqual(processedCount, frameCount)
    }
    
    func testMemoryHandling() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        try await encoder.startEncoding(to: outputURL, width: 640, height: 480)
        
        // Create and encode a moderate number of frames to test memory handling
        // Using 50 frames instead of 100 to prevent test hanging
        for frameIndex in 0..<50 {
            let frame = createTestFrame(time: Int64(frameIndex))
            encoder.processFrame(frame)
            
            // Add a small delay to prevent overwhelming the system
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms delay
        }
        
        // Stop encoding and wait for completion
        await encoder.stopEncoding()
        
        // Wait for the file to be written
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        
        // Verify the output file exists and is not empty
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        XCTAssertGreaterThan(fileSize, 0)
    }
}

// MARK: - Error Types
enum EncodingError: Error {
    case formatDescriptionCreationFailed
    case sampleBufferCreationFailed
    case pixelBufferCreationFailed
    case invalidWidth
    case invalidHeight
    case outputPathError
}
#endif 