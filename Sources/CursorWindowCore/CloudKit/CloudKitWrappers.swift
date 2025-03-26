import Foundation
import CloudKit

// Wrapper for CKContainer to conform to our protocol
public class CloudKitContainerWrapper: CloudKitContainerProtocol {
    private let container: CKContainer
    private let databaseWrapper: CloudKitDatabaseWrapper
    
    public init(_ container: CKContainer) {
        self.container = container
        self.databaseWrapper = CloudKitDatabaseWrapper(container.privateCloudDatabase)
    }
    
    public var privateCloudDatabase: CloudKitDatabaseProtocol {
        return databaseWrapper
    }
    
    public func accountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }
}

// Wrapper for CKDatabase to conform to our protocol
public class CloudKitDatabaseWrapper: CloudKitDatabaseProtocol {
    private let database: CKDatabase
    
    public init(_ database: CKDatabase) {
        self.database = database
    }
    
    public func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?, desiredKeys: [CKRecord.FieldKey]?, resultsLimit: Int) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?) {
        return try await database.records(matching: query, inZoneWith: zoneID, desiredKeys: desiredKeys, resultsLimit: resultsLimit)
    }
    
    public func save(_ record: CKRecord) async throws -> CKRecord {
        return try await database.save(record)
    }
} 