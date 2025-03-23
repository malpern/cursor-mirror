import XCTest
import CursorWindowCore
import AppKit
import SwiftUI

final class ViewportTests: XCTestCase {
    var viewportManager: ViewportManager!
    
    override func setUp() {
        super.setUp()
        viewportManager = ViewportManager {
            AnyView(Text("Test View"))
        }
        // Ensure we start with a clean state
        UserDefaults.standard.removeObject(forKey: "com.cursor-window.viewport.position.x")
        UserDefaults.standard.removeObject(forKey: "com.cursor-window.viewport.position.y")
        viewportManager.showViewport()
    }
    
    override func tearDown() {
        viewportManager.hideViewport()
        viewportManager = nil
        // Clean up saved position
        UserDefaults.standard.removeObject(forKey: "com.cursor-window.viewport.position.x")
        UserDefaults.standard.removeObject(forKey: "com.cursor-window.viewport.position.y")
        super.tearDown()
    }
    
    func testWindowMovementSmoothness() async throws {
        // Test window movement with native dragging
        let initialPosition = CGPoint(x: 100, y: 100)
        viewportManager.updatePosition(to: initialPosition)
        
        // Wait for any animations to complete
        try await Task.sleep(for: .milliseconds(100))
        
        // Verify initial position
        XCTAssertEqual(viewportManager.position.x, initialPosition.x, accuracy: 1.0)
        XCTAssertEqual(viewportManager.position.y, initialPosition.y, accuracy: 1.0)
        
        // Test movement with delays to allow for smoothing
        let movements = [
            CGPoint(x: 150, y: 150),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 250, y: 250)
        ]
        
        for position in movements {
            viewportManager.updatePosition(to: position)
            // Wait for movement to complete
            try await Task.sleep(for: .milliseconds(100))
            
            // Verify position with more lenient accuracy due to smoothing
            XCTAssertEqual(viewportManager.position.x, position.x, accuracy: 2.0)
            XCTAssertEqual(viewportManager.position.y, position.y, accuracy: 2.0)
        }
    }
    
    func testWindowBounds() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }
        
        let screenFrame = screen.visibleFrame
        
        // Try to move window outside bounds
        let outOfBoundsPosition = CGPoint(
            x: screenFrame.maxX + 100,
            y: screenFrame.maxY + 100
        )
        
        viewportManager.updatePosition(to: outOfBoundsPosition)
        
        // Verify window was constrained to screen bounds
        XCTAssertLessThanOrEqual(
            viewportManager.position.x,
            screenFrame.maxX - ViewportManager.viewportSize.width,
            "Window should be constrained within screen bounds (x-axis)"
        )
        XCTAssertLessThanOrEqual(
            viewportManager.position.y,
            screenFrame.maxY - ViewportManager.viewportSize.height,
            "Window should be constrained within screen bounds (y-axis)"
        )
    }
    
    func testPositionPersistence() async throws {
        // Test that position is saved when requested
        let testPosition = CGPoint(x: 300, y: 300)
        
        // Ensure position is within screen bounds
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }
        
        let constrainedPosition = CGPoint(
            x: min(testPosition.x, screen.visibleFrame.maxX - ViewportManager.viewportSize.width),
            y: min(testPosition.y, screen.visibleFrame.maxY - ViewportManager.viewportSize.height)
        )
        
        viewportManager.updatePosition(to: constrainedPosition, persistPosition: true)
        
        // Wait for any animations and persistence operations
        try await Task.sleep(for: .milliseconds(100))
        
        // Verify position was saved to UserDefaults
        let savedX = UserDefaults.standard.double(forKey: "com.cursor-window.viewport.position.x")
        let savedY = UserDefaults.standard.double(forKey: "com.cursor-window.viewport.position.y")
        
        XCTAssertEqual(savedX, constrainedPosition.x, accuracy: 2.0)
        XCTAssertEqual(savedY, constrainedPosition.y, accuracy: 2.0)
        
        // Verify actual window position matches saved position
        XCTAssertEqual(viewportManager.position.x, constrainedPosition.x, accuracy: 2.0)
        XCTAssertEqual(viewportManager.position.y, constrainedPosition.y, accuracy: 2.0)
    }
} 