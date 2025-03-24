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
    
    // Test device filtering functionality
    func testDeviceFiltering() {
        // Setup mock devices with different names and types
        let recordID1 = CKRecord.ID(recordName: "device1")
        let recordID2 = CKRecord.ID(recordName: "device2")
        let recordID3 = CKRecord.ID(recordName: "device3")
        
        let device1 = DeviceInfo(id: "device1", name: "MacBook Pro", type: "Mac", recordID: recordID1)
        let device2 = DeviceInfo(id: "device2", name: "iPhone 15", type: "iPhone", recordID: recordID2)
        let device3 = DeviceInfo(id: "device3", name: "iPad Air", type: "iPad", recordID: recordID3)
        
        // Update the mock view model with these devices
        mockViewModel.connectionState.updateDiscoveredDevices([device1, device2, device3])
        
        // Create the filtering helper
        let helper = DeviceFilteringTestHelper()
        
        // Test filtering by device name
        let filteredByName = helper.filterDevices(mockViewModel.connectionState.discoveredDevices, searchText: "iPhone")
        XCTAssertEqual(filteredByName.count, 1)
        XCTAssertEqual(filteredByName.first?.id, "device2")
        
        // Test filtering by device type
        let filteredByType = helper.filterDevices(mockViewModel.connectionState.discoveredDevices, searchText: "iPad")
        XCTAssertEqual(filteredByType.count, 1)
        XCTAssertEqual(filteredByType.first?.id, "device3")
        
        // Test filtering with no matches
        let filteredNoMatches = helper.filterDevices(mockViewModel.connectionState.discoveredDevices, searchText: "Android")
        XCTAssertEqual(filteredNoMatches.count, 0)
        
        // Test with empty search text (should return all devices)
        let filteredEmpty = helper.filterDevices(mockViewModel.connectionState.discoveredDevices, searchText: "")
        XCTAssertEqual(filteredEmpty.count, 3)
    }
    
    // Test retry connection functionality
    func testRetryConnection() {
        // Setup a device and connection error
        let recordID = CKRecord.ID(recordName: "device1")
        let device = DeviceInfo(id: "device1", name: "Device 1", recordID: recordID)
        
        // Set up initial state: selected device with error
        mockViewModel.connectionState.selectDevice(device)
        mockViewModel.connectionState.handleError(NSError(domain: "com.test", code: -1, userInfo: nil))
        
        // Check initial state
        XCTAssertEqual(mockViewModel.connectionState.status, .error)
        XCTAssertNotNil(mockViewModel.connectionState.lastError)
        XCTAssertEqual(mockViewModel.connectionState.selectedDevice?.id, "device1")
        
        // Create helper and retry connection
        let helper = RetryConnectionTestHelper(viewModel: mockViewModel)
        helper.retryConnection()
        
        // Verify error was cleared
        XCTAssertTrue(mockViewModel.clearErrorCalled)
        
        // Verify connection was retried
        XCTAssertTrue(mockViewModel.connectToDeviceCalled)
        XCTAssertEqual(mockViewModel.lastConnectedDevice?.id, "device1")
    }
    
    // Test formatted last update time
    func testFormattedLastUpdateTime() {
        // Set a specific last updated time
        let now = Date()
        mockViewModel.connectionState.lastUpdated = now
        
        // Create helper to format the time
        let helper = DateFormattingTestHelper()
        let formattedTime = helper.formatRelativeTime(mockViewModel.connectionState.lastUpdated)
        
        // Verify the formatter produces a non-empty string
        XCTAssertFalse(formattedTime.isEmpty)
        
        // Test with a time from yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        mockViewModel.connectionState.lastUpdated = yesterday
        let formattedYesterday = helper.formatRelativeTime(mockViewModel.connectionState.lastUpdated)
        
        // Should contain "day" or localized equivalent
        XCTAssertTrue(formattedYesterday.contains("day") || 
                     formattedYesterday.contains("yesterday") ||
                     formattedYesterday.contains("1"))
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

// Helper class to test device filtering
class DeviceFilteringTestHelper {
    func filterDevices(_ devices: [DeviceInfo], searchText: String) -> [DeviceInfo] {
        if searchText.isEmpty {
            return devices
        } else {
            return devices.filter { device in
                device.name.localizedCaseInsensitiveContains(searchText) ||
                device.type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// Helper class to test retry connection
class RetryConnectionTestHelper {
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func retryConnection() {
        // This simulates the retry connection action
        viewModel.clearError()
        
        if let selectedDevice = viewModel.connectionState.selectedDevice {
            viewModel.connectToDevice(selectedDevice)
        }
    }
}

// Helper class to test date formatting
class DateFormattingTestHelper {
    func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 