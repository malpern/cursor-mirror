import Foundation
import CloudKit

#if os(macOS)
/// Service to register this device with CloudKit
public class DeviceRegistrationService {
    // CloudKit container
    private let container: CKContainer
    
    // Device information
    private let deviceName: String
    private let deviceID: String
    private let deviceType: String
    
    /// Initialize the device registration service
    /// - Parameter container: CloudKit container to use
    public init(
        container: CKContainer = CKContainer(identifier: "iCloud.com.cursormirror.client"),
        deviceName: String = Host.current().localizedName ?? "MacBook",
        deviceID: String = UUID().uuidString,
        deviceType: String = "Mac"
    ) {
        self.container = container
        self.deviceName = deviceName
        self.deviceID = deviceID
        self.deviceType = deviceType
    }
    
    /// Register this device to CloudKit
    /// - Parameter serverIP: The IP address of the server
    /// - Returns: Success or failure
    public func registerDevice(serverIP: String = ServerConfig.getLocalIPAddress()) async throws -> Bool {
        print("Registering device with server IP: \(serverIP)")
        
        // Check iCloud account status
        let status = try await checkiCloudAccountStatus()
        guard status == .available else {
            print("iCloud account unavailable with status: \(status.rawValue)")
            return false
        }
        
        // Create a unique identifier for this device
        let query = CKQuery(
            recordType: "Device",
            predicate: NSPredicate(format: "id == %@", deviceID)
        )
        
        do {
            // Check if device already exists
            let (results, _) = try await container.privateCloudDatabase.records(
                matching: query,
                inZoneWith: nil,
                desiredKeys: nil,
                resultsLimit: 1
            )
            
            // If device exists, update it
            if let recordResult = results.first?.1 {
                var existingRecord: CKRecord
                do {
                    existingRecord = try recordResult.get()
                    existingRecord["name"] = deviceName
                    existingRecord["type"] = deviceType
                    existingRecord["isOnline"] = 1
                    existingRecord["lastSeen"] = Date()
                    existingRecord["serverAddress"] = serverIP
                    
                    _ = try await container.privateCloudDatabase.save(existingRecord)
                    print("Updated existing device record with server IP: \(serverIP)")
                    return true
                } catch {
                    print("Error updating device record: \(error.localizedDescription)")
                    throw error
                }
            } else {
                // Create a new device record
                let newRecord = CKRecord(recordType: "Device")
                newRecord["id"] = deviceID
                newRecord["name"] = deviceName
                newRecord["type"] = deviceType
                newRecord["isOnline"] = 1
                newRecord["lastSeen"] = Date()
                newRecord["serverAddress"] = serverIP
                
                _ = try await container.privateCloudDatabase.save(newRecord)
                print("Created new device record with server IP: \(serverIP)")
                return true
            }
        } catch {
            print("Error registering device: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Check iCloud account status
    private func checkiCloudAccountStatus() async throws -> CKAccountStatus {
        return try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Mark this device as offline in CloudKit
    /// - Returns: Success or failure
    public static func markOffline(deviceID: String? = nil) async throws -> Bool {
        let container = CKContainer(identifier: "iCloud.com.cursormirror.client")
        let deviceID = deviceID ?? Host.current().localizedName ?? "MacBook"
        
        do {
            // Check the account status first
            let status: CKAccountStatus = try await withCheckedThrowingContinuation { continuation in
                container.accountStatus { status, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: status)
                }
            }
            
            guard status == .available else {
                print("iCloud account unavailable with status: \(status.rawValue)")
                return false
            }
            
            // Create a query to find this device
            let query = CKQuery(
                recordType: "Device",
                predicate: NSPredicate(format: "id == %@", deviceID)
            )
            
            // Look for the device record
            let (results, _) = try await container.privateCloudDatabase.records(
                matching: query,
                inZoneWith: nil,
                desiredKeys: nil,
                resultsLimit: 1
            )
            
            // If device exists, update it to be offline
            if let recordResult = results.first?.1 {
                var deviceRecord: CKRecord
                do {
                    deviceRecord = try recordResult.get()
                    deviceRecord["isOnline"] = 0
                    deviceRecord["lastSeen"] = Date()
                    
                    _ = try await container.privateCloudDatabase.save(deviceRecord)
                    print("Updated device to offline status")
                    return true
                } catch {
                    print("Error updating device record: \(error.localizedDescription)")
                    return false
                }
            }
            
            // No device found
            print("Device not found in CloudKit")
            return false
        } catch {
            print("Error marking device offline: \(error.localizedDescription)")
            throw error
        }
    }
}
#endif 