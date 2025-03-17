import XCTest
import Foundation
import NIO
@testable import CursorWindowCore
import XCTVapor

@available(macOS 14.0, *)
final class PerformanceTests: XCTestCase {
    private var app: Application!
    private var httpServer: HTTPServerManager!
    private var videoSegmentHandler: VideoSegmentHandler!
    private var tempDirectory: String!
    private var segmentWriter: TSSegmentWriter!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for segments
        let fileManager = FileManager.default
        tempDirectory = NSTemporaryDirectory().appending("perf_test_segments_\(UUID().uuidString)")
        try fileManager.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        
        // Set up segment writer and handler
        segmentWriter = try await TSSegmentWriter(segmentDirectory: tempDirectory)
        let config = VideoSegmentConfig(
            targetSegmentDuration: 2.0,
            maxSegments: 10,
            maxCachedSegments: 20,
            segmentDirectory: tempDirectory
        )
        videoSegmentHandler = VideoSegmentHandler(config: config, segmentWriter: segmentWriter)
        
        // Set up HTTP server
        let httpConfig = HTTPServerConfig(
            host: "localhost",
            port: 8989, // Use different port for tests
            enableTLS: false,
            authentication: .disabled,
            cors: .permissive,
            logging: .disabled, // Disable logging for performance tests
            rateLimit: .disabled, // Disable rate limiting for performance tests
            metrics: .minimal // Minimal metrics for testing
        )
        httpServer = HTTPServerManager(config: httpConfig)
        
