#if os(macOS)
import XCTest
@testable import CursorWindow

@MainActor
final class DraggableViewportUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Wait for app to be ready
        let window = app.windows["CursorWindow"]
        let windowExists = window.waitForExistence(timeout: 5)
        guard windowExists else {
            XCTFail("Main window did not appear")
            return
        }
    }
    
    override func tearDown() async throws {
        if app != nil {
            app.terminate()
            app = nil
        }
    }
    
    func getViewport() throws -> XCUIElement {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        let window = app.windows["CursorWindow"]
        guard window.exists else {
            throw XCTSkip("Window does not exist")
        }
        
        let viewport = window.children(matching: .any)["DraggableViewport"]
        guard viewport.waitForExistence(timeout: 5) else {
            throw XCTSkip("Viewport does not exist")
        }
        
        return viewport
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
    
    func testViewportDragging() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        let viewport = try getViewport()
        
        // Get initial position
        let initialFrame = viewport.frame
        
        // Create coordinates for drag operation
        let start = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7))
        
        // Perform drag operation
        start.press(forDuration: 0.1, thenDragTo: end)
        
        // Wait for animation to complete
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Get new position
        let newFrame = viewport.frame
        
        // Verify viewport has moved
        XCTAssertNotEqual(initialFrame.origin.x, newFrame.origin.x, "Viewport should have moved horizontally")
        XCTAssertNotEqual(initialFrame.origin.y, newFrame.origin.y, "Viewport should have moved vertically")
    }
    
    func testViewportBoundaryConstraints() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        let viewport = try getViewport()
        
        // Create coordinates for drag operations
        let start = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let leftEnd = viewport.coordinate(withNormalizedOffset: CGVector(dx: -0.5, dy: 0.5))
        let topEnd = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -0.5))
        
        // Try to drag viewport off screen to the left
        start.press(forDuration: 0.1, thenDragTo: leftEnd)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify viewport is still visible on screen
        XCTAssertGreaterThanOrEqual(viewport.frame.origin.x, 0, "Viewport should not move off screen to the left")
        
        // Try to drag viewport off screen to the top
        start.press(forDuration: 0.1, thenDragTo: topEnd)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Verify viewport is still visible on screen
        XCTAssertGreaterThanOrEqual(viewport.frame.origin.y, 0, "Viewport should not move off screen to the top")
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