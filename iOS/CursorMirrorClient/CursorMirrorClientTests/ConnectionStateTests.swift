//
//  ConnectionStateTests.swift
//  CursorMirrorClient
//
//  Created by Micah Alpern on 3/23/25.
//

import XCTest
import CloudKit
@testable import CursorMirrorClient

final class ConnectionStateTests: XCTestCase {
    var sut: ConnectionState!
    
    override func setUp() {
        super.setUp()
        sut = ConnectionState()
    }
    
    override func tearDown() {
        // Force any potential observers to detach by removing references
        sut = nil
        
        // Run a short runloop spin to allow any pending operations to complete
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(sut.status, .disconnected)
        XCTAssertNil(sut.selectedDevice)
        XCTAssertTrue(sut.discoveredDevices.isEmpty)
    }
    
    func testDeviceSelection() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let testDevice = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID)
        
        // Act
        sut.selectDevice(testDevice)
        
        // Assert
        XCTAssertEqual(sut.selectedDevice?.id, "test-id")
        XCTAssertEqual(sut.status, .connecting)
    }
    
    func testConnectionStateTransitions() {
        // Test connecting
        sut.status = .connecting
        XCTAssertEqual(sut.status, .connecting)
        
        // Test connected
        sut.status = .connected
        XCTAssertEqual(sut.status, .connected)
        
        // Test disconnecting
        sut.status = .disconnecting
        XCTAssertEqual(sut.status, .disconnecting)
        
        // Test disconnected
        sut.status = .disconnected
        XCTAssertEqual(sut.status, .disconnected)
    }
    
    func testDeviceDiscovery() {
        // Arrange
        let recordID1 = CKRecord.ID(recordName: "device1")
        let recordID2 = CKRecord.ID(recordName: "device2")
        let device1 = DeviceInfo(id: "device1", name: "Device 1", recordID: recordID1)
        let device2 = DeviceInfo(id: "device2", name: "Device 2", recordID: recordID2)
        
        // Act
        sut.updateDiscoveredDevices([device1, device2])
        
        // Assert
        XCTAssertEqual(sut.discoveredDevices.count, 2)
        XCTAssertTrue(sut.discoveredDevices.contains { $0.id == "device1" })
        XCTAssertTrue(sut.discoveredDevices.contains { $0.id == "device2" })
    }
    
    func testErrorHandling() {
        // Arrange
        let testError = NSError(domain: "com.cursormirror.test", code: -1, userInfo: nil)
        
        // Act
        sut.handleError(testError)
        
        // Assert
        XCTAssertEqual(sut.status, .error)
        XCTAssertNotNil(sut.lastError)
    }
    
    func testClearError() {
        // Arrange
        let testError = NSError(domain: "com.cursormirror.test", code: -1, userInfo: nil)
        sut.handleError(testError)
        
        // Act
        sut.clearError()
        
        // Assert
        XCTAssertNil(sut.lastError)
        XCTAssertEqual(sut.status, .disconnected)
    }
}

