import Foundation
import CloudKit

#if os(macOS)
/// Service to register this device with CloudKit
@globalActor
public actor DeviceRegistrationActor {
    static public let shared = DeviceRegistrationActor()
    
    public func createService() -> DeviceRegistrationService {
        return DeviceRegistrationService()
    }
}

open class DeviceRegistrationService: DeviceRegistrationServiceProtocol {
    // CloudKit container
    private let container: CloudKitContainerProtocol
    
    // Device information
    private let deviceName: String
    private let deviceID: String
    private let deviceType: String
    
    /// Initialize the device registration service
    /// - Parameter container: CloudKit container to use
    public init(
        container: CloudKitContainerProtocol = CloudKitContainerWrapper(CKContainer(identifier: "iCloud.com.cursormirror.client")),
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
    open func registerDevice(serverIP: String = ServerConfig.getLocalIPAddress()) async throws -> Bool {
        print("Registering device with server IP: \(serverIP)")
        
        // Check iCloud account status with retry
        let status = try await withRetry(maxAttempts: 3, delay: 0.5) {
            try await checkiCloudAccountStatus()
        }
        
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
            // Check if device already exists with retry
            let (results, _) = try await withRetry(maxAttempts: 3, delay: 0.5) {
                try await container.privateCloudDatabase.records(
                    matching: query,
                    inZoneWith: nil,
                    desiredKeys: nil,
                    resultsLimit: 1
                )
            }
            
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
                    
                    // Save with retry
                    _ = try await withRetry(maxAttempts: 3, delay: 0.5) {
                        try await container.privateCloudDatabase.save(existingRecord)
                    }
                    print("Updated existing device record with server IP: \(serverIP)")
                    return true
                } catch {
                    print("Error updating device record: \(error.localizedDescription)")
                    throw error
                }
            }
            
            // Create a new device record
            let newRecord = CKRecord(recordType: "Device")
            newRecord["id"] = deviceID
            newRecord["name"] = deviceName
            newRecord["type"] = deviceType
            newRecord["isOnline"] = 1
            newRecord["lastSeen"] = Date()
            newRecord["serverAddress"] = serverIP
            
            // Save with retry
            _ = try await withRetry(maxAttempts: 3, delay: 0.5) {
                try await container.privateCloudDatabase.save(newRecord)
            }
            print("Created new device record with server IP: \(serverIP)")
            return true
        } catch {
            print("Error registering device: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Helper function to retry an operation with exponential backoff
    private func withRetry<T>(maxAttempts: Int, delay: TimeInterval, operation: () async throws -> T) async throws -> T {
        var attempts = 0
        var lastError: Error?
        
        while attempts < maxAttempts {
            do {
                return try await operation()
            } catch {
                attempts += 1
                lastError = error
                print("Operation failed (attempt \(attempts)/\(maxAttempts)): \(error.localizedDescription)")
                
                if attempts < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * Double(attempts) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NSError(domain: "DeviceRegistrationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation failed after \(maxAttempts) attempts"])
    }
    
    /// Check iCloud account status
    private func checkiCloudAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
    
    /// Mark this device as offline in CloudKit
    /// - Returns: Success or failure
    open class func markOffline(deviceID: String? = nil) async throws -> Bool {
        let container = CloudKitContainerWrapper(CKContainer(identifier: "iCloud.com.cursormirror.client"))
        let deviceID = deviceID ?? Host.current().localizedName ?? "MacBook"
        
        // Check the account status first
        let status = try await container.accountStatus()
        guard status == .available else {
            print("iCloud account unavailable with status: \(status.rawValue)")
            return false
        }
        
        // Create a query to find this device
        let query = CKQuery(
            recordType: "Device",
            predicate: NSPredicate(format: "id == %@", deviceID)
        )
        
        do {
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
    
    /// Register the device with CloudKit
    /// - Parameter serverIP: The IP address of the server
    /// - Returns: True if registration was successful, false otherwise
    public func registerDeviceSync(serverIP: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        Task {
            do {
                success = try await registerDevice(serverIP: serverIP)
                semaphore.signal()
            } catch {
                print("Error registering device: \(error.localizedDescription)")
                semaphore.signal()
            }
        }
        
        _ = semaphore.wait(timeout: .now() + 5.0)
        return success
    }
}
#endif 