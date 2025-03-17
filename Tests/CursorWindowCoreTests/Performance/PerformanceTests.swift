import XCTest
import Vapor
import NIO
import XCTVapor
import NIOHTTP1
@testable import CursorWindowCore

/// Performance tests for the HTTP server and video segment handling
class PerformanceTests: XCTestCase {
    var app: Application!
    var serverManager: HTTPServerManager!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for test assets
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("performance_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test segments for HLS streaming
        try createTestSegments()
        
        // Configure the application with test settings
        app = Application(.testing)
        let config = HTTPServerConfig(
            hostname: "127.0.0.1",
            port: 8080 + Int.random(in: 1000...2000), // Use a random port to avoid conflicts
            useSSL: false,
            enableAdmin: false,
            maxRequestLogs: 1000,
            enableCORS: true
        )
        
        // Create a stream manager with test data
        let streamManager = HLSStreamManager(segmentsDirectory: tempDirectory.path)
        
        // Create the HTTP server manager
        serverManager = try HTTPServerManager(app: app, 
                                             config: config,
                                             streamManager: streamManager,
                                             authManager: AuthenticationManager(username: "test", password: "test"))
        
        // Configure the test routes
        try serverManager.start()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        // Shut down the app
        app.shutdown()
        
        // Clean up the temporary directory
        try FileManager.default.removeItem(at: tempDirectory)
    }
    
    // MARK: - Test Helpers
    
