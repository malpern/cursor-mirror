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
        
        // Check if the selected display is the main display
        // Note: SCDisplay doesn't have an isMainDisplay property directly
        // We'll check if it's the first display instead, which is typically the main one
        if let firstDisplay = configuration.displays.first {
            XCTAssertEqual(configuration.selectedDisplay, firstDisplay)
        }
        
        // Verify windows were loaded (may be empty if no windows are open)
        XCTAssertNotNil(configuration.windows)
    }
    
    func testCreateFilter() async throws {
        // Update displays first
        try await configuration.updateDisplays()
        
        // Create filter
        let filter = configuration.createFilter()
        
        // Verify filter is created
        XCTAssertNotNil(filter)
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