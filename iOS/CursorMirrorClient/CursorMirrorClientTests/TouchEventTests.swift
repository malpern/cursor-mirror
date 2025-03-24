import XCTest
@testable import CursorMirrorClient

class TouchEventTests: XCTestCase {
    
    func testTouchEventInitialization() {
        // Test basic initialization
        let event = TouchEvent(type: .began, percentX: 0.5, percentY: 0.5)
        
        // Verify properties
        XCTAssertEqual(event.type, .began)
        XCTAssertEqual(event.percentX, 0.5)
        XCTAssertEqual(event.percentY, 0.5)
        XCTAssertNil(event.force)
        XCTAssertNotNil(event.id)
        XCTAssertNotNil(event.timestamp)
    }
    
    func testTouchEventWithForce() {
        // Test initialization with force value
        let event = TouchEvent(type: .moved, percentX: 0.25, percentY: 0.75, force: 0.8)
        
        // Verify force is stored correctly
        XCTAssertEqual(event.force, 0.8)
    }
    
    func testCoordinateClamping() {
        // Test values outside the 0-1 range are clamped
        let event1 = TouchEvent(type: .began, percentX: -0.5, percentY: 1.5)
        XCTAssertEqual(event1.percentX, 0.0, "X coordinate should be clamped to minimum 0")
        XCTAssertEqual(event1.percentY, 1.0, "Y coordinate should be clamped to maximum 1")
        
        let event2 = TouchEvent(type: .began, percentX: 2.0, percentY: -1.0)
        XCTAssertEqual(event2.percentX, 1.0, "X coordinate should be clamped to maximum 1")
        XCTAssertEqual(event2.percentY, 0.0, "Y coordinate should be clamped to minimum 0")
    }
    
    func testJSONSerialization() {
        // Create an event
        let event = TouchEvent(type: .ended, percentX: 0.5, percentY: 0.5)
        
        // Test serialization to JSON
        let jsonData = event.toJSONData()
        XCTAssertNotNil(jsonData, "Event should serialize to JSON")
        
        // Test deserialization from JSON
        if let data = jsonData {
            let deserializedEvent = TouchEvent.from(jsonData: data)
            XCTAssertNotNil(deserializedEvent, "Should deserialize from JSON")
            
            // Verify properties match
            XCTAssertEqual(deserializedEvent?.id, event.id)
            XCTAssertEqual(deserializedEvent?.type, event.type)
            XCTAssertEqual(deserializedEvent?.percentX, event.percentX)
            XCTAssertEqual(deserializedEvent?.percentY, event.percentY)
            XCTAssertEqual(deserializedEvent?.force, event.force)
        }
    }
    
    func testAllEventTypes() {
        // Test all event types
        let eventTypes: [TouchEventType] = [.began, .moved, .ended, .cancelled]
        
        for type in eventTypes {
            let event = TouchEvent(type: type, percentX: 0.5, percentY: 0.5)
            XCTAssertEqual(event.type, type)
            
            // Verify serialization works for all types
            let jsonData = event.toJSONData()
            XCTAssertNotNil(jsonData)
            
            if let data = jsonData {
                let deserializedEvent = TouchEvent.from(jsonData: data)
                XCTAssertEqual(deserializedEvent?.type, type)
            }
        }
    }
    
    func testInvalidJSONDeserialization() {
        // Create invalid JSON data
        let invalidJSON = "{\"invalid\": \"json\"}".data(using: .utf8)!
        
        // Attempt to deserialize
        let event = TouchEvent.from(jsonData: invalidJSON)
        XCTAssertNil(event, "Should return nil for invalid JSON")
    }
} 