    /// Creates test segment files of different sizes for performance testing
    private func createTestSegments() throws {
        // Create 20 segment files of varying sizes
        for i in 0..<20 {
            // Create segments of different sizes to simulate real video segments
            let size = i % 3 == 0 ? 64 * 1024 : (i % 3 == 1 ? 256 * 1024 : 1024 * 1024)
            let data = Data(repeating: UInt8(i % 256), count: size)
            
            // Create the segment file
            let segmentPath = tempDirectory.appendingPathComponent("segment\(i).ts")
            try data.write(to: segmentPath)
        }
        
        // Create a playlist file
        let playlist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:2
        #EXT-X-MEDIA-SEQUENCE:0
        
        #EXTINF:2.000000,
        segment0.ts
        #EXTINF:2.000000,
        segment1.ts
        #EXTINF:2.000000,
        segment2.ts
        #EXTINF:2.000000,
        segment3.ts
        #EXTINF:2.000000,
        segment4.ts
        #EXTINF:2.000000,
        segment5.ts
        #EXTINF:2.000000,
        segment6.ts
        #EXTINF:2.000000,
        segment7.ts
        #EXTINF:2.000000,
        segment8.ts
        #EXTINF:2.000000,
        segment9.ts
        #EXTINF:2.000000,
        segment10.ts
        #EXTINF:2.000000,
        segment11.ts
        #EXTINF:2.000000,
        segment12.ts
        #EXTINF:2.000000,
        segment13.ts
        #EXTINF:2.000000,
        segment14.ts
        #EXTINF:2.000000,
        segment15.ts
        #EXTINF:2.000000,
        segment16.ts
        #EXTINF:2.000000,
        segment17.ts
        #EXTINF:2.000000,
        segment18.ts
        #EXTINF:2.000000,
        segment19.ts
        
        #EXT-X-ENDLIST
        """
        
        let playlistPath = tempDirectory.appendingPathComponent("playlist.m3u8")
        try playlist.write(to: playlistPath, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Performance Tests
    
    /// Tests the performance of segment delivery
    func testSegmentDeliveryPerformance() throws {
        measure {
            for i in 0..<10 {
                let segmentIndex = i % 20
                let expectation = XCTestExpectation(description: "Segment \(segmentIndex) delivery")
                
                let segmentURL = "/stream/segment\(segmentIndex).ts"
                
                app.test(.GET, segmentURL) { response in
                    XCTAssertEqual(response.status, .ok)
                    XCTAssertNotNil(response.body)
                    
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    /// Tests the performance of the caching mechanism
    func testCachingPerformance() throws {
        // First request to cache the segments
        for i in 0..<5 {
            let segmentURL = "/stream/segment\(i).ts"
            try app.test(.GET, segmentURL) { response in
                XCTAssertEqual(response.status, .ok)
            }
        }
        
        // Now measure cached responses
        measure {
            for i in 0..<5 {
                let expectation = XCTestExpectation(description: "Cached segment \(i) delivery")
                
                let segmentURL = "/stream/segment\(i).ts"
                
                app.test(.GET, segmentURL) { response in
                    XCTAssertEqual(response.status, .ok)
                    // Verify cache headers if implemented
                    if let cacheControl = response.headers.first(name: .cacheControl) {
                        XCTAssertTrue(cacheControl.contains("max-age="))
                    }
                    
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    /// Tests the performance of range requests
    func testRangeRequestPerformance() throws {
        // Use a larger segment for range requests
        let segmentIndex = 9 // This should be one of the 1MB segments
        let segmentURL = "/stream/segment\(segmentIndex).ts"
        
        measure {
            for i in 0..<5 {
                let expectation = XCTestExpectation(description: "Range request \(i)")
                
                // Define range based on the iteration
                let startByte = i * 200 * 1024
                let endByte = startByte + 100 * 1024 - 1
                
                var headers = HTTPHeaders()
                headers.add(name: .range, value: "bytes=\(startByte)-\(endByte)")
                
                app.test(.GET, segmentURL, headers: headers) { response in
                    // Should be 206 Partial Content
                    XCTAssertEqual(response.status, .partialContent)
                    
                    // Check content-range header
                    if let contentRange = response.headers.first(name: .contentRange) {
                        XCTAssertTrue(contentRange.starts(with: "bytes \(startByte)-\(endByte)/"))
                    }
                    
                    // Verify correct content length
                    if let contentLength = response.headers.first(name: .contentLength) {
                        XCTAssertEqual(Int(contentLength), 100 * 1024)
                    }
                    
                    expectation.fulfill()
                }
                
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    /// Tests the performance of concurrent segment requests
    func testConcurrentSegmentRequests() throws {
        measure {
            let group = DispatchGroup()
            for i in 0..<10 {
                group.enter()
                
                let segmentIndex = i % 20
                let segmentURL = "/stream/segment\(segmentIndex).ts"
                
                DispatchQueue.global().async {
                    do {
                        try self.app.test(.GET, segmentURL) { response in
                            XCTAssertEqual(response.status, .ok)
                            XCTAssertNotNil(response.body)
                        }
                    } catch {
                        XCTFail("Request failed: \(error)")
                    }
                    
                    group.leave()
                }
            }
            
            // Wait for all concurrent requests to complete
            let result = group.wait(timeout: .now() + 10.0)
            XCTAssertEqual(result, .success, "Timed out waiting for concurrent requests")
        }
    }
    
    /// Tests memory usage during segment operations
    func testMemoryUsageDuringSegmentOperations() throws {
        // Function to get current memory usage
        func currentMemoryUsageInMB() -> Double {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
            
            let kerr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }
            
            if kerr == KERN_SUCCESS {
                return Double(info.resident_size) / (1024 * 1024)
            } else {
                return -1
            }
        }
        
        // Initial memory usage
        let initialMemory = currentMemoryUsageInMB()
        XCTAssertGreaterThan(initialMemory, 0, "Failed to get initial memory usage")
        
        // Perform a series of segment requests with different patterns
        for _ in 0..<5 {
            // Sequential segment access
            for i in 0..<10 {
                let segmentURL = "/stream/segment\(i).ts"
                try app.test(.GET, segmentURL) { _ in }
            }
            
            // Random segment access
            for _ in 0..<10 {
                let randomSegment = Int.random(in: 0..<20)
                let segmentURL = "/stream/segment\(randomSegment).ts"
                try app.test(.GET, segmentURL) { _ in }
            }
            
            // Range requests
            for i in 0..<5 {
                let segmentIndex = 12 // Using a 1MB segment
                let segmentURL = "/stream/segment\(segmentIndex).ts"
                let startByte = i * 200 * 1024
                let endByte = startByte + 50 * 1024 - 1
                
                var headers = HTTPHeaders()
                headers.add(name: .range, value: "bytes=\(startByte)-\(endByte)")
                
                try app.test(.GET, segmentURL, headers: headers) { _ in }
            }
        }
        
        // Final memory usage
        let finalMemory = currentMemoryUsageInMB()
        XCTAssertGreaterThan(finalMemory, 0, "Failed to get final memory usage")
        
        // Print memory usage for analysis
        print("Memory usage: Initial \(initialMemory) MB, Final \(finalMemory) MB, Difference \(finalMemory - initialMemory) MB")
        
        // Check for significant memory leaks
        // Allow for some memory growth, but not excessive
        XCTAssertLessThan(finalMemory - initialMemory, 50, "Excessive memory growth detected")
    }
} 