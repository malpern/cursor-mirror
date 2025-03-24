import XCTest
import SwiftUI
import CloudKit
@testable import CursorMirrorClient

final class SettingsViewTests: XCTestCase {
    
    var mockViewModel: TestConnectionViewModel!
    
    override func setUp() {
        super.setUp()
        mockViewModel = TestConnectionViewModel()
        
        // Clear any settings from previous tests
        let testDefaults = UserDefaults.standard
        testDefaults.removeObject(forKey: "streamQuality")
        testDefaults.removeObject(forKey: "bufferSize")
        testDefaults.synchronize()
    }
    
    override func tearDown() {
        mockViewModel = nil
        
        // Clean up settings
        let testDefaults = UserDefaults.standard
        testDefaults.removeObject(forKey: "streamQuality")
        testDefaults.removeObject(forKey: "bufferSize")
        testDefaults.synchronize()
        
        super.tearDown()
    }
    
    // Test initial state with default settings
    func testDefaultSettings() {
        // Create the view
        _ = SettingsView(viewModel: mockViewModel)
        
        // Create a test helper to inspect settings
        let helper = SettingsTestHelper()
        
        // Verify default values
        XCTAssertEqual(helper.getStreamConfig().quality, .auto)
        XCTAssertEqual(helper.getStreamConfig().bufferSize, StreamConfig.defaultBufferSize)
        XCTAssertTrue(helper.getStreamConfig().isAutoQualityEnabled)
    }
    
    // Test saving custom settings
    func testSaveSettings() {
        // Create a test helper
        let helper = SettingsTestHelper()
        
        // Set and save custom values
        let config = StreamConfig()
        config.quality = .high
        config.bufferSize = 5.0
        config.saveConfiguration()
        
        // Create a new configuration instance to load saved values
        let loadedConfig = helper.getStreamConfig(skipClear: true)
        
        // Verify saved values
        XCTAssertEqual(loadedConfig.quality, .high)
        XCTAssertEqual(loadedConfig.bufferSize, 5.0)
        XCTAssertFalse(loadedConfig.isAutoQualityEnabled)
    }
    
    // Test reset to defaults
    func testResetToDefaults() {
        // Create a test helper
        let helper = SettingsTestHelper()
        
        // Set custom values
        let config = StreamConfig()
        config.quality = .high
        config.bufferSize = 5.0
        config.saveConfiguration()
        
        // Verify custom values were saved
        let loadedConfig = helper.getStreamConfig(skipClear: true)
        XCTAssertEqual(loadedConfig.quality, .high)
        XCTAssertEqual(loadedConfig.bufferSize, 5.0)
        
        // Reset to defaults
        loadedConfig.resetToDefaults()
        
        // Load a new instance to verify reset
        let resetConfig = helper.getStreamConfig(skipClear: true)
        XCTAssertEqual(resetConfig.quality, .auto)
        XCTAssertEqual(resetConfig.bufferSize, StreamConfig.defaultBufferSize)
        XCTAssertTrue(resetConfig.isAutoQualityEnabled)
    }
    
    // Test connection status display
    func testConnectionStatusDisplay() {
        // Setup a mock connection
        let recordID = CKRecord.ID(recordName: "test-id")
        let device = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID)
        mockViewModel.connectionState.selectDevice(device)
        mockViewModel.connectionState.status = ConnectionStatus.connected
        
        // Create the view
        _ = SettingsView(viewModel: mockViewModel)
        
        // Verify connection status
        XCTAssertEqual(mockViewModel.connectionState.status, ConnectionStatus.connected)
        XCTAssertEqual(mockViewModel.connectionState.selectedDevice?.id, "test-id")
        
        // Create helper to test disconnect action
        let helper = SettingsConnectionHelper(viewModel: mockViewModel)
        
        // Test disconnect action
        helper.disconnect()
        
        // Verify disconnection
        XCTAssertTrue(mockViewModel.disconnectCalled)
        XCTAssertEqual(mockViewModel.connectionState.status, ConnectionStatus.disconnected)
        XCTAssertNil(mockViewModel.connectionState.selectedDevice)
    }
}

// MARK: - Test Helpers

class SettingsTestHelper {
    func getStreamConfig(skipClear: Bool = false) -> StreamConfig {
        return StreamConfig(skipDefaultsClear: skipClear)
    }
}

class SettingsConnectionHelper {
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func disconnect() {
        viewModel.disconnect()
    }
} 