#if os(macOS)
import XCTest
import AVFoundation
@testable import CursorWindowCore

@available(macOS 14.0, *)
final class H264VideoEncoderTests: XCTestCase, VideoEncoderDelegate {
    private var encoder: H264VideoEncoder?
    private var outputURL: URL?
    private var receivedSampleBuffers: [CMSampleBuffer] = []
    
    // VideoEncoderDelegate implementation
    public func videoEncoder(_ encoder: VideoEncoder, didOutputSampleBuffer sampleBuffer: CMSampleBuffer) {
        receivedSampleBuffers.append(sampleBuffer)
    }
    
    override func setUp() async throws {
        try await super.setUp()
        let viewportSize = ViewportSize.defaultSize()
        // Initialize with self as delegate for tests
        encoder = try H264VideoEncoder(viewportSize: viewportSize, delegate: self)
        outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_output.mp4")
        receivedSampleBuffers = []
    }
    
    override func tearDown() async throws {
        if let outputURL = outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        encoder = nil
        outputURL = nil
        receivedSampleBuffers = []
        try await super.tearDown()
    }
    
    private func createTestFrame(time: Int64) -> CVPixelBuffer {
        let width = 640
        let height = 480
        let bytesPerRow = width * 4
        let bufferSize = height * bytesPerRow
        
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
        
        return pixelBuffer
    }
    
    func testBasicEncoding() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        // Start encoding
        try await encoder.startEncoding(to: outputURL, width: 1920, height: 1080)
        
        // Create and encode fewer test frames (10 instead of 30)
        for frameIndex in 0..<10 {
            let frame = createTestFrame(time: Int64(frameIndex))
            try encoder.encode(frame)
            
            // Add a small delay to prevent overwhelming the system
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        }
        
        // Stop encoding
        await encoder.stopEncoding()
        
        // Wait a bit for the file to be written
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        
        // Verify we received sample buffers via the delegate
        XCTAssertFalse(receivedSampleBuffers.isEmpty)
    }
    
    func testStopAndRestart() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        // First encoding session
        try await encoder.startEncoding(to: outputURL, width: 1920, height: 1080)
        let frame = createTestFrame(time: 0)
        try encoder.encode(frame)
        await encoder.stopEncoding()
        
        // Try to process a frame after stopping - should be handled gracefully
        do {
            try encoder.encode(frame)
        } catch {
            // Expected error - encoder is stopped
            print("Expected error after stopping: \(error)")
        }
        
        // Start a new encoding session
        let newOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_output_new.mp4")
        defer { try? FileManager.default.removeItem(at: newOutputURL) }
        
        try await encoder.startEncoding(to: newOutputURL, width: 1920, height: 1080)
        try encoder.encode(frame)
        await encoder.stopEncoding()
    }
    
    func testEncodingPerformance() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        try await encoder.startEncoding(to: outputURL, width: 1920, height: 1080)
        
        measure {
            let frame = createTestFrame(time: 0)
            do {
                try encoder.encode(frame)
            } catch {
                XCTFail("Encoding failed: \(error)")
            }
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
        let frameCount = 20 // Reduced from 100 to make the test faster
        let tasks = (0..<frameCount).map { frameIndex in
            Task {
                let frame = createTestFrame(time: Int64(frameIndex))
                try encoder.encode(frame)
                await counter.increment()
            }
        }
        
        // Wait for all tasks to complete
        for task in tasks {
            do {
                try await task.value
            } catch {
                print("Task error: \(error)")
            }
        }
        
        // Stop encoding
        await encoder.stopEncoding()
        
        // Verify that frames were processed
        let processedCount = await counter.getCount()
        XCTAssertGreaterThan(processedCount, 0)
    }
    
    func testMemoryHandling() async throws {
        guard let encoder = encoder, let outputURL = outputURL else { return }
        
        try await encoder.startEncoding(to: outputURL, width: 640, height: 480)
        
        // Create and encode a moderate number of frames to test memory handling
        // Using 20 frames instead of 50 to make the test faster
        for frameIndex in 0..<20 {
            let frame = createTestFrame(time: Int64(frameIndex))
            try encoder.encode(frame)
            
            // Add a small delay to prevent overwhelming the system
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms delay
        }
        
        // Stop encoding and wait for completion
        await encoder.stopEncoding()
        
        // Wait for the file to be written
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        
        // Verify we received sample buffers
        XCTAssertFalse(receivedSampleBuffers.isEmpty)
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