import XCTest
import Vapor
import XCTVapor
import NIO
import Foundation
@testable import CursorWindowCore

/// Tests for the HTTP server under load conditions
class HTTPServerLoadTests: XCTestCase {
    var app: Application!
    var testDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary directory for test data
        testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("load_tests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // Create test files of different sizes
        try createTestFiles()
        
        // Configure the test application
        app = Application(.testing)
        
        // Add middleware for static file serving
        app.middleware.use(FileMiddleware(publicDirectory: testDirectory.path))
        
        // Configure test routes
        configureTestRoutes()
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        
        // Shut down the app
        app.shutdown()
        
        // Clean up the temporary directory
        try FileManager.default.removeItem(at: testDirectory)
    }
    
    // MARK: - Test Setup
    
    /// Creates test files of different sizes for load testing
    private func createTestFiles() throws {
        // Create small file (10KB)
        let smallFileData = Data(repeating: 0x41, count: 10 * 1024) // 'A' repeated
        try smallFileData.write(to: testDirectory.appendingPathComponent("small.dat"))
        
        // Create medium file (100KB)
        let mediumFileData = Data(repeating: 0x42, count: 100 * 1024) // 'B' repeated
        try mediumFileData.write(to: testDirectory.appendingPathComponent("medium.dat"))
        
        // Create large file (1MB)
        let largeFileData = Data(repeating: 0x43, count: 1024 * 1024) // 'C' repeated
        try largeFileData.write(to: testDirectory.appendingPathComponent("large.dat"))
    }
    
    /// Configures routes for the test application
    private func configureTestRoutes() {
        // Health check endpoint
        app.get("health") { _ -> String in
            return "OK"
        }
        
        // Echo endpoint
        app.get("echo") { req -> String in
            let message = req.query[String.self, at: "message"] ?? "No message"
            return message
        }
        
        // Delay endpoint to simulate processing time
        app.get("delay") { req -> EventLoopFuture<String> in
            let milliseconds = req.query[Int.self, at: "ms"] ?? 100
            return req.eventLoop.flatScheduleTask(in: .milliseconds(Int64(milliseconds))) {
                return "Delayed \(milliseconds)ms"
            }.futureResult
        }
        
        // File serving endpoint that handles range requests
        app.on(.GET, "files", "**") { req -> Response in
            guard let path = req.parameters.getCatchall().joined(separator: "/").removingPercentEncoding else {
                throw Abort(.badRequest)
            }
            
            let filePath = self.testDirectory.appendingPathComponent(path).path
            guard FileManager.default.fileExists(atPath: filePath) else {
                throw Abort(.notFound)
            }
            
            let fileSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int ?? 0
            
            // Get file data
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            
            // Check for range request
            if let rangeHeader = req.headers.first(name: .range) {
                // Parse range header
                let rangeParts = rangeHeader.split(separator: "=")
                if rangeParts.count == 2 && rangeParts[0] == "bytes" {
                    let ranges = rangeParts[1].split(separator: ",")[0].split(separator: "-")
                    if ranges.count > 0 {
                        let start = Int(ranges[0]) ?? 0
                        let end = ranges.count > 1 ? (Int(ranges[1]) ?? (fileSize - 1)) : (fileSize - 1)
                        
                        if start >= 0 && end < fileSize && start <= end {
                            let length = end - start + 1
                            let rangeData = fileData.subdata(in: start..<(start + length))
                            
                            var headers = HTTPHeaders()
                            headers.add(name: .contentRange, value: "bytes \(start)-\(end)/\(fileSize)")
                            headers.add(name: .contentLength, value: "\(length)")
                            headers.add(name: .contentType, value: "application/octet-stream")
                            
                            return Response(status: .partialContent, headers: headers, body: Response.Body(data: rangeData))
                        }
                    }
                }
            }
            
            // Return full file if not a range request or if range parsing failed
            var headers = HTTPHeaders()
            headers.add(name: .contentLength, value: "\(fileSize)")
            headers.add(name: .contentType, value: "application/octet-stream")
            
            return Response(status: .ok, headers: headers, body: Response.Body(data: fileData))
        }
    }
    
    // MARK: - Load Tests
    
