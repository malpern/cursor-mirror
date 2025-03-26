import Foundation
import CloudKit

// Protocol for CloudKit settings sync operations
protocol CloudKitSettingsSyncProtocol {
    func syncSettings(_ settings: [String: Any], forDeviceID deviceID: String) async throws
    func loadSettings(forDeviceID deviceID: String) async throws -> [String: Any]?
    func deleteSettings(forDeviceID deviceID: String) async throws
}

class CloudKitSettingsSync: CloudKitSettingsSyncProtocol {
    private let database: CloudKitDatabaseProtocol
    private let recordType = "DeviceSettings"
    
    init(database: CloudKitDatabaseProtocol? = nil) {
        self.database = database ?? CloudKitDatabaseWrapper(CKContainer(identifier: "iCloud.com.cursormirror.client").privateCloudDatabase)
    }
    
    /// Synchronize settings to CloudKit
    func syncSettings(_ settings: [String: Any], forDeviceID deviceID: String) async throws {
        // Check iCloud account status first
        try await checkiCloudAccountStatus()
        
        // Create a query to find existing settings record for this device
        let predicate = NSPredicate(format: "deviceID == %@", deviceID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        // Check if a record already exists
        let (results, _) = try await database.records(
            matching: query,
            inZoneWith: nil,
            resultsLimit: 1
        )
        
        let record: CKRecord
        
        // If a record exists, update it; otherwise create a new one
        if let existingRecordResult = results.first?.1 {
            do {
                record = try existingRecordResult.get()
            } catch {
                print("Error retrieving existing settings record: \(error.localizedDescription)")
                throw error
            }
        } else {
            // Create a new record
            record = CKRecord(recordType: recordType)
            record["deviceID"] = deviceID as NSString
        }
        
        // Serialize settings to JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: settings),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            record["settingsJson"] = jsonString as NSString
        }
        
        // Save timestamp
        record["lastUpdated"] = Date() as NSDate
        
        // Save to CloudKit
        _ = try await database.save(record)
    }
    
    /// Load settings from CloudKit for a specific device
    func loadSettings(forDeviceID deviceID: String) async throws -> [String: Any]? {
        // Check iCloud account status first
        try await checkiCloudAccountStatus()
        
        // Create a query to find settings for this device
        let predicate = NSPredicate(format: "deviceID == %@", deviceID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        // Query CloudKit
        let (results, _) = try await database.records(
            matching: query,
            inZoneWith: nil,
            resultsLimit: 1
        )
        
        // If we found a record, convert it to a dictionary
        if let recordResult = results.first?.1 {
            do {
                let record = try recordResult.get()
                
                // Get settings JSON from record
                if let settingsJson = record["settingsJson"] as? String,
                   let jsonData = settingsJson.data(using: .utf8),
                   let settings = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    return settings
                }
                
                return nil
            } catch {
                print("Error retrieving settings record: \(error.localizedDescription)")
                throw error
            }
        }
        
        return nil
    }
    
    /// Delete settings from CloudKit
    func deleteSettings(forDeviceID deviceID: String) async throws {
        // Check iCloud account status first
        try await checkiCloudAccountStatus()
        
        // Create a query to find settings for this device
        let predicate = NSPredicate(format: "deviceID == %@", deviceID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        // Query CloudKit
        let (results, _) = try await database.records(
            matching: query,
            inZoneWith: nil,
            resultsLimit: 1
        )
        
        // If we found a record, delete it
        if let recordResult = results.first,
           let recordID = try? recordResult.1.get().recordID {
            try await CKContainer(identifier: "iCloud.com.cursormirror.client").privateCloudDatabase.deleteRecord(withID: recordID)
        }
    }
    
    /// Check iCloud account status
    private func checkiCloudAccountStatus() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            CKContainer(identifier: "iCloud.com.cursormirror.client").accountStatus { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if status != .available {
                    let error = NSError(
                        domain: "CursorMirrorErrorDomain",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "iCloud account not available. Please sign in to iCloud in Settings."]
                    )
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume()
            }
        }
    }
} 