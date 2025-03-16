#if os(macOS)
import XCTest
@testable import CursorWindow

@MainActor
final class MainViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDown() async throws {
        if app != nil {
            app.terminate()
            app = nil
        }
    }
    
    func testMainViewExists() async throws {
        guard NSApplication.shared.isRunning else {
            throw XCTSkip("UI tests require a running application")
        }
        
        let mainView = app.windows["CursorWindow"]
        let exists = mainView.waitForExistence(timeout: 5)
        XCTAssertTrue(exists, "Main window should exist within 5 seconds")
        
        // Additional checks for window properties
        XCTAssertTrue(mainView.isEnabled, "Main window should be enabled")
        XCTAssertTrue(mainView.isHittable, "Main window should be hittable")
        
        // Check window dimensions
        let frame = mainView.frame
        XCTAssertGreaterThan(frame.width, 0, "Window width should be greater than 0")
        XCTAssertGreaterThan(frame.height, 0, "Window height should be greater than 0")
    }
    
    func testMainViewInitialState() throws {
        // Verify the main window exists
        let mainWindow = app.windows["CursorWindow"]
        XCTAssertTrue(mainWindow.exists)
        
        // Verify the tab view exists
        let tabView = mainWindow.tabGroups.firstMatch
        XCTAssertTrue(tabView.exists)
        
        // Verify both tabs exist
        let previewTab = mainWindow.tabs["Preview"]
        let encodingTab = mainWindow.tabs["Encoding"]
        XCTAssertTrue(previewTab.exists)
        XCTAssertTrue(encodingTab.exists)
        
        // Verify preview tab is selected by default
        XCTAssertTrue(previewTab.isSelected)
    }
    
    func testTabSwitching() throws {
        let mainWindow = app.windows["CursorWindow"]
        
        // Switch to encoding tab
        mainWindow.tabs["Encoding"].click()
        
        // Verify encoding tab is selected
        XCTAssertTrue(mainWindow.tabs["Encoding"].isSelected)
        XCTAssertFalse(mainWindow.tabs["Preview"].isSelected)
        
        // Switch back to preview tab
        mainWindow.tabs["Preview"].click()
        
        // Verify preview tab is selected
        XCTAssertTrue(mainWindow.tabs["Preview"].isSelected)
        XCTAssertFalse(mainWindow.tabs["Encoding"].isSelected)
    }
    
    func testEncodingControls() throws {
        let mainWindow = app.windows["CursorWindow"]
        
        // Switch to encoding tab
        mainWindow.tabs["Encoding"].click()
        
        // Verify encoding controls exist
        let startButton = mainWindow.buttons["Start Encoding"]
        XCTAssertTrue(startButton.exists)
        XCTAssertTrue(startButton.isEnabled)
        
        // Click start encoding
        startButton.click()
        
        // Verify button text changes
        XCTAssertEqual(startButton.title, "Stop Encoding")
        
        // Click stop encoding
        startButton.click()
        
        // Verify button text changes back
        XCTAssertEqual(startButton.title, "Start Encoding")
    }
    
    func testEncodingSettings() throws {
        let mainWindow = app.windows["CursorWindow"]
        
        // Switch to encoding tab
        mainWindow.tabs["Encoding"].click()
        
        // Verify settings controls exist
        let frameRateSlider = mainWindow.sliders["Frame Rate"]
        let bitrateSlider = mainWindow.sliders["Bitrate"]
        
        XCTAssertTrue(frameRateSlider.exists)
        XCTAssertTrue(bitrateSlider.exists)
        
        // Adjust frame rate
        frameRateSlider.adjust(toNormalizedSliderPosition: 0.5)
        
        // Verify frame rate value updated
        let frameRateValue = mainWindow.staticTexts.matching(identifier: "Frame Rate Value").firstMatch
        XCTAssertTrue(frameRateValue.exists)
        XCTAssertNotEqual(frameRateValue.label, "30 fps") // Default value should have changed
    }
    
    func testPermissionPrompt() throws {
        let mainWindow = app.windows["CursorWindow"]
        
        // Switch to preview tab
        mainWindow.tabs["Preview"].click()
        
        // Verify permission button exists when needed
        if app.buttons["Request Permission"].exists {
            let permissionButton = app.buttons["Request Permission"]
            XCTAssertTrue(permissionButton.isEnabled)
            
            // Note: We can't actually test clicking the button as it would trigger
            // a system permission dialog that we can't interact with in UI tests
        }
    }
    
    func testPreviewControls() throws {
        let mainWindow = app.windows["CursorWindow"]
        
        // Switch to preview tab
        mainWindow.tabs["Preview"].click()
        
        // Verify preview controls exist
        let previewToggle = mainWindow.checkBoxes["Enable Preview"]
        XCTAssertTrue(previewToggle.exists)
        
        // Toggle preview
        previewToggle.click()
        
        // Verify preview state changed
        XCTAssertTrue(previewToggle.isSelected)
        
        // Toggle preview back
        previewToggle.click()
        
        // Verify preview state changed back
        XCTAssertFalse(previewToggle.isSelected)
    }
}
#endif 