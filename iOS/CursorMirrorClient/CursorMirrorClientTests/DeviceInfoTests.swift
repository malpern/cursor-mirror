//
//  DeviceInfoTests.swift
//  CursorMirrorClient
//
//  Created by Micah Alpern on 3/23/25.
//

import XCTest
import CloudKit
@testable import CursorMirrorClient

final class DeviceInfoTests: XCTestCase {
    // Add tearDown method to ensure proper cleanup
    override func tearDown() {
        // Run a short runloop spin to allow any pending operations to complete
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        super.tearDown()
    }
    
    func testDeviceInfoInitialization() {
        // Arrange & Act
        let recordID = CKRecord.ID(recordName: "test-id")
        let device = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID)
        
        // Assert
        XCTAssertEqual(device.id, "test-id")
        XCTAssertEqual(device.name, "Test Device")
        XCTAssertEqual(device.type, "Mac")  // Default value
        XCTAssertFalse(device.isOnline)     // Default value
    }
    
    func testDeviceInfoEquality() {
        // Arrange
        let recordID1 = CKRecord.ID(recordName: "test-id")
        let recordID2 = CKRecord.ID(recordName: "different-id")
        let device1 = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID1)
        let device2 = DeviceInfo(id: "test-id", name: "Different Name", recordID: recordID1)
        let device3 = DeviceInfo(id: "different-id", name: "Test Device", recordID: recordID2)
        
        // Assert
        XCTAssertEqual(device1, device2) // Should be equal because IDs match
        XCTAssertNotEqual(device1, device3) // Should not be equal because IDs differ
    }
    
    func testInitFromCloudKitRecord() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let record = CKRecord(recordType: "Device", recordID: recordID)
        record["name"] = "Test Device"
        record["type"] = "Mac"
        record["isOnline"] = 1
        record["lastSeen"] = Date()
        
        // Act
        let device = DeviceInfo(from: record)
        
        // Assert
        XCTAssertNotNil(device)
        XCTAssertEqual(device?.id, recordID.recordName)
        XCTAssertEqual(device?.name, "Test Device")
        XCTAssertEqual(device?.type, "Mac")
        XCTAssertTrue(device?.isOnline ?? false)
    }
    
    func testInitFromInvalidCloudKitRecord() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let record = CKRecord(recordType: "Device", recordID: recordID)
        // Missing required fields
        
        // Act
        let device = DeviceInfo(from: record)
        
        // Assert
        XCTAssertNil(device)
    }
    
    func testHashable() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let device1 = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID)
        let device2 = DeviceInfo(id: "test-id", name: "Different Name", recordID: recordID)
        
        // Act
        let set = Set([device1, device2])
        
        // Assert
        XCTAssertEqual(set.count, 1) // Should only contain one device because they have the same ID
    }
    
    func testDisplayNameFormatting() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let device = DeviceInfo(id: "test-id", name: "Test Device", type: "iPhone", recordID: recordID)
        
        // Act & Assert
        XCTAssertEqual(device.displayName, "Test Device (iPhone)")
    }
    
    func testStatusIndicator() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let onlineDevice = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID, isOnline: true)
        let offlineDevice = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID, isOnline: false)
        
        // Act & Assert
        XCTAssertEqual(onlineDevice.statusIndicator, "🟢")
        XCTAssertEqual(offlineDevice.statusIndicator, "⚫️")
    }
    
    func testLastSeenFormatting() {
        // Arrange
        let recordID = CKRecord.ID(recordName: "test-id")
        let now = Date()
        let device = DeviceInfo(id: "test-id", name: "Test Device", recordID: recordID, lastSeen: now)
        
        // Act
        let lastSeenText = device.lastSeenText
        
        // Assert
        XCTAssertFalse(lastSeenText.isEmpty)
        // Note: We can't test the exact string as it's relative to current time
        // but we can verify it's not empty
    }
}

