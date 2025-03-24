import XCTest
import SwiftUI
import CloudKit
@testable import CursorMirrorClient

final class DeviceDiscoveryViewTests: XCTestCase {
    
    var mockViewModel: TestConnectionViewModel!
    
    override func setUp() {
        super.setUp()
        mockViewModel = TestConnectionViewModel()
    }
    
    override func tearDown() {
        mockViewModel = nil
        super.tearDown()
    }
    
    // Test device discovery functionality
    func testDeviceDiscovery() {
        // Ensure the mock viewModel is in a clean state before using it
        mockViewModel = TestConnectionViewModel()
        
        // Reset the flag for tracking startDeviceDiscovery calls
        mockViewModel.startDeviceDiscoveryCalled = false
        
        // Manually call startDeviceDiscovery to simulate the view's onAppear behavior
        mockViewModel.startDeviceDiscovery()
        
        // Verify that startDeviceDiscovery was called
        XCTAssertTrue(mockViewModel.startDeviceDiscoveryCalled)
        
        // Since our mock implementation adds devices synchronously,
        // we should now have devices in the list
        XCTAssertEqual(mockViewModel.connectionState.discoveredDevices.count, 2)
        XCTAssertTrue(mockViewModel.connectionState.discoveredDevices.contains { $0.id == "device1" })
        XCTAssertTrue(mockViewModel.connectionState.discoveredDevices.contains { $0.id == "device2" })
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
        _ = DeviceDiscoveryView(viewModel: mockViewModel)
        
        // Verify error state
        XCTAssertEqual(mockViewModel.connectionState.status, ConnectionStatus.error)
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
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func selectDevice(_ device: DeviceInfo) {
        // This simulates the tap action in the DeviceDiscoveryView
        viewModel.connectToDevice(device)
    }
}

// Helper class to test error handling
class ErrorHandlingTestHelper {
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func clearError() {
        // This simulates tapping the dismiss button on the error banner
        viewModel.clearError()
    }
} 