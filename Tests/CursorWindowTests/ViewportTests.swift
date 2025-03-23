import XCTest
import CursorWindowCore
import AppKit

final class ViewportTests: XCTestCase {
    var viewportManager: ViewportManager!
    var window: NSWindow!
    
    override func setUp() {
        super.setUp()
        // Create a simple view factory for testing
        viewportManager = ViewportManager {
            AnyView(Text("Test View"))
        }
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        viewportManager.window = window
    }
    
    override func tearDown() {
        window.close()
        viewportManager = nil
        super.tearDown()
    }
    
    func testWindowMovementSmoothness() {
        // Test window movement with native dragging
        let initialPosition = CGPoint(x: 100, y: 100)
        window.setFrameOrigin(initialPosition)
        
        // Simulate window movement
        let movements = [
            CGPoint(x: 150, y: 150),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 250, y: 250)
        ]
        
        for position in movements {
            window.setFrameOrigin(position)
            
            // Verify position was updated correctly
            XCTAssertEqual(viewportManager.position.x, position.x, accuracy: 0.1)
            XCTAssertEqual(viewportManager.position.y, position.y, accuracy: 0.1)
        }
    }
    
    func testWindowBounds() {
        // Test that window stays within screen bounds
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        
        // Try to move window outside bounds
        let outOfBoundsPosition = CGPoint(
            x: screenFrame.maxX + 100,
            y: screenFrame.maxY + 100
        )
        
        window.setFrameOrigin(outOfBoundsPosition)
        
        // Verify window was constrained to screen bounds
        XCTAssertLessThanOrEqual(viewportManager.position.x, screenFrame.maxX - ViewportManager.viewportSize.width)
        XCTAssertLessThanOrEqual(viewportManager.position.y, screenFrame.maxY - ViewportManager.viewportSize.height)
    }
    
    func testPositionPersistence() {
        // Test that position is saved when requested
        let testPosition = CGPoint(x: 300, y: 300)
        viewportManager.updatePosition(to: testPosition, persistPosition: true)
        
        // Verify position was saved to UserDefaults
        let savedX = UserDefaults.standard.double(forKey: UserDefaultsKeys.viewportPositionX)
        let savedY = UserDefaults.standard.double(forKey: UserDefaultsKeys.viewportPositionY)
        
        XCTAssertEqual(savedX, testPosition.x, accuracy: 0.1)
        XCTAssertEqual(savedY, testPosition.y, accuracy: 0.1)
    }
} 