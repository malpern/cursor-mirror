import XCTest
import SwiftUI
@testable import CursorMirrorClient

final class SettingsViewTests: XCTestCase {
    
    // Test settings for UI testing
    var testSettings: UserSettings!
    
    override func setUp() {
        super.setUp()
        // Create a test UserSettings to avoid interfering with app settings
        testSettings = UserSettingsForTest(settingsKey: "com.cursormirror.uiTestSettings")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "com.cursormirror.uiTestSettings")
        testSettings = nil
        super.tearDown()
    }
    
    // Test that SettingsView creates the correct sections
    func testSettingsSectionsCreation() {
        // Given all possible settings sections
        let allSections = SettingsView.SettingsSection.allCases
        
        // Then we should have exactly 4 sections
        XCTAssertEqual(allSections.count, 4)
        
        // And they should match our expected values
        XCTAssertEqual(allSections[0].rawValue, "Connection")
        XCTAssertEqual(allSections[1].rawValue, "Video")
        XCTAssertEqual(allSections[2].rawValue, "Touch Controls")
        XCTAssertEqual(allSections[3].rawValue, "Appearance")
    }
    
    // Test that section icons are correctly assigned
    func testSectionIcons() {
        // Test each section has the correct icon
        XCTAssertEqual(SettingsView.SettingsSection.connection.icon, "network")
        XCTAssertEqual(SettingsView.SettingsSection.video.icon, "film")
        XCTAssertEqual(SettingsView.SettingsSection.touch.icon, "hand.tap")
        XCTAssertEqual(SettingsView.SettingsSection.appearance.icon, "paintpalette")
    }
} 