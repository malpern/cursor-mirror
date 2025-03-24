import Foundation
@testable import CursorMirrorClient

class MockCloudKitSettingsSync: CloudKitSettingsSyncProtocol {
    // Storage for settings by device ID
    private var storage: [String: [String: Any]] = [:]
    
    // Flags to track method calls
    var syncCalled = false
    var loadCalled = false
    var deleteCalled = false
    
    // Error simulation
    var shouldFailSync = false
    var shouldFailLoad = false
    var shouldFailDelete = false
    
    // Last used device ID
    var lastDeviceID: String?
    
    func syncSettings(_ settings: [String: Any], forDeviceID deviceID: String) async throws {
        syncCalled = true
        lastDeviceID = deviceID
        
        if shouldFailSync {
            throw MockError.failedToSync
        }
        
        storage[deviceID] = settings
    }
    
    func loadSettings(forDeviceID deviceID: String) async throws -> [String: Any]? {
        loadCalled = true
        lastDeviceID = deviceID
        
        if shouldFailLoad {
            throw MockError.failedToLoad
        }
        
        return storage[deviceID]
    }
    
    func deleteSettings(forDeviceID deviceID: String) async throws {
        deleteCalled = true
        lastDeviceID = deviceID
        
        if shouldFailDelete {
            throw MockError.failedToDelete
        }
        
        storage.removeValue(forKey: deviceID)
    }
    
    // Helper method to reset the mock state for testing
    func reset() {
        storage.removeAll()
        syncCalled = false
        loadCalled = false
        deleteCalled = false
        shouldFailSync = false
        shouldFailLoad = false
        shouldFailDelete = false
        lastDeviceID = nil
    }
    
    // Custom error type for testing
    enum MockError: Error {
        case failedToSync
        case failedToLoad
        case failedToDelete
    }
} 