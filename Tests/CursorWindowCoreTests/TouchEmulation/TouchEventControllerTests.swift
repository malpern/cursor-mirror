import XCTest
@testable import CursorWindowCore

class TouchEventControllerTests: XCTestCase {
    
    var controller: TouchEventController!
    
    override func setUp() {
        super.setUp()
        controller = TouchEventController.shared
        controller.isEnabled = true
        
        // Setup a test viewport bounds
        controller.viewportBounds = CGRect(x: 100, y: 100, width: 393, height: 852)
    }
    
    override func tearDown() {
        controller.isEnabled = false
        super.tearDown()
    }
    
    // Test basic event processing
    func testProcessTouchEvent() {
        // Create a touch event
        let touchEvent: [String: Any] = [
            "event": [
                "type": "began",
                "percentX": 0.5,
                "percentY": 0.5,
                "timestamp": Date()
            ]
        ]
        
        // Process the event (should not crash)
        controller.processTouchEvent(touchEvent)
        
        // Since we can't directly observe the mouse events being generated,
        // this test just ensures the method doesn't crash
        XCTAssertTrue(true, "Touch event processing should complete without errors")
    }
    
    // Test coordinate mapping
    func testCoordinateMapping() {
        // Create a custom subclass for testing
        class TestTouchEventController: TouchEventController {
            var lastProcessedPosition: CGPoint?
            
            override init() {
                super.init()
            }
            
            override func simulateMouseDown(at position: CGPoint) {
                lastProcessedPosition = position
                // Don't actually post the event in tests
            }
            
            override func simulateMouseMoved(to position: CGPoint) {
                lastProcessedPosition = position
                // Don't actually post the event in tests
            }
            
            override func simulateMouseDragged(to position: CGPoint) {
                lastProcessedPosition = position
                // Don't actually post the event in tests
            }
            
            override func simulateMouseUp(at position: CGPoint) {
                lastProcessedPosition = position
                // Don't actually post the event in tests
            }
        }
        
        // Use the test subclass
        let testController = TestTouchEventController()
        testController.isEnabled = true
        testController.viewportBounds = CGRect(x: 100, y: 100, width: 200, height: 400)
        
        // Test different coordinate mappings
        // Center position (0.5, 0.5)
        let centerEvent: [String: Any] = [
            "event": [
                "type": "began",
                "percentX": 0.5,
                "percentY": 0.5
            ]
        ]
        testController.processTouchEvent(centerEvent)
        XCTAssertEqual(testController.lastProcessedPosition?.x, 200, "X coordinate should map to center of viewport")
        XCTAssertEqual(testController.lastProcessedPosition?.y, 300, "Y coordinate should map to center of viewport")
        
        // Top-left position (0, 0)
        let topLeftEvent: [String: Any] = [
            "event": [
                "type": "began",
                "percentX": 0.0,
                "percentY": 0.0
            ]
        ]
        testController.processTouchEvent(topLeftEvent)
        XCTAssertEqual(testController.lastProcessedPosition?.x, 100, "X coordinate should map to left of viewport")
        XCTAssertEqual(testController.lastProcessedPosition?.y, 100, "Y coordinate should map to top of viewport")
        
        // Bottom-right position (1, 1)
        let bottomRightEvent: [String: Any] = [
            "event": [
                "type": "began",
                "percentX": 1.0,
                "percentY": 1.0
            ]
        ]
        testController.processTouchEvent(bottomRightEvent)
        XCTAssertEqual(testController.lastProcessedPosition?.x, 300, "X coordinate should map to right of viewport")
        XCTAssertEqual(testController.lastProcessedPosition?.y, 500, "Y coordinate should map to bottom of viewport")
    }
    
    // Test all event types
    func testAllEventTypes() {
        // Create a custom subclass for testing
        class TestTouchEventController: TouchEventController {
            var lastEventType: String?
            var isMouseDownCalled = false
            var isMouseMovedCalled = false
            var isMouseDraggedCalled = false
            var isMouseUpCalled = false
            
            override init() {
                super.init()
            }
            
            func reset() {
                lastEventType = nil
                isMouseDownCalled = false
                isMouseMovedCalled = false
                isMouseDraggedCalled = false
                isMouseUpCalled = false
            }
            
            override func simulateMouseDown(at position: CGPoint) {
                isMouseDownCalled = true
                lastEventType = "down"
                // Don't actually post the event in tests
            }
            
            override func simulateMouseMoved(to position: CGPoint) {
                isMouseMovedCalled = true
                lastEventType = "moved"
                // Don't actually post the event in tests
            }
            
            override func simulateMouseDragged(to position: CGPoint) {
                isMouseDraggedCalled = true
                lastEventType = "dragged"
                // Don't actually post the event in tests
            }
            
            override func simulateMouseUp(at position: CGPoint) {
                isMouseUpCalled = true
                lastEventType = "up"
                // Don't actually post the event in tests
            }
        }
        
        // Use the test subclass
        let testController = TestTouchEventController()
        testController.isEnabled = true
        testController.viewportBounds = CGRect(x: 100, y: 100, width: 200, height: 400)
        
        // Test began event (should call mouse down)
        let beganEvent: [String: Any] = [
            "event": [
                "type": "began",
                "percentX": 0.5,
                "percentY": 0.5
            ]
        ]
        testController.processTouchEvent(beganEvent)
        XCTAssertTrue(testController.isMouseDownCalled, "Mouse down should be called for began event")
        XCTAssertEqual(testController.lastEventType, "down")
        
        // Reset state
        testController.reset()
        
        // Test moved event with mouse up (should call mouse move)
        testController.isMouseDown = false
        let movedEvent: [String: Any] = [
            "event": [
                "type": "moved",
                "percentX": 0.5,
                "percentY": 0.5
            ]
        ]
        testController.processTouchEvent(movedEvent)
        XCTAssertTrue(testController.isMouseMovedCalled, "Mouse moved should be called for moved event when mouse is up")
        XCTAssertEqual(testController.lastEventType, "moved")
        
        // Reset state
        testController.reset()
        
        // Test moved event with mouse down (should call mouse drag)
        testController.isMouseDown = true
        testController.processTouchEvent(movedEvent)
        XCTAssertTrue(testController.isMouseDraggedCalled, "Mouse dragged should be called for moved event when mouse is down")
        XCTAssertEqual(testController.lastEventType, "dragged")
        
        // Reset state
        testController.reset()
        
        // Test ended event (should call mouse up)
        let endedEvent: [String: Any] = [
            "event": [
                "type": "ended",
                "percentX": 0.5,
                "percentY": 0.5
            ]
        ]
        testController.isMouseDown = true
        testController.processTouchEvent(endedEvent)
        XCTAssertTrue(testController.isMouseUpCalled, "Mouse up should be called for ended event")
        XCTAssertEqual(testController.lastEventType, "up")
    }
    
    // Test disabled touch emulation
    func testDisabledTouchEmulation() {
        // Create a custom subclass for testing
        class TestTouchEventController: TouchEventController {
            var methodCalled = false
            
            override init() {
                super.init()
            }
            
            func reset() {
                methodCalled = false
            }
            
            override func simulateMouseDown(at position: CGPoint) {
                methodCalled = true
            }
        }
        
        // Use the test subclass
        let testController = TestTouchEventController()
        testController.isEnabled = false
        testController.viewportBounds = CGRect(x: 100, y: 100, width: 200, height: 400)
        
        // Create a touch event
        let touchEvent: [String: Any] = [
            "event": [
                "type": "began",
                "percentX": 0.5,
                "percentY": 0.5
            ]
        ]
        
        // Process the event with touch emulation disabled
        testController.processTouchEvent(touchEvent)
        
        // Verify no methods were called
        XCTAssertFalse(testController.methodCalled, "No touch event methods should be called when disabled")
    }
    
    // Test invalid event data
    func testInvalidEventData() {
        // Create a custom subclass for testing
        class TestTouchEventController: TouchEventController {
            var methodCalled = false
            
            override init() {
                super.init()
            }
            
            func reset() {
                methodCalled = false
            }
            
            override func simulateMouseDown(at position: CGPoint) {
                methodCalled = true
            }
        }
        
        // Use the test subclass
        let testController = TestTouchEventController()
        testController.isEnabled = true
        
        // Missing event data
        let missingDataEvent: [String: Any] = [:]
        testController.processTouchEvent(missingDataEvent)
        XCTAssertFalse(testController.methodCalled, "No methods should be called with missing event data")
        
        // Reset
        testController.reset()
        
        // Missing coordinates
        let missingCoordinatesEvent: [String: Any] = [
            "event": [
                "type": "began"
            ]
        ]
        testController.processTouchEvent(missingCoordinatesEvent)
        XCTAssertFalse(testController.methodCalled, "No methods should be called with missing coordinates")
        
        // Reset
        testController.reset()
        
        // Invalid event type
        let invalidTypeEvent: [String: Any] = [
            "event": [
                "type": "invalid",
                "percentX": 0.5,
                "percentY": 0.5
            ]
        ]
        testController.processTouchEvent(invalidTypeEvent)
        XCTAssertFalse(testController.methodCalled, "No methods should be called with invalid event type")
    }
} 