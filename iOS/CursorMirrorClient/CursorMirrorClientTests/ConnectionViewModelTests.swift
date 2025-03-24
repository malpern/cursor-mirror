import XCTest
import CloudKit
import UIKit
@testable import CursorMirrorClient

final class ConnectionViewModelTests: XCTestCase {
    var sut: ConnectionViewModel!
    var mockConnectionState: ConnectionState!
    var mockStreamConfig: StreamConfig!
    var mockDatabase: MockCloudKitDatabase!
    
    override func setUp() {
        super.setUp()
        mockConnectionState = ConnectionState()
        mockStreamConfig = StreamConfig()
        mockDatabase = MockCloudKitDatabase()
        sut = ConnectionViewModel(
            connectionState: mockConnectionState,
            streamConfig: mockStreamConfig,
            database: mockDatabase
        )
    }
    
    override func tearDown() {
        // Cancel any active tasks before setting nil
        sut?.cancelDiscovery()
        
        sut = nil
        mockConnectionState = nil
        mockStreamConfig = nil
        mockDatabase = nil
        
        // Run a short runloop spin to allow any pending operations to complete
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Use the termination helper
        terminateTestProcesses()
        
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(sut.connectionState.status, .disconnected)
        XCTAssertNil(sut.connectionState.selectedDevice)
        XCTAssertTrue(sut.connectionState.discoveredDevices.isEmpty)
    }
    
    func testConnectToDevice() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let testDevice = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID)
        
        // Act
        sut.connectToDevice(testDevice)
        
        // Assert - immediate state change
        XCTAssertEqual(sut.connectionState.status, .connecting)
        XCTAssertEqual(sut.connectionState.selectedDevice?.id, "test-id")
        
        // Note: We don't test the async transition to connected state here since it happens after a delay
    }
    
    func testDisconnect() async throws {
        // Arrange - set up a connected state first
        let recordID = CKRecord.ID(recordName: "test-id")
        let testDevice = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID)
        mockConnectionState.selectedDevice = testDevice
        mockConnectionState.status = .connected
        
        // Act
        sut.disconnect()
        
        // Assert - immediate state change
        XCTAssertEqual(sut.connectionState.status, .disconnecting)
        
        // Wait for the async transition to complete
        try await Task.sleep(for: .seconds(1))
        
        // Assert - final state after async operation
        XCTAssertEqual(sut.connectionState.status, .disconnected)
        XCTAssertNil(sut.connectionState.selectedDevice)
    }
    
    func testClearError() {
        // Arrange
        let testError = NSError(domain: "com.cursormirror.test", code: -1, userInfo: nil)
        mockConnectionState.handleError(testError)
        
        // Act
        sut.clearError()
        
        // Assert
        XCTAssertNil(sut.connectionState.lastError)
        XCTAssertEqual(sut.connectionState.status, .disconnected)
    }
    
    func testGetStreamURL() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let testDevice = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID)
        mockConnectionState.selectedDevice = testDevice
        mockConnectionState.status = .connected
        
        // Act
        let streamURL = sut.getStreamURL()
        
        // Assert
        XCTAssertNotNil(streamURL)
        XCTAssertTrue(streamURL?.absoluteString.contains("test-id") ?? false)
    }
    
    func testGetStreamURLWhenNotConnected() {
        // Arrange - we're not connected
        let recordID = CKRecord.ID(recordName: "test-id")
        let testDevice = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID)
        mockConnectionState.selectedDevice = testDevice
        mockConnectionState.status = .disconnected // Not connected!
        
        // Act
        let streamURL = sut.getStreamURL()
        
        // Assert
        XCTAssertNil(streamURL, "Should not return a stream URL when not connected")
    }
    
    func testDeviceDiscovery() async throws {
        // Arrange - prepare mock devices
        let device1 = MockCloudKitDatabase.createMockDeviceRecord(id: "device1", name: "Device 1")
        let device2 = MockCloudKitDatabase.createMockDeviceRecord(id: "device2", name: "Device 2")
        mockDatabase.mockDevices = [device1, device2]
        
        // Act
        sut.startDeviceDiscovery()
        
        // Wait a bit for async operation to complete
        try await Task.sleep(for: .seconds(0.5))
        
        // Assert
        XCTAssertEqual(mockDatabase.queriesPerformed.count, 1)
        XCTAssertEqual(sut.connectionState.discoveredDevices.count, 2)
        XCTAssertTrue(sut.connectionState.discoveredDevices.contains { $0.id == "device1" })
        XCTAssertTrue(sut.connectionState.discoveredDevices.contains { $0.id == "device2" })
    }
    
    func testDeviceDiscoveryFailure() async throws {
        // Arrange - prepare mock error
        mockDatabase.shouldFailQueries = true
        mockDatabase.simulatedQueryError = NSError(
            domain: "CloudKitError",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Network error"]
        )
        
        // Act
        sut.startDeviceDiscovery()
        
        // Wait a bit for async operation to complete
        try await Task.sleep(for: .seconds(0.5))
        
        // Assert
        XCTAssertEqual(mockDatabase.queriesPerformed.count, 1)
        XCTAssertEqual(sut.connectionState.status, .error)
        XCTAssertNotNil(sut.connectionState.lastError)
    }
} 