        // Generate test segments
        try await generateTestSegments()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        // Stop HTTP server if running
        if await httpServer.isRunning {
            try await httpServer.stop()
        }
        
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(atPath: tempDirectory)
        }
        
        app = nil
        httpServer = nil
        videoSegmentHandler = nil
        segmentWriter = nil
        tempDirectory = nil
    }
    
    // Generate test segments of various sizes for performance testing
    private func generateTestSegments() async throws {
        // Small segment (256KB)
        try await generateSegment(size: 256 * 1024, quality: "low", index: 0)
        
        // Medium segment (1MB)
        try await generateSegment(size: 1024 * 1024, quality: "medium", index: 0)
        
        // Large segment (4MB)
        try await generateSegment(size: 4 * 1024 * 1024, quality: "high", index: 0)
        
        // Generate multiple segments to test caching behavior
        for i in 1...5 {
            try await generateSegment(size: 1024 * 1024, quality: "medium", index: i)
        }
    }
    
    private func generateSegment(size: Int, quality: String, index: Int) async throws {
        // Create a segment with random binary data
        let data = generateRandomData(size: size)
        let filename = "segment_\(index).ts"
        let segmentPath = (tempDirectory as NSString).appendingPathComponent(filename)
        try data.write(to: URL(fileURLWithPath: segmentPath))
        
        // Set up a segment and process it
        try await segmentWriter.startNewSegment()
        let segment = TSSegment(
            id: "test_\(quality)_\(index)",
            path: filename,
            duration: 2.0,
            startTime: Double(index) * 2.0
        )
        await segmentWriter.setCurrentSegment(segment)
        
        try await videoSegmentHandler.processVideoData(
            data.prefix(100), // Just a small portion to register the segment
            presentationTime: Double(index) * 2.0,
            quality: quality
        )
    }
    
    private func generateRandomData(size: Int) -> Data {
        var data = Data(count: size)
        data.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            // Fill with random bytes
            if let addr = ptr.baseAddress {
                for i in 0..<min(size, ptr.count) {
                    addr.storeBytes(of: UInt8.random(in: 0...255), toByteOffset: i, as: UInt8.self)
                }
            }
        }
        return data
    }
    
    // MARK: - Performance Tests
    
    // Test direct segment delivery performance
    func testSegmentDeliveryPerformance() async throws {
        let quality = "medium"
        let filename = "segment_0.ts"
        
        measure {
            let expectation = XCTestExpectation(description: "Segment delivery completed")
            
            Task {
                do {
                    // Get segment data - this should be optimized with our caching
                    let (_, _) = try await self.videoSegmentHandler.getSegmentData(quality: quality, filename: filename)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to get segment data: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // Test segment caching performance by accessing the same segment multiple times
    func testSegmentCachingPerformance() async throws {
        let quality = "high"
        let filename = "segment_0.ts"
        
        // First access will cache the segment
        _ = try await videoSegmentHandler.getSegmentData(quality: quality, filename: filename)
        
        // Measure cached access
        measure {
            let expectation = XCTestExpectation(description: "Cached segment access completed")
            
            Task {
                do {
                    // This should use the cache and be very fast
                    let (_, _) = try await self.videoSegmentHandler.getSegmentData(quality: quality, filename: filename)
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to get segment data: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // Test range request performance for partial segment delivery
    func testRangeRequestPerformance() async throws {
        let quality = "high"
        let filename = "segment_0.ts"
        
        // Cache the segment first
        _ = try await videoSegmentHandler.getSegmentData(quality: quality, filename: filename)
        
        // Measure range request performance
        measure {
            let expectation = XCTestExpectation(description: "Range request completed")
            
            Task {
                do {
                    // Request a 100KB chunk from the middle of the segment
                    let range = HTTPRange(start: 1048576, end: 1048576 + 102400)
                    let (data, _) = try await self.videoSegmentHandler.getSegmentData(
                        quality: quality,
                        filename: filename,
                        range: range
                    )
                    XCTAssertEqual(data.count, 102401) // Inclusive range
                    expectation.fulfill()
                } catch {
                    XCTFail("Failed to get segment data: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // Test multiple concurrent segment requests
    func testConcurrentSegmentRequests() async throws {
        let quality = "medium"
        
        // Measure concurrent access performance
        measure {
            let expectation = XCTestExpectation(description: "Concurrent requests completed")
            expectation.expectedFulfillmentCount = 5
            
            Task {
                // Request 5 different segments concurrently
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<5 {
                        group.addTask {
                            do {
                                let filename = "segment_\(i).ts"
                                _ = try await self.videoSegmentHandler.getSegmentData(quality: quality, filename: filename)
                                expectation.fulfill()
                            } catch {
                                XCTFail("Failed to get segment data: \(error)")
                            }
                        }
                    }
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Memory Usage Tests
    
    // Test memory usage during segment operation
    func testMemoryUsageDuringMultipleSegmentAccess() async throws {
        let startMemory = getMemoryUsage()
        print("Starting memory usage: \(startMemory) MB")
        
        // Access multiple segments to fill the cache
        for i in 0..<5 {
            _ = try await videoSegmentHandler.getSegmentData(quality: "medium", filename: "segment_\(i).ts")
        }
        
        let midMemory = getMemoryUsage()
        print("Memory after caching: \(midMemory) MB (delta: \(midMemory - startMemory) MB)")
        
        // Force cache pruning by accessing way more segments than the cache limit
        let config = VideoSegmentConfig(
            targetSegmentDuration: 2.0,
            maxSegments: 30,
            maxCachedSegments: 10, // Smaller cache to force pruning
            segmentDirectory: tempDirectory
        )
        
        let newHandler = VideoSegmentHandler(config: config, segmentWriter: segmentWriter)
        
        // Generate and access many segments
        for i in 0..<20 {
            try await generateSegment(size: 512 * 1024, quality: "test", index: i)
            _ = try await newHandler.getSegmentData(quality: "test", filename: "segment_\(i).ts")
        }
        
        let endMemory = getMemoryUsage()
        print("Final memory usage: \(endMemory) MB (delta: \(endMemory - midMemory) MB)")
        
        // The memory shouldn't grow unbounded due to our cache pruning
        // This is a simple assertion; real memory profiling would be more complex
        XCTAssertLessThan(endMemory - midMemory, 100, "Memory usage grew too much")
    }
    
    // Helper to get current memory usage
    private func getMemoryUsage() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Float(info.resident_size) / (1024 * 1024) // Return in MB
        } else {
            return 0
        }
    }
}

// Helper extension for the segment writer to set current segment in tests
@available(macOS 14.0, *)
extension TSSegmentWriter {
    func setCurrentSegment(_ segment: TSSegment) async {
        // This is only for testing purposes
        self.currentSegment = segment
    }
} 