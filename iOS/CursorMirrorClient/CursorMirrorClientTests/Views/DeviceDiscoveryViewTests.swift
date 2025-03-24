import XCTest
import SwiftUI
import CloudKit
@testable import CursorMirrorClient

final class DeviceDiscoveryViewTests: XCTestCase {
    
    var mockViewModel: MockConnectionViewModel!
    
    override func setUp() {
        super.setUp()
        mockViewModel = MockConnectionViewModel()
    }
    
    override func tearDown() {
        mockViewModel = nil
        super.tearDown()
    }
    
    // Test initial state with no devices
    func testEmptyDevicesList() {
        // Create the view with the mock view model
        let view = DeviceDiscoveryView(viewModel: mockViewModel)
        
        // Verify initial state
        XCTAssertTrue(mockViewModel.connectionState.discoveredDevices.isEmpty)
        XCTAssertNil(mockViewModel.connectionState.selectedDevice)
        XCTAssertEqual(mockViewModel.connectionState.status, .disconnected)
        
        // Verify that startDeviceDiscovery was called during onAppear
        XCTAssertTrue(mockViewModel.startDeviceDiscoveryCalled)
    }
    
    // Test device selection
    func testDeviceSelection() {
        // Setup mock devices
        let recordID1 = CKRecord.ID(recordName: "device1")
        let device1 = DeviceInfo(id: "device1", name: "Device 1", recordID: recordID1)
        mockViewModel.connectionState.updateDiscoveredDevices([device1])
        
        // Create the helper to test device selection
        let helper = DeviceSelectionTestHelper(viewModel: mockViewModel)
        
        // Test selecting a device
        helper.selectDevice(device1)
        
        // Verify connection was initiated
        XCTAssertTrue(mockViewModel.connectToDeviceCalled)
        XCTAssertEqual(mockViewModel.lastConnectedDevice?.id, "device1")
    }
    
    // Test error handling
    func testErrorHandling() {
        // Simulate an error state
        let testError = NSError(domain: "com.test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        mockViewModel.connectionState.handleError(testError)
        
        // Create the view with the mock view model in error state
        let view = DeviceDiscoveryView(viewModel: mockViewModel)
        
        // Verify error state
        XCTAssertEqual(mockViewModel.connectionState.status, .error)
        XCTAssertNotNil(mockViewModel.connectionState.lastError)
        
        // Create helper to test error clearing
        let helper = ErrorHandlingTestHelper(viewModel: mockViewModel)
        
        // Test clearing error
        helper.clearError()
        
        // Verify error was cleared
        XCTAssertTrue(mockViewModel.clearErrorCalled)
        XCTAssertNil(mockViewModel.connectionState.lastError)
    }
}

// MARK: - Test Helpers

// Helper class to test device selection without having to test the SwiftUI view directly
class DeviceSelectionTestHelper {
    private let viewModel: MockConnectionViewModel
    
    init(viewModel: MockConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func selectDevice(_ device: DeviceInfo) {
        // This simulates the tap action in the DeviceDiscoveryView
        viewModel.connectToDevice(device)
    }
}

// Helper class to test error handling
class ErrorHandlingTestHelper {
    private let viewModel: MockConnectionViewModel
    
    init(viewModel: MockConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func clearError() {
        // This simulates tapping the dismiss button on the error banner
        viewModel.clearError()
    }
}

// MARK: - Mock View Model

class MockConnectionViewModel: ConnectionViewModel {
    var startDeviceDiscoveryCalled = false
    var connectToDeviceCalled = false
    var clearErrorCalled = false
    var disconnectCalled = false
    var lastConnectedDevice: DeviceInfo?
    
    override func startDeviceDiscovery() {
        startDeviceDiscoveryCalled = true
        // Don't call super to avoid actual cloud operations
    }
    
    override func connectToDevice(_ device: DeviceInfo) {
        connectToDeviceCalled = true
        lastConnectedDevice = device
        
        // Simulate immediate connection for testing
        connectionState.selectDevice(device)
        connectionState.status = .connected
    }
    
    override func clearError() {
        clearErrorCalled = true
        super.clearError()
    }
    
    override func disconnect() {
        disconnectCalled = true
        connectionState.status = .disconnected
        connectionState.selectedDevice = nil
    }
} 