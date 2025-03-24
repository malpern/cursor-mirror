import XCTest
@testable import CursorMirrorClient

class TouchEventSendingTests: XCTestCase {
    
    var viewModel: ConnectionViewModel!
    var mockCloudKit: MockCloudKitDatabase!
    var mockURLSession: MockURLSession!
    var originalURLSession: URLSession!
    
    override func setUp() {
        super.setUp()
        
        // Set up mock CloudKit
        mockCloudKit = MockCloudKitDatabase()
        
        // Set up mock URL session
        mockURLSession = MockURLSession()
        let mockSession = URLSession.makeMockSession(mockURLSession: mockURLSession)
        
        // Create view model with mock dependencies
        viewModel = ConnectionViewModel(
            connectionState: ConnectionState(),
            database: mockCloudKit
        )
        
        // Save original URL session
        originalURLSession = URLSession.shared
        
        // Swap in the mock session
        URLSession.swapURLSession(mockSession)
    }
    
    override func tearDown() {
        // Restore original URL session
        URLSession.swapURLSession(originalURLSession)
        
        viewModel = nil
        mockCloudKit = nil
        mockURLSession = nil
        
        super.tearDown()
    }
    
    func testSendTouchEvent() async {
        // Set up a connected state
        let device = DeviceInfo(id: "test-device", name: "Test Device", type: "Mac", isOnline: true, lastSeen: Date())
        viewModel.connectionState.selectDevice(device)
        viewModel.connectionState.status = .connected
        
        // Create touch event
        let touchEvent = TouchEvent(type: .began, percentX: 0.5, percentY: 0.5)
        
        // Configure touch endpoint URL
        let touchURL = URL(string: "http://localhost:8080/api/touch")!
        mockURLSession.setSuccessResponse(for: touchURL)
        
        // Send the event
        await viewModel.sendTouchEvent(touchEvent)
        
        // Verify request was made
        XCTAssertEqual(mockURLSession.requestCount, 1, "Should have made a network request")
        XCTAssertNotNil(mockURLSession.lastRequest, "Should have captured the last request")
        
        // Verify request details
        if let request = mockURLSession.lastRequest {
            XCTAssertEqual(request.url?.absoluteString, "http://localhost:8080/api/touch", "Incorrect URL")
            XCTAssertEqual(request.httpMethod, "POST", "Should be a POST request")
            XCTAssertEqual(request.allHTTPHeaderFields?["Content-Type"], "application/json", "Missing content type")
            
            // Verify the request body contains the event data
            if let body = request.httpBody {
                do {
                    let json = try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
                    XCTAssertNotNil(json, "Request body should be valid JSON")
                    
                    let deviceID = json?["deviceID"] as? String
                    XCTAssertEqual(deviceID, "test-device", "Device ID in request body is incorrect")
                    
                    // Verify event data is included
                    XCTAssertNotNil(json?["event"], "Event data should be present in request body")
                } catch {
                    XCTFail("Failed to parse request body: \(error.localizedDescription)")
                }
            } else {
                XCTFail("Request body is missing")
            }
        }
    }
    
    func testSendTouchEventFailure() async {
        // Set up a connected state
        let device = DeviceInfo(id: "test-device", name: "Test Device", type: "Mac", isOnline: true, lastSeen: Date())
        viewModel.connectionState.selectDevice(device)
        viewModel.connectionState.status = .connected
        
        // Create touch event
        let touchEvent = TouchEvent(type: .began, percentX: 0.5, percentY: 0.5)
        
        // Configure touch endpoint URL to return an error
        let touchURL = URL(string: "http://localhost:8080/api/touch")!
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: nil)
        mockURLSession.setErrorResponse(for: touchURL, error: error)
        
        // Send the event (this should not throw or crash)
        await viewModel.sendTouchEvent(touchEvent)
        
        // Verify request was made
        XCTAssertEqual(mockURLSession.requestCount, 1, "Should have made a network request despite failure")
    }
    
    func testIgnoreTouchEventsWhenDisconnected() async {
        // Set status to disconnected
        viewModel.connectionState.status = .disconnected
        
        // Create touch event
        let touchEvent = TouchEvent(type: .began, percentX: 0.5, percentY: 0.5)
        
        // Send the event
        await viewModel.sendTouchEvent(touchEvent)
        
        // Verify no request was made
        XCTAssertEqual(mockURLSession.requestCount, 0, "Should not make requests when disconnected")
    }
    
    func testAllTouchEventTypes() async {
        // Set up a connected state
        let device = DeviceInfo(id: "test-device", name: "Test Device", type: "Mac", isOnline: true, lastSeen: Date())
        viewModel.connectionState.selectDevice(device)
        viewModel.connectionState.status = .connected
        
        // Configure touch endpoint URL
        let touchURL = URL(string: "http://localhost:8080/api/touch")!
        mockURLSession.setSuccessResponse(for: touchURL)
        
        // Test all touch event types
        let eventTypes: [TouchEventType] = [.began, .moved, .ended, .cancelled]
        
        for type in eventTypes {
            // Reset request count
            mockURLSession.requestCount = 0
            
            // Create and send event
            let touchEvent = TouchEvent(type: type, percentX: 0.5, percentY: 0.5)
            await viewModel.sendTouchEvent(touchEvent)
            
            // Verify request was made
            XCTAssertEqual(mockURLSession.requestCount, 1, "Should have made a request for \(type) event")
        }
    }
}

// Helper extension to swap the shared URLSession
private extension URLSession {
    static func swapURLSession(_ session: URLSession) {
        // This is a bit hacky and only for testing
        // It uses the Objective-C runtime to replace the shared session
        let originalClass = URLSession.self
        
        // Get the shared property
        let selector = #selector(getter: URLSession.shared)
        
        // Create a method to return our mock
        let method = class_getClassMethod(originalClass, selector)!
        
        let implementation: @convention(c) (AnyObject, Selector) -> URLSession = { _, _ in
            return session
        }
        
        method_setImplementation(method, unsafeBitCast(implementation, to: IMP.self))
    }
} 