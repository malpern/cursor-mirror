import Foundation
import CloudKit
@testable import CursorMirrorClient

/// A mock implementation of CloudKitDatabaseProtocol for testing without real CloudKit dependencies
class MockCloudKitDatabase: CloudKitDatabaseProtocol {
    var recordsToReturn: [(CKRecord.ID, Result<CKRecord, Error>)] = []
    var recordsToSave: [CKRecord] = []
    var queriesReceived: [CKQuery] = []
    var error: Error?
    
    func reset() {
        recordsToReturn = []
        recordsToSave = []
        queriesReceived = []
        error = nil
    }
    
    /// Creates a mock device record for testing
    static func createMockDeviceRecord(id: String, name: String) -> CKRecord {
        let record = CKRecord(recordType: "Device")
        record["id"] = id
        record["name"] = name
        record["type"] = "Mac"
        record["isOnline"] = 1
        record["lastSeen"] = Date()
        return record
    }
    
    // MARK: - CloudKitDatabaseProtocol
    
    func records(
        matching query: CKQuery,
        inZoneWith zoneID: CKRecordZone.ID?,
        resultsLimit: Int
    ) async throws -> (
        matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
        queryCursor: CKQueryOperation.Cursor?
    ) {
        queriesReceived.append(query)
        
        if let error = self.error {
            throw error
        }
        
        return (recordsToReturn, nil)
    }
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        if let error = self.error {
            throw error
        }
        
        recordsToSave.append(record)
        return record
    }
    
    // Helper to add a successful record
    func addRecord(id: String = "test-record", type: String = "Device") {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: type, recordID: recordID)
        record["id"] = id
        record["name"] = "Test Device"
        record["type"] = "Mac"
        record["isOnline"] = 1
        record["lastSeen"] = Date()
        
        recordsToReturn.append((recordID, .success(record)))
    }
    
    // Helper to add an error result
    func addError(recordID: String = "error-record", error: Error) {
        let recordID = CKRecord.ID(recordName: recordID)
        recordsToReturn.append((recordID, .failure(error)))
    }
} 