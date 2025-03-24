import Foundation
import CloudKit
@testable import CursorMirrorClient

/// A mock implementation of CloudKitDatabaseProtocol for testing without real CloudKit dependencies
class MockCloudKitDatabase: CloudKitDatabaseProtocol {
    // Records to return for queries
    var mockDevices: [CKRecord] = []
    
    // Test control flags
    var shouldFailQueries = false
    var simulatedQueryError: Error?
    var queriesPerformed: [CKQuery] = []
    var saveOperationsPerformed: [CKRecord] = []
    var shouldFailSaves = false
    var simulatedSaveError: Error?
    
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
        // Record this query for test verification
        queriesPerformed.append(query)
        
        // Simulate failure if needed
        if shouldFailQueries {
            throw simulatedQueryError ?? NSError(
                domain: "MockCloudKitError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Simulated query failure"]
            )
        }
        
        // Return mock results
        let results: [(CKRecord.ID, Result<CKRecord, Error>)] = mockDevices.map { record in
            (record.recordID, .success(record))
        }
        
        // Apply result limit if specified
        let limitedResults = resultsLimit > 0 && resultsLimit < results.count
            ? Array(results.prefix(resultsLimit))
            : results
        
        return (matchResults: limitedResults, queryCursor: nil)
    }
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        // Record this save operation for test verification
        saveOperationsPerformed.append(record)
        
        // Simulate failure if needed
        if shouldFailSaves {
            throw simulatedSaveError ?? NSError(
                domain: "MockCloudKitError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Simulated save failure"]
            )
        }
        
        // Return the saved record
        return record
    }
} 