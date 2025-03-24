import Foundation
import CloudKit
import SwiftUI
@testable import CursorMirrorClient

/// A mock implementation of ConnectionViewModel for testing purposes
class TestConnectionViewModel: ConnectionViewModel {
    // Mock behavior flags
    var shouldProvideStreamURL = false
    var providedStreamURL: URL?
    var clearErrorCalled = false
    var disconnectCalled = false
    var connectToDeviceCalled = false
    var startDeviceDiscoveryCalled = false
    var lastConnectedDevice: DeviceInfo?
    
    // Mock database
    private let mockDatabase = MockCloudKitDatabase()
    
    override init(connectionState: ConnectionState = ConnectionState(), 
                 streamConfig: StreamConfig = StreamConfig(),
                 database: CloudKitDatabaseProtocol? = nil) {
        // Always use our mock database, regardless of what's passed in
        super.init(connectionState: connectionState, 
                  streamConfig: streamConfig, 
                  database: mockDatabase)
        
        // Initialize flags for testing
        startDeviceDiscoveryCalled = false
        connectToDeviceCalled = false
        clearErrorCalled = false
        disconnectCalled = false
        
        // Add some mock devices for testing
        let recordID1 = CKRecord.ID(recordName: "device1")
        let recordID2 = CKRecord.ID(recordName: "device2")
        let device1 = DeviceInfo(id: "device1", name: "Device 1", recordID: recordID1)
        let device2 = DeviceInfo(id: "device2", name: "Device 2", recordID: recordID2)
        mockDatabase.mockDevices = [
            MockCloudKitDatabase.createMockDeviceRecord(id: "device1", name: "Device 1"),
            MockCloudKitDatabase.createMockDeviceRecord(id: "device2", name: "Device 2")
        ]
    }
    
    /// Add mock devices to be returned by discovery
    func addMockDevices(_ devices: [DeviceInfo]) {
        connectionState.updateDiscoveredDevices(devices)
    }
    
    override func getStreamURL() -> URL? {
        return shouldProvideStreamURL ? providedStreamURL : nil
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
    
    override func connectToDevice(_ device: DeviceInfo) {
        connectToDeviceCalled = true
        lastConnectedDevice = device
        connectionState.selectDevice(device)
        connectionState.status = .connected
    }
    
    override func startDeviceDiscovery() {
        startDeviceDiscoveryCalled = true
        // Don't call super to avoid actual CloudKit operations
        
        // Immediately update discovered devices synchronously for tests
        // This avoids async issues in tests
        let recordID1 = CKRecord.ID(recordName: "device1")
        let recordID2 = CKRecord.ID(recordName: "device2")
        let device1 = DeviceInfo(id: "device1", name: "Device 1", recordID: recordID1)
        let device2 = DeviceInfo(id: "device2", name: "Device 2", recordID: recordID2)
        connectionState.updateDiscoveredDevices([device1, device2])
    }
    
    override func registerThisDevice() async {
        // No-op to avoid actual CloudKit operations
    }
} 