    /// Tests the server with concurrent health check requests
    func testConcurrentHealthChecks() throws {
        let concurrentRequests = 100
        let group = DispatchGroup()
        var responses = [Int](repeating: 0, count: concurrentRequests)
        
        measure {
            for i in 0..<concurrentRequests {
                group.enter()
                
                DispatchQueue.global().async {
                    do {
                        try self.app.test(.GET, "health") { response in
                            XCTAssertEqual(response.status, .ok)
                            XCTAssertEqual(response.body.string, "OK")
                            responses[i] = 1
                        }
                    } catch {
                        XCTFail("Request \(i) failed: \(error)")
                    }
                    
                    group.leave()
                }
            }
            
            let result = group.wait(timeout: .now() + 10.0)
            XCTAssertEqual(result, .success, "Timed out waiting for concurrent health checks")
            
            // Verify all requests succeeded
            let successCount = responses.reduce(0, +)
            XCTAssertEqual(successCount, concurrentRequests, "Only \(successCount) of \(concurrentRequests) requests succeeded")
        }
    }
    
    /// Tests the server with concurrent large file downloads
    func testConcurrentLargeFileDownloads() throws {
        let concurrentRequests = 10
        let group = DispatchGroup()
        var responses = [Int](repeating: 0, count: concurrentRequests)
        
        measure {
            for i in 0..<concurrentRequests {
                group.enter()
                
                DispatchQueue.global().async {
                    do {
                        try self.app.test(.GET, "files/large.dat") { response in
                            XCTAssertEqual(response.status, .ok)
                            XCTAssertEqual(response.body.readableBytes, 1024 * 1024, "Incorrect file size received")
                            responses[i] = 1
                        }
                    } catch {
                        XCTFail("Request \(i) failed: \(error)")
                    }
                    
                    group.leave()
                }
            }
            
            let result = group.wait(timeout: .now() + 30.0)
            XCTAssertEqual(result, .success, "Timed out waiting for concurrent file downloads")
            
            // Verify all requests succeeded
            let successCount = responses.reduce(0, +)
            XCTAssertEqual(successCount, concurrentRequests, "Only \(successCount) of \(concurrentRequests) requests succeeded")
        }
    }
    
    /// Tests the server with concurrent range requests
    func testConcurrentRangeRequests() throws {
        let concurrentRequests = 20
        let group = DispatchGroup()
        var responses = [Int](repeating: 0, count: concurrentRequests)
        
        measure {
            for i in 0..<concurrentRequests {
                group.enter()
                
                // Create a different range for each request
                let startByte = (i * 50 * 1024) % (1024 * 1024)
                let endByte = startByte + 20 * 1024 - 1
                
                var headers = HTTPHeaders()
                headers.add(name: .range, value: "bytes=\(startByte)-\(endByte)")
                
                DispatchQueue.global().async {
                    do {
                        try self.app.test(.GET, "files/large.dat", headers: headers) { response in
                            XCTAssertEqual(response.status, .partialContent)
                            XCTAssertEqual(response.body.readableBytes, 20 * 1024, "Incorrect range size received")
                            
                            if let contentRange = response.headers.first(name: .contentRange) {
                                XCTAssertTrue(contentRange.starts(with: "bytes \(startByte)-\(endByte)/"), "Invalid Content-Range header")
                            } else {
                                XCTFail("Missing Content-Range header")
                            }
                            
                            responses[i] = 1
                        }
                    } catch {
                        XCTFail("Request \(i) failed: \(error)")
                    }
                    
                    group.leave()
                }
            }
            
            let result = group.wait(timeout: .now() + 20.0)
            XCTAssertEqual(result, .success, "Timed out waiting for concurrent range requests")
            
            // Verify all requests succeeded
            let successCount = responses.reduce(0, +)
            XCTAssertEqual(successCount, concurrentRequests, "Only \(successCount) of \(concurrentRequests) requests succeeded")
        }
    }
    
    /// Tests the server with a mix of different request types to simulate real-world load
    func testMixedRequestLoad() throws {
        let totalRequests = 50
        let group = DispatchGroup()
        var successCount = 0
        let lock = NSLock()
        
        measure {
            for i in 0..<totalRequests {
                group.enter()
                
                DispatchQueue.global().async {
                    do {
                        // Determine request type based on index
                        switch i % 5 {
                        case 0:
                            // Health check
                            try self.app.test(.GET, "health") { response in
                                XCTAssertEqual(response.status, .ok)
                                lock.lock()
                                successCount += 1
                                lock.unlock()
                            }
                            
                        case 1:
                            // Echo request
                            try self.app.test(.GET, "echo?message=test\(i)") { response in
                                XCTAssertEqual(response.status, .ok)
                                XCTAssertEqual(response.body.string, "test\(i)")
                                lock.lock()
                                successCount += 1
                                lock.unlock()
                            }
                            
                        case 2:
                            // Delay request with random delay
                            let delay = Int.random(in: 10...100)
                            try self.app.test(.GET, "delay?ms=\(delay)") { response in
                                XCTAssertEqual(response.status, .ok)
                                XCTAssertEqual(response.body.string, "Delayed \(delay)ms")
                                lock.lock()
                                successCount += 1
                                lock.unlock()
                            }
                            
                        case 3:
                            // Small file request
                            try self.app.test(.GET, "files/small.dat") { response in
                                XCTAssertEqual(response.status, .ok)
                                XCTAssertEqual(response.body.readableBytes, 10 * 1024)
                                lock.lock()
                                successCount += 1
                                lock.unlock()
                            }
                            
                        case 4:
                            // Range request on medium file
                            let startByte = Int.random(in: 0..<(90 * 1024))
                            let endByte = startByte + 10 * 1024 - 1
                            
                            var headers = HTTPHeaders()
                            headers.add(name: .range, value: "bytes=\(startByte)-\(endByte)")
                            
                            try self.app.test(.GET, "files/medium.dat", headers: headers) { response in
                                XCTAssertEqual(response.status, .partialContent)
                                XCTAssertEqual(response.body.readableBytes, 10 * 1024)
                                lock.lock()
                                successCount += 1
                                lock.unlock()
                            }
                            
                        default:
                            break
                        }
                    } catch {
                        XCTFail("Request \(i) failed: \(error)")
                    }
                    
                    group.leave()
                }
            }
            
            let result = group.wait(timeout: .now() + 30.0)
            XCTAssertEqual(result, .success, "Timed out waiting for mixed request load")
            
            // Verify all requests succeeded
            XCTAssertEqual(successCount, totalRequests, "Only \(successCount) of \(totalRequests) requests succeeded")
        }
    }
    
    /// Tests server latency under load with a small processing delay
    func testServerLatencyUnderLoad() throws {
        let concurrentRequests = 20
        let processingDelayMs = 50
        let group = DispatchGroup()
        var responseTimes = [TimeInterval](repeating: 0, count: concurrentRequests)
        
        measure {
            for i in 0..<concurrentRequests {
                group.enter()
                
                DispatchQueue.global().async {
                    let startTime = Date()
                    
                    do {
                        try self.app.test(.GET, "delay?ms=\(processingDelayMs)") { response in
                            let endTime = Date()
                            let requestDuration = endTime.timeIntervalSince(startTime)
                            
                            XCTAssertEqual(response.status, .ok)
                            XCTAssertEqual(response.body.string, "Delayed \(processingDelayMs)ms")
                            
                            responseTimes[i] = requestDuration
                        }
                    } catch {
                        XCTFail("Request \(i) failed: \(error)")
                    }
                    
                    group.leave()
                }
            }
            
            let result = group.wait(timeout: .now() + 30.0)
            XCTAssertEqual(result, .success, "Timed out waiting for latency test")
            
            // Calculate average response time
            let totalResponseTime = responseTimes.reduce(0, +)
            let averageResponseTime = totalResponseTime / Double(concurrentRequests)
            
            // Verify response times are within acceptable limits
            // The delay is 50ms, but we expect some overhead, so a 150ms average is reasonable
            print("Average response time: \(averageResponseTime * 1000) ms for \(processingDelayMs)ms delay")
            XCTAssertLessThan(averageResponseTime, 0.15, "Average response time excessive: \(averageResponseTime * 1000) ms")
            
            // Also check for outliers
            let maxResponseTime = responseTimes.max() ?? 0
            print("Maximum response time: \(maxResponseTime * 1000) ms")
            XCTAssertLessThan(maxResponseTime, 0.3, "Maximum response time excessive: \(maxResponseTime * 1000) ms")
        }
    }
} 