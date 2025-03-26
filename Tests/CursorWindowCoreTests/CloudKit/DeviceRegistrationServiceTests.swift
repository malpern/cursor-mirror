import XCTest
import CloudKit
@testable import CursorWindowCore

// Protocol for CloudKit container operations
protocol CloudKitContainerProtocol {
    var privateCloudDatabase: CloudKitDatabaseProtocol { get }
    func accountStatus() async throws -> CKAccountStatus
}

// Protocol for CloudKit database operations
protocol CloudKitDatabaseProtocol {
    func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?, desiredKeys: [CKRecord.FieldKey]?, resultsLimit: Int) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
    func save(_ record: CKRecord) async throws -> CKRecord
}

extension CKContainer: CloudKitContainerProtocol {
    var privateCloudDatabase: CloudKitDatabaseProtocol {
        return super.privateCloudDatabase
    }
}

extension CKDatabase: CloudKitDatabaseProtocol {}

@MainActor
final class DeviceRegistrationServiceTests: XCTestCase {
    var deviceService: DeviceRegistrationService!
    var mockContainer: MockCloudKitContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock container
        mockContainer = MockCloudKitContainer()
        
        // Create device service with mock container
        deviceService = DeviceRegistrationService(
            container: mockContainer,
            deviceName: "TestDevice",
            deviceID: "test-device-id",
            deviceType: "Mac"
        )
    }
    
    override func tearDown() async throws {
        deviceService = nil
        mockContainer = nil
        try await super.tearDown()
    }
    
    func testRegisterDeviceSuccess() async throws {
        // Given
        mockContainer.accountStatus = .available
        mockContainer.mockDatabase.recordsToReturn = []
        
        // When
        let result = try await deviceService.registerDevice(serverIP: "192.168.1.1")
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockContainer.mockDatabase.savedRecords.count, 1)
        
        let savedRecord = mockContainer.mockDatabase.savedRecords.first
        XCTAssertNotNil(savedRecord)
        XCTAssertEqual(savedRecord?["id"] as? String, "test-device-id")
        XCTAssertEqual(savedRecord?["name"] as? String, "TestDevice")
        XCTAssertEqual(savedRecord?["type"] as? String, "Mac")
        XCTAssertEqual(savedRecord?["isOnline"] as? Int, 1)
        XCTAssertEqual(savedRecord?["serverAddress"] as? String, "192.168.1.1")
    }
    
    func testRegisterDeviceUpdateExisting() async throws {
        // Given
        mockContainer.accountStatus = .available
        let existingRecord = CKRecord(recordType: "Device")
        existingRecord["id"] = "test-device-id"
        existingRecord["name"] = "OldName"
        mockContainer.mockDatabase.recordsToReturn = [(existingRecord.recordID, .success(existingRecord))]
        
        // When
        let result = try await deviceService.registerDevice(serverIP: "192.168.1.1")
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockContainer.mockDatabase.savedRecords.count, 1)
        
        let savedRecord = mockContainer.mockDatabase.savedRecords.first
        XCTAssertNotNil(savedRecord)
        XCTAssertEqual(savedRecord?["name"] as? String, "TestDevice")
        XCTAssertEqual(savedRecord?["serverAddress"] as? String, "192.168.1.1")
    }
    
    func testRegisterDeviceWithRetry() async throws {
        // Given
        mockContainer.accountStatus = .available
        mockContainer.mockDatabase.shouldFailFirst = 2 // Fail first 2 attempts
        
        // When
        let result = try await deviceService.registerDevice(serverIP: "192.168.1.1")
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockContainer.mockDatabase.saveAttempts, 3) // Should succeed on third try
    }
    
    func testRegisterDeviceAccountUnavailable() async throws {
        // Given
        mockContainer.accountStatus = .noAccount
        
        // When
        let result = try await deviceService.registerDevice(serverIP: "192.168.1.1")
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockContainer.mockDatabase.savedRecords.isEmpty)
    }
    
    func testMarkOfflineSuccess() async throws {
        // Given
        mockContainer.accountStatus = .available
        let existingRecord = CKRecord(recordType: "Device")
        existingRecord["id"] = "test-device-id"
        existingRecord["isOnline"] = 1
        mockContainer.mockDatabase.recordsToReturn = [(existingRecord.recordID, .success(existingRecord))]
        
        // When
        let result = try await DeviceRegistrationService.markOffline(deviceID: "test-device-id")
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockContainer.mockDatabase.savedRecords.count, 1)
        
        let savedRecord = mockContainer.mockDatabase.savedRecords.first
        XCTAssertNotNil(savedRecord)
        XCTAssertEqual(savedRecord?["isOnline"] as? Int, 0)
    }
    
    func testMarkOfflineDeviceNotFound() async throws {
        // Given
        mockContainer.accountStatus = .available
        mockContainer.mockDatabase.recordsToReturn = []
        
        // When
        let result = try await DeviceRegistrationService.markOffline(deviceID: "test-device-id")
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockContainer.mockDatabase.savedRecords.isEmpty)
    }
}

// Mock CloudKit container for testing
final class MockCloudKitContainer: CloudKitContainerProtocol {
    var accountStatus: CKAccountStatus = .available
    let mockDatabase = MockCloudKitDatabase()
    
    var privateCloudDatabase: CloudKitDatabaseProtocol {
        return mockDatabase
    }
    
    func accountStatus() async throws -> CKAccountStatus {
        return accountStatus
    }
}

// Mock CloudKit database for testing
final class MockCloudKitDatabase: CloudKitDatabaseProtocol {
    var recordsToReturn: [(CKRecord.ID, Result<CKRecord, Error>)] = []
    var savedRecords: [CKRecord] = []
    var shouldFailFirst: Int = 0
    var saveAttempts: Int = 0
    
    func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?, desiredKeys: [CKRecord.FieldKey]?, resultsLimit: Int) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?) {
        return (recordsToReturn, nil)
    }
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        saveAttempts += 1
        
        if saveAttempts <= shouldFailFirst {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated save failure"])
        }
        
        savedRecords.append(record)
        return record
    }
} 