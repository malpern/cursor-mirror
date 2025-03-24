import Foundation
import CloudKit
@testable import CursorMirrorClient

class MockCloudKitDatabase: CloudKitDatabaseProtocol {
    // Devices to return in queries
    var mockDevices: [CKRecord] = []
    
    // Simulated errors
    var shouldFailQueries = false
    var simulatedQueryError: Error?
    var shouldFailSaves = false
    var simulatedSaveError: Error?
    
    // Track operations
    var queriesPerformed: [CKQuery] = []
    var recordsSaved: [CKRecord] = []
    
    // Initialize with optional mock devices
    init(mockDevices: [CKRecord] = []) {
        self.mockDevices = mockDevices
    }
    
    // Create a standard mock device record
    static func createMockDeviceRecord(id: String, name: String, type: String = "Mac") -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "Device", recordID: recordID)
        record["id"] = id
        record["name"] = name
        record["type"] = type
        record["isOnline"] = 1
        record["lastSeen"] = Date()
        return record
    }
    
    // MARK: - CloudKitDatabaseProtocol Implementation
    
    func records(
        matching query: CKQuery,
        inZoneWith zoneID: CKRecordZone.ID? = nil,
        resultsLimit: Int = 0
    ) async throws -> (
        matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
        queryCursor: CKQueryOperation.Cursor?
    ) {
        // Track this query
        queriesPerformed.append(query)
        
        // Check if should fail
        if shouldFailQueries {
            throw simulatedQueryError ?? NSError(
                domain: "MockCloudKitError",
                code: -1,
                userInfo: nil
            )
        }
        
        // Process and return mock results
        let results: [(CKRecord.ID, Result<CKRecord, Error>)] = mockDevices.map { record in
            return (record.recordID, .success(record))
        }
        
        return (results, nil)
    }
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        // Track this save
        recordsSaved.append(record)
        
        // Check if should fail
        if shouldFailSaves {
            throw simulatedSaveError ?? NSError(
                domain: "MockCloudKitError",
                code: -1,
                userInfo: nil
            )
        }
        
        return record
    }
} 