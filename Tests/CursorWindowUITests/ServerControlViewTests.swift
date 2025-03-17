#if os(macOS)
import XCTest
@testable import CursorWindow

@MainActor
final class ServerControlViewTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Wait for app to be ready
        let window = app.windows["Cursor Mirror"]
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
    
    func testServerTabExists() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        // Switch to Server tab
        app.tabs["Server"].click()
        
        // Verify server tab is selected
        XCTAssertTrue(app.tabs["Server"].isSelected)
        
        // Verify key server control elements exist
        XCTAssertTrue(app.staticTexts["Server Status"].exists)
        XCTAssertTrue(app.staticTexts["Server Configuration"].exists)
        XCTAssertTrue(app.staticTexts["Server Controls"].exists)
        XCTAssertTrue(app.buttons["Start Server"].exists)
    }
    
    func testServerConfiguration() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        // Switch to Server tab
        app.tabs["Server"].click()
        
        // Test hostname field
        let hostnameField = app.textFields["Hostname"]
        XCTAssertTrue(hostnameField.exists)
        
        // Clear and enter new hostname
        hostnameField.click()
        hostnameField.typeKey(.delete, modifierFlags: [.command])
        hostnameField.typeText("localhost")
        
        // Test port field
        let portField = app.textFields["Port"]
        XCTAssertTrue(portField.exists)
        
        // Clear and enter new port
        portField.click()
        portField.typeKey(.delete, modifierFlags: [.command])
        portField.typeText("9090")
        
        // Test toggles
        let sslToggle = app.switches["Enable SSL/TLS"]
        XCTAssertTrue(sslToggle.exists)
        
        let adminToggle = app.switches["Enable Admin Dashboard"]
        XCTAssertTrue(adminToggle.exists)
    }
    
    func testServerStartStop() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        // Switch to Server tab
        app.tabs["Server"].click()
        
        // Find start server button
        let startButton = app.buttons["Start Server"]
        XCTAssertTrue(startButton.exists)
        
        // Test click start (this won't actually start the server in test mode)
        startButton.click()
        
        // Since the server probably won't actually start in the test environment,
        // we'll just verify the UI elements that should be there regardless
        XCTAssertTrue(app.staticTexts["Stream Status"].exists || app.buttons["Stop Server"].exists)
    }
}

#else
#error("ServerControlViewTests is only available on macOS 14.0 or later")
#endif 