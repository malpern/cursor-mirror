import Foundation
import CloudKit

// Protocol for device registration service operations
public protocol DeviceRegistrationServiceProtocol {
    func registerDevice(serverIP: String) async throws -> Bool
    static func markOffline(deviceID: String?) async throws -> Bool
}

// Protocol for CloudKit container operations
public protocol CloudKitContainerProtocol {
    var privateCloudDatabase: CloudKitDatabaseProtocol { get }
    func accountStatus() async throws -> CKAccountStatus
}

// Protocol for CloudKit database operations
public protocol CloudKitDatabaseProtocol {
    func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?, desiredKeys: [CKRecord.FieldKey]?, resultsLimit: Int) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
    func save(_ record: CKRecord) async throws -> CKRecord
} 