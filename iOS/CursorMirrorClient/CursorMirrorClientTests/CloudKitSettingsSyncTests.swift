import XCTest
@testable import CursorMirrorClient

class CloudKitSettingsSyncTests: XCTestCase {
    
    var userSettings: UserSettings!
    var mockCloudSync: MockCloudKitSettingsSync!
    
    override func setUp() {
        super.setUp()
        mockCloudSync = MockCloudKitSettingsSync()
        userSettings = UserSettings(cloudSync: mockCloudSync)
    }
    
    override func tearDown() {
        mockCloudSync = nil
        userSettings = nil
        super.tearDown()
    }
    
    // MARK: - Basic CloudSync Tests
    
    func testCloudSyncEnabled() {
        // Verify cloud sync is enabled by default
        XCTAssertTrue(userSettings.enableCloudSync)
        
        // Change a setting to trigger a save/sync
        userSettings.accentColor = .red
        
        // Wait for async operation to complete
        let expectation = XCTestExpectation(description: "Cloud sync called")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify sync was called
        XCTAssertTrue(mockCloudSync.syncCalled)
    }
    
    func testCloudSyncDisabled() {
        // Disable cloud sync
        userSettings.enableCloudSync = false
        
        // Reset the mock
        mockCloudSync.reset()
        
        // Change a setting to trigger a save/sync
        userSettings.accentColor = .green
        
        // Wait for async operation to complete
        let expectation = XCTestExpectation(description: "Cloud sync not called")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify sync was not called
        XCTAssertFalse(mockCloudSync.syncCalled)
    }
    
    func testForceSync() {
        // Reset the mock
        mockCloudSync.reset()
        
        // Simulate clicking the "Force Sync Now" button
        userSettings.syncLastAttempted = Date()
        
        // Wait for async operation to complete
        let expectation = XCTestExpectation(description: "Force sync called")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify sync was called
        XCTAssertTrue(mockCloudSync.syncCalled)
    }
    
    // MARK: - Device Specific Settings Tests
    
    func testDeviceSpecificSettingsEnabled() {
        // Verify device-specific settings are enabled by default
        XCTAssertTrue(userSettings.deviceSpecificSettings)
        
        // Create a custom UserDefaults for testing
        let defaults = UserDefaults(suiteName: "testDeviceSpecificSettings")!
        defaults.removePersistentDomain(forName: "testDeviceSpecificSettings")
        
        // Set a unique settings key for testing
        let settings = UserSettings(cloudSync: mockCloudSync)
        settings.settingsKey = "test.settings.key"
        
        // Save settings
        settings.accentColor = .blue
        
        // Verify the key used for saving includes the device ID
        XCTAssertTrue(settings.deviceSpecificSettingsKey.contains(settings.settingsKey))
    }
    
    func testToggleDeviceSpecificSettings() {
        // Initially enabled
        XCTAssertTrue(userSettings.deviceSpecificSettings)
        
        // Toggle off
        userSettings.toggleDeviceSpecificSettings()
        XCTAssertFalse(userSettings.deviceSpecificSettings)
        
        // Toggle back on
        userSettings.toggleDeviceSpecificSettings()
        XCTAssertTrue(userSettings.deviceSpecificSettings)
    }
    
    // MARK: - Error Handling Tests
    
    func testSyncError() {
        // Configure mock to fail on sync
        mockCloudSync.shouldFailSync = true
        
        // Trigger sync
        userSettings.accentColor = .yellow
        
        // Wait for async operation to complete
        let expectation = XCTestExpectation(description: "Sync error handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify sync was attempted but failed
        XCTAssertTrue(mockCloudSync.syncCalled)
        XCTAssertNil(userSettings.syncLastSuccessful)
    }
    
    func testLoadError() {
        // Configure mock to fail on load
        mockCloudSync.shouldFailLoad = true
        
        // Trigger load from cloud
        userSettings.load()
        
        // Wait for async operation to complete
        let expectation = XCTestExpectation(description: "Load error handled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify load was attempted
        XCTAssertTrue(mockCloudSync.loadCalled)
    }
    
    // MARK: - Reset Tests
    
    func testResetToDefaults() {
        // Change some settings
        userSettings.accentColor = .purple
        userSettings.enableTouchControls = false
        
        // Reset the mock
        mockCloudSync.reset()
        
        // Reset settings to defaults
        userSettings.resetToDefaults()
        
        // Wait for async operation to complete
        let expectation = XCTestExpectation(description: "Delete called after reset")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify delete was called to remove cloud settings
        XCTAssertTrue(mockCloudSync.deleteCalled)
        
        // Verify settings were reset
        XCTAssertEqual(userSettings.accentColor, .blue)
        XCTAssertTrue(userSettings.enableTouchControls)
    }
} 