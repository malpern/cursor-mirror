import XCTest
import SwiftUI
import CloudKit
@testable import CursorMirrorClient

final class UIWorkflowTests: XCTestCase {
    
    var mockViewModel: TestConnectionViewModel!
    var contentView: ContentView?
    
    override func setUp() {
        super.setUp()
        
        // Create a mock view model with pre-populated devices
        mockViewModel = TestConnectionViewModel()
        
        // Add mock devices
        let recordID1 = CKRecord.ID(recordName: "device1")
        let device1 = DeviceInfo(id: "device1", name: "Mac Studio", recordID: recordID1)
        let recordID2 = CKRecord.ID(recordName: "device2")
        let device2 = DeviceInfo(id: "device2", name: "MacBook Pro", recordID: recordID2)
        mockViewModel.connectionState.updateDiscoveredDevices([device1, device2])
        
        // Setup mock stream URL
        mockViewModel.shouldProvideStreamURL = true
        mockViewModel.providedStreamURL = URL(string: "http://test.com/stream")
        
        // Clear any settings from previous tests
        let testDefaults = UserDefaults.standard
        testDefaults.removeObject(forKey: "streamQuality")
        testDefaults.removeObject(forKey: "bufferSize")
        testDefaults.synchronize()
    }
    
    override func tearDown() {
        mockViewModel = nil
        contentView = nil
        
        // Clean up settings
        let testDefaults = UserDefaults.standard
        testDefaults.removeObject(forKey: "streamQuality")
        testDefaults.removeObject(forKey: "bufferSize")
        testDefaults.synchronize()
        
        super.tearDown()
    }
    
    // Test the full user workflow: discover devices, connect to a device, 
    // play the stream, change settings, disconnect
    func testFullUserWorkflow() {
        // 1. Test discovering devices
        XCTAssertEqual(mockViewModel.connectionState.discoveredDevices.count, 2)
        
        // 2. Test connecting to a device
        let deviceToConnect = mockViewModel.connectionState.discoveredDevices.first!
        let deviceHelper = DeviceWorkflowHelper(viewModel: mockViewModel)
        deviceHelper.connectToDevice(deviceToConnect)
        
        // Verify connection
        XCTAssertTrue(mockViewModel.connectToDeviceCalled)
        XCTAssertEqual(mockViewModel.connectionState.status, ConnectionStatus.connected)
        XCTAssertEqual(mockViewModel.connectionState.selectedDevice?.id, deviceToConnect.id)
        
        // 3. Test streaming
        let streamHelper = StreamWorkflowHelper(viewModel: mockViewModel)
        let streamURL = streamHelper.getStreamURL()
        
        // Verify stream URL
        XCTAssertNotNil(streamURL)
        
        // 4. Test changing settings
        let settingsHelper = SettingsWorkflowHelper()
        
        // Get default settings
        let defaultConfig = settingsHelper.getStreamConfig()
        XCTAssertEqual(defaultConfig.quality, .auto)
        
        // Change settings
        let customConfig = settingsHelper.getStreamConfig()
        customConfig.quality = .high
        customConfig.bufferSize = 5.0
        customConfig.saveConfiguration()
        
        // Verify changed settings
        let savedConfig = settingsHelper.getStreamConfig(skipClear: true)
        XCTAssertEqual(savedConfig.quality, .high)
        XCTAssertEqual(savedConfig.bufferSize, 5.0)
        
        // 5. Test disconnecting
        deviceHelper.disconnect()
        
        // Verify disconnection
        XCTAssertTrue(mockViewModel.disconnectCalled)
        XCTAssertEqual(mockViewModel.connectionState.status, ConnectionStatus.disconnected)
        XCTAssertNil(mockViewModel.connectionState.selectedDevice)
    }
    
    // Test error handling across the UI
    func testErrorHandlingWorkflow() {
        // Simulate an error
        let testError = NSError(domain: "com.test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        mockViewModel.connectionState.handleError(testError)
        
        // Verify error state
        XCTAssertEqual(mockViewModel.connectionState.status, ConnectionStatus.error)
        XCTAssertNotNil(mockViewModel.connectionState.lastError)
        
        // Clear error
        let errorHelper = ErrorWorkflowHelper(viewModel: mockViewModel)
        errorHelper.clearError()
        
        // Verify error cleared
        XCTAssertTrue(mockViewModel.clearErrorCalled)
        XCTAssertNil(mockViewModel.connectionState.lastError)
    }
}

// MARK: - Workflow Helpers

class DeviceWorkflowHelper {
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func connectToDevice(_ device: DeviceInfo) {
        viewModel.connectToDevice(device)
    }
    
    func disconnect() {
        viewModel.disconnect()
    }
}

class StreamWorkflowHelper {
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func getStreamURL() -> URL? {
        return viewModel.getStreamURL()
    }
}

class SettingsWorkflowHelper {
    func getStreamConfig(skipClear: Bool = false) -> StreamConfig {
        return StreamConfig(skipDefaultsClear: skipClear)
    }
}

class ErrorWorkflowHelper {
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func clearError() {
        viewModel.clearError()
    }
} 