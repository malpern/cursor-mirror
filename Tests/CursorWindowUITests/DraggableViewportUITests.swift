#if os(macOS)
import XCTest
@testable import CursorWindow

@available(macOS 14.0, *)
final class DraggableViewportUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDown() async throws {
        app.terminate()
        app = nil
    }
    
    func testViewportInitialState() throws {
        // Verify the viewport window exists
        let viewportWindow = app.windows["CursorWindow"]
        XCTAssertTrue(viewportWindow.exists)
        
        // Verify the viewport has the correct dimensions
        let viewport = viewportWindow.groups["DraggableViewport"]
        XCTAssertTrue(viewport.exists)
        
        // Get the frame and verify dimensions (iPhone 15 Pro dimensions: 393x852)
        let frame = viewport.frame
        XCTAssertEqual(Int(frame.width), 393)
        XCTAssertEqual(Int(frame.height), 852)
    }
    
    func testViewportDragging() throws {
        let viewportWindow = app.windows["CursorWindow"]
        let viewport = viewportWindow.groups["DraggableViewport"]
        
        // Get initial position
        let initialFrame = viewport.frame
        
        // Perform drag operation
        viewport.press(forDuration: 0.5, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 100, dy: 100)))
        
        // Get new position
        let newFrame = viewport.frame
        
        // Verify the viewport moved
        XCTAssertNotEqual(initialFrame.origin.x, newFrame.origin.x)
        XCTAssertNotEqual(initialFrame.origin.y, newFrame.origin.y)
        
        // Verify dimensions remained unchanged
        XCTAssertEqual(Int(newFrame.width), 393)
        XCTAssertEqual(Int(newFrame.height), 852)
    }
    
    func testViewportStaysOnScreen() throws {
        let viewportWindow = app.windows["CursorWindow"]
        let viewport = viewportWindow.groups["DraggableViewport"]
        
        // Try to drag viewport off screen to the left
        viewport.press(forDuration: 0.5, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: -1000, dy: 0)))
        
        // Verify viewport is still visible on screen
        XCTAssertTrue(viewport.isHittable)
        XCTAssertGreaterThanOrEqual(viewport.frame.origin.x, 0)
        
        // Try to drag viewport off screen to the top
        viewport.press(forDuration: 0.5, thenDragTo: viewport.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: -1000)))
        
        // Verify viewport is still visible on screen
        XCTAssertTrue(viewport.isHittable)
        XCTAssertGreaterThanOrEqual(viewport.frame.origin.y, 0)
    }
    
    func testViewportKeyboardShortcuts() throws {
        let viewportWindow = app.windows["CursorWindow"]
        let viewport = viewportWindow.groups["DraggableViewport"]
        
        // Get initial position
        let initialFrame = viewport.frame
        
        // Move viewport with arrow keys
        viewport.typeKey(.rightArrow, modifierFlags: [.command])
        
        // Get new position
        var newFrame = viewport.frame
        
        // Verify viewport moved right
        XCTAssertGreaterThan(newFrame.origin.x, initialFrame.origin.x)
        
        // Move viewport with arrow keys
        viewport.typeKey(.leftArrow, modifierFlags: [.command])
        
        // Get final position
        newFrame = viewport.frame
        
        // Verify viewport moved back
        XCTAssertEqual(newFrame.origin.x, initialFrame.origin.x)
    }
    
    func testViewportMenuBarInteractions() throws {
        // Click the menu bar item
        let menuBarsQuery = app.menuBars
        menuBarsQuery.menuBarItems["View"].click()
        
        // Verify menu items exist
        let resetPositionMenuItem = menuBarsQuery.menuItems["Reset Position"]
        XCTAssertTrue(resetPositionMenuItem.exists)
        
        // Click reset position
        resetPositionMenuItem.click()
        
        // Verify viewport is at default position
        let viewport = app.windows["CursorWindow"].groups["DraggableViewport"]
        let frame = viewport.frame
        
        // Default position should be center of main screen
        let screen = NSScreen.main!.frame
        let expectedX = (screen.width - 393) / 2
        let expectedY = (screen.height - 852) / 2
        
        XCTAssertEqual(Int(frame.origin.x), Int(expectedX), accuracy: 1)
        XCTAssertEqual(Int(frame.origin.y), Int(expectedY), accuracy: 1)
    }
}
#endif 