import Foundation
import CloudKit
import SwiftUI
import UIKit  // Required for UIDevice access on iOS

// Protocol for CloudKit database operations we need
protocol CloudKitDatabaseProtocol {
    // Split into multiple lines to fix line length issues
    func records(
        matching query: CKQuery,
        inZoneWith zoneID: CKRecordZone.ID?,
        resultsLimit: Int
    ) async throws -> (
        matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
        queryCursor: CKQueryOperation.Cursor?
    )
    func save(_ record: CKRecord) async throws -> CKRecord
}

// Wrapper class to make CKDatabase conform to our protocol
class CloudKitDatabaseWrapper: CloudKitDatabaseProtocol {
    private let database: CKDatabase
    
    init(_ database: CKDatabase) {
        self.database = database
    }
    
    func records(
        matching query: CKQuery,
        inZoneWith zoneID: CKRecordZone.ID?,
        resultsLimit: Int
    ) async throws -> (
        matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
        queryCursor: CKQueryOperation.Cursor?
    ) {
        return try await database.records(
            matching: query,
            inZoneWith: zoneID,
            desiredKeys: nil,
            resultsLimit: resultsLimit
        )
    }
    
    func save(_ record: CKRecord) async throws -> CKRecord {
        return try await database.save(record)
    }
}

@Observable
class ConnectionViewModel {
    // The connection state that the view will observe
    private(set) var connectionState: ConnectionState
    
    // CloudKit database for device discovery
    private let database: CloudKitDatabaseProtocol
    
    // Stream configuration
    private let streamConfig: StreamConfig
    
    // Task for device discovery
    private var discoveryTask: Task<Void, Never>?
    
    // Flag to prevent multiple discovery operations at once
    private var isDiscovering = false
    
    init(connectionState: ConnectionState = ConnectionState(), 
         streamConfig: StreamConfig = StreamConfig(),
         database: CloudKitDatabaseProtocol? = nil) {
        self.connectionState = connectionState
        self.streamConfig = streamConfig
        self.database = database ?? CloudKitDatabaseWrapper(CKContainer.default().privateCloudDatabase)
    }
    
    deinit {
        // Cancel any ongoing discovery
        cancelDiscovery()
    }
    
    // MARK: - Public Methods
    
    /// Start discovering available devices
    func startDeviceDiscovery() {
        guard !isDiscovering else { return }
        
        isDiscovering = true
        connectionState.status = .disconnected
        
        discoveryTask = Task {
            do {
                // Set up the query for devices
                let query = CKQuery(recordType: "Device", predicate: NSPredicate(value: true))
                query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
                
                let (results, _) = try await database.records(
                    matching: query,
                    inZoneWith: nil,
                    resultsLimit: 0
                )
                
                // Process the results
                let devices = results.compactMap { _, recordResult -> DeviceInfo? in
                    do {
                        let record = try recordResult.get()
                        return DeviceInfo(from: record)
                    } catch {
                        print("Error getting record: \(error.localizedDescription)")
                        return nil
                    }
                }
                
                // Update the connection state on the main thread
                await MainActor.run {
                    connectionState.updateDiscoveredDevices(devices)
                    isDiscovering = false
                }
            } catch {
                await MainActor.run {
                    connectionState.handleError(error)
                    isDiscovering = false
                }
            }
        }
    }
    
    /// Connect to the selected device
    func connectToDevice(_ device: DeviceInfo) {
        connectionState.selectDevice(device)
        
        // Simulate connection process
        Task {
            do {
                // Simulate network delay
                try await Task.sleep(for: .seconds(1.5))
                
                // On successful connection
                await MainActor.run {
                    connectionState.status = .connected
                    connectionState.lastUpdated = Date()
                }
            } catch {
                await MainActor.run {
                    connectionState.handleError(error)
                }
            }
        }
    }
    
    /// Disconnect from the current device
    func disconnect() {
        guard connectionState.status == .connected else { return }
        
        connectionState.status = .disconnecting
        
        // Simulate disconnection process
        Task {
            // Simulate network delay
            try? await Task.sleep(for: .seconds(0.5))
            
            await MainActor.run {
                connectionState.status = .disconnected
                connectionState.selectedDevice = nil
                connectionState.lastUpdated = Date()
            }
        }
    }
    
    /// Clear any errors and reset to disconnected state
    func clearError() {
        connectionState.clearError()
    }
    
    /// Stop ongoing device discovery
    func cancelDiscovery() {
        discoveryTask?.cancel()
        discoveryTask = nil
        isDiscovering = false
    }
    
    // MARK: - Device Management
    
    /// Register this device in CloudKit for discovery by other devices
    func registerThisDevice() async {
        do {
            // Create a unique identifier for this device
            let deviceID = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            
            // Check if this device is already registered
            let query = CKQuery(
                recordType: "Device", 
                predicate: NSPredicate(format: "id == %@", deviceID)
            )
            
            let (results, _) = try await database.records(
                matching: query,
                inZoneWith: nil,
                resultsLimit: 1
            )
            
            // If device exists, update it; otherwise create a new record
            if let recordResult = results.first?.1 {
                let existingRecord: CKRecord
                do {
                    existingRecord = try recordResult.get()
                    existingRecord["name"] = await UIDevice.current.name
                    existingRecord["type"] = await UIDevice.current.model
                    existingRecord["isOnline"] = 1
                    existingRecord["lastSeen"] = Date()
                    
                    _ = try await database.save(existingRecord)
                } catch {
                    print("Error updating existing record: \(error.localizedDescription)")
                    throw error
                }
            } else {
                // Create a new device record
                let newRecord = CKRecord(recordType: "Device")
                newRecord["id"] = deviceID
                newRecord["name"] = await UIDevice.current.name
                newRecord["type"] = await UIDevice.current.model
                newRecord["isOnline"] = 1
                newRecord["lastSeen"] = Date()
                
                _ = try await database.save(newRecord)
            }
        } catch {
            print("Failed to register device: \(error.localizedDescription)")
            // Handle the error but don't update UI state since this is a background operation
        }
    }
    
    /// Get the stream URL for the currently connected device
    func getStreamURL() -> URL? {
        guard let device = connectionState.selectedDevice,
              connectionState.status == .connected else {
            return nil
        }
        
        // Base URL would typically come from the device record or a service discovery
        let baseURL = "http://localhost:8080" // Default for testing
        
        return streamConfig.generateStreamURL(forDevice: device.id, baseURL: baseURL)
    }
    
    /// Send a touch event to the connected device
    func sendTouchEvent(_ event: TouchEvent) async {
        guard connectionState.status == .connected,
              let device = connectionState.selectedDevice else {
            return
        }
        
        // Base URL for API calls
        let baseURLString = "http://localhost:8080" // Default for testing
        
        // Build the URL for the touch event endpoint
        guard let url = URL(string: "\(baseURLString)/api/touch") else {
            print("Invalid URL for touch event")
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // Add device ID and touch event data
            let payload: [String: Any] = [
                "deviceID": device.id,
                "event": try JSONSerialization.jsonObject(with: JSONEncoder().encode(event))
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            // Send the request
            let (_, response) = try await URLSession.shared.data(for: request)
            
            // Check response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Success
                print("Touch event sent successfully")
            } else {
                print("Failed to send touch event, status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
        } catch {
            print("Error sending touch event: \(error.localizedDescription)")
        }
    }
} 