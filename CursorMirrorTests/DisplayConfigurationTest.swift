import XCTest
import ScreenCaptureKit
@testable import cursor_window

@MainActor
final class DisplayConfigurationTests: XCTestCase {
    var configuration: DisplayConfiguration!
    
    override func setUp() async throws {
        try await super.setUp()
        configuration = DisplayConfiguration()
    }
    
    override func tearDown() async throws {
        configuration = nil
        try await super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(configuration.displays.isEmpty)
        XCTAssertNil(configuration.selectedDisplay)
        XCTAssertTrue(configuration.windows.isEmpty)
        XCTAssertNil(configuration.error)
    }
    
    func testUpdateDisplays() async throws {
        // Update displays
        try await configuration.updateDisplays()
        
        // Verify we have at least one display (the main display)
        XCTAssertFalse(configuration.displays.isEmpty)
        
        // Verify the main display is selected by default
        XCTAssertNotNil(configuration.selectedDisplay)
        XCTAssertTrue(configuration.selectedDisplay?.isMainDisplay ?? false)
        
        // Verify windows were loaded (may be empty if no windows are open)
        XCTAssertNotNil(configuration.windows)
    }
    
    func testCreateFilter() async throws {
        // Update displays first
        try await configuration.updateDisplays()
        
        // Create filter
        let filter = configuration.createFilter()
        
        // Verify filter is created with the main display
        XCTAssertNotNil(filter)
        
        // Get the display from the filter using private API
        // Note: This is not ideal for production tests, but helps verify our implementation
        let display = filter.value(forKey: "display") as? SCDisplay
        XCTAssertNotNil(display)
        XCTAssertTrue(display?.isMainDisplay ?? false)
    }
    
    func testWindowFiltering() async throws {
        // Update displays and windows
        try await configuration.updateDisplays()
        
        // Verify our app's windows are not included
        let ourWindows = configuration.windows.filter { window in
            window.owningApplication?.bundleIdentifier.contains("cursor-window") ?? false
        }
        XCTAssertTrue(ourWindows.isEmpty)
    }
}
