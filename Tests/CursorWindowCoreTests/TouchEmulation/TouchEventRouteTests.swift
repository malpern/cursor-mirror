import XCTest
import Vapor
import XCTVapor
@testable import CursorWindowCore

class TouchEventRouteTests: XCTestCase {
    
    var app: Application!
    
    override func setUp() {
        super.setUp()
        
        // Create test app
        app = Application(.testing)
        
        // Register touch routes
        let testController = TestTouchEventController()
        testController.registerRoutes(with: app)
    }
    
    override func tearDown() {
        app.shutdown()
        app = nil
        
        super.tearDown()
    }
    
    // Test successful touch event
    func testSuccessfulTouchEvent() throws {
        // Create test event data
        let eventData: [String: Any] = [
            "deviceID": "test-device",
            "event": [
                "type": "began",
                "percentX": 0.5,
                "percentY": 0.5
            ]
        ]
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: eventData)
        
        // Send request
        try app.test(.POST, "/api/touch", beforeRequest: { req in
            req.headers.contentType = .json
            req.body = .init(data: jsonData)
        }, afterResponse: { response in
            // Check response status
            XCTAssertEqual(response.status, .ok, "Response status should be 200 OK")
            
            // Verify the event was processed
            let testController = TestTouchEventController.shared
            XCTAssertTrue(testController.lastTouchEventProcessed, "Event should have been processed")
            
            if let processedEvent = testController.lastTouchEvent {
                // Verify event content
                XCTAssertEqual(processedEvent["deviceID"] as? String, "test-device")
                
                if let event = processedEvent["event"] as? [String: Any] {
                    XCTAssertEqual(event["type"] as? String, "began")
                    XCTAssertEqual(event["percentX"] as? Double, 0.5)
                    XCTAssertEqual(event["percentY"] as? Double, 0.5)
                } else {
                    XCTFail("Event data missing from processed event")
                }
            } else {
                XCTFail("No event was processed")
            }
        })
    }
    
    // Test malformed JSON
    func testMalformedJSON() throws {
        // Invalid JSON
        let invalidJSON = "{ invalid: json }"
        
        // Send request with invalid JSON
        try app.test(.POST, "/api/touch", beforeRequest: { req in
            req.headers.contentType = .json
            req.body = .init(string: invalidJSON)
        }, afterResponse: { response in
            // Check response status
            XCTAssertEqual(response.status, .badRequest, "Response should be 400 Bad Request for invalid JSON")
        })
    }
    
    // Test missing required fields
    func testMissingFields() throws {
        // Missing event field
        let missingEventData: [String: Any] = [
            "deviceID": "test-device"
            // No event field
        ]
        
        // Convert to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: missingEventData)
        
        // Send request
        try app.test(.POST, "/api/touch", beforeRequest: { req in
            req.headers.contentType = .json
            req.body = .init(data: jsonData)
        }, afterResponse: { response in
            // Since Vapor will decode this request but our controller expects certain fields,
            // the response should still be OK, but no event processing occurs
            XCTAssertEqual(response.status, .ok)
            
            let testController = TestTouchEventController.shared
            XCTAssertFalse(testController.lastTouchEventProcessed, "Event should not have been processed with missing fields")
        })
    }
}

// Mock TouchEventController for testing
class TestTouchEventController: TouchEventController {
    // Use a shared instance for tests
    static let shared = TestTouchEventController()
    
    // Track the last event that was processed
    var lastTouchEvent: [String: Any]?
    var lastTouchEventProcessed = false
    
    override func processTouchEvent(_ touchEvent: [String: Any]) {
        lastTouchEvent = touchEvent
        lastTouchEventProcessed = true
        
        // Don't actually process the event in tests
        // super.processTouchEvent(touchEvent)
    }
    
    func reset() {
        lastTouchEvent = nil
        lastTouchEventProcessed = false
    }
} 