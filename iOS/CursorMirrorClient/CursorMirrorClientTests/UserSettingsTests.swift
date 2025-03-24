import XCTest
import SwiftUI
@testable import CursorMirrorClient

final class UserSettingsTests: XCTestCase {
    
    // Temporary UserSettings instance for testing
    var sut: UserSettings!
    let testKey = "com.cursormirror.testSettings"
    
    override func setUp() {
        super.setUp()
        // Create a test instance with a different key to not interfere with the app's settings
        sut = UserSettingsForTest(settingsKey: testKey)
    }
    
    override func tearDown() {
        // Clear test data
        UserDefaults.standard.removeObject(forKey: testKey)
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initial Values Tests
    
    func testDefaultValues() {
        // Verify default values are set correctly
        XCTAssertFalse(sut.autoConnect)
        XCTAssertEqual(sut.connectionTimeout, 30.0)
        XCTAssertEqual(sut.maxReconnectionAttempts, 3)
        XCTAssertTrue(sut.rememberLastDevice)
        
        XCTAssertEqual(sut.defaultQuality, .auto)
        XCTAssertEqual(sut.maxBandwidthUsage, 0.0)
        XCTAssertEqual(sut.bufferSize, 3.0)
        XCTAssertTrue(sut.enableAdaptiveBitrate)
        
        XCTAssertTrue(sut.enableTouchControls)
        XCTAssertEqual(sut.touchSensitivity, 1.0)
        XCTAssertTrue(sut.showTouchIndicator)
        
        XCTAssertNil(sut.preferredColorScheme)
        XCTAssertEqual(sut.interfaceOpacity, 0.8)
        
        // Can't directly test Color equality easily due to how SwiftUI colors work
    }
    
    // MARK: - Persistence Tests
    
    func testPersistenceAndReloading() {
        // Change some settings
        sut.autoConnect = true
        sut.connectionTimeout = 45.0
        sut.defaultQuality = .high
        sut.enableTouchControls = false
        sut.touchSensitivity = 1.5
        
        // Verify values are updated
        XCTAssertTrue(sut.autoConnect)
        XCTAssertEqual(sut.connectionTimeout, 45.0)
        XCTAssertEqual(sut.defaultQuality, .high)
        XCTAssertFalse(sut.enableTouchControls)
        XCTAssertEqual(sut.touchSensitivity, 1.5)
        
        // Create a new instance (which should load from UserDefaults)
        let reloadedSettings = UserSettingsForTest(settingsKey: testKey)
        
        // Verify the new instance has the saved values
        XCTAssertTrue(reloadedSettings.autoConnect)
        XCTAssertEqual(reloadedSettings.connectionTimeout, 45.0)
        XCTAssertEqual(reloadedSettings.defaultQuality, .high)
        XCTAssertFalse(reloadedSettings.enableTouchControls)
        XCTAssertEqual(reloadedSettings.touchSensitivity, 1.5)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Change some settings
        sut.autoConnect = true
        sut.connectionTimeout = 45.0
        sut.defaultQuality = .high
        sut.enableTouchControls = false
        
        // Reset to defaults
        sut.resetToDefaults()
        
        // Verify reset was successful
        XCTAssertFalse(sut.autoConnect)
        XCTAssertEqual(sut.connectionTimeout, 30.0)
        XCTAssertEqual(sut.defaultQuality, .auto)
        XCTAssertTrue(sut.enableTouchControls)
    }
    
    // MARK: - Color Scheme Tests
    
    func testColorScheme() {
        // Default is nil (system)
        XCTAssertNil(sut.preferredColorScheme)
        
        // Set to light
        sut.preferredColorScheme = .light
        XCTAssertEqual(sut.preferredColorScheme, .light)
        
        // Create a new instance to test persistence
        let reloadedSettings = UserSettingsForTest(settingsKey: testKey)
        XCTAssertEqual(reloadedSettings.preferredColorScheme, .light)
        
        // Set to dark
        sut.preferredColorScheme = .dark
        XCTAssertEqual(sut.preferredColorScheme, .dark)
        
        // Set back to system (nil)
        sut.preferredColorScheme = nil
        XCTAssertNil(sut.preferredColorScheme)
    }
}

// Test-specific subclass to override the settings key
class UserSettingsForTest: UserSettings {
    init(settingsKey: String) {
        super.init()
        self.settingsKey = settingsKey
        load() // Reload with new key
    }
} 