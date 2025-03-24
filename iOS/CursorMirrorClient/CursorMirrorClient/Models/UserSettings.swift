import Foundation
import SwiftUI
import UIKit

@Observable
class UserSettings {
    // MARK: - Connection Settings
    var autoConnect: Bool {
        didSet { save() }
    }
    
    var connectionTimeout: TimeInterval {
        didSet { save() }
    }
    
    var maxReconnectionAttempts: Int {
        didSet { save() }
    }
    
    var rememberLastDevice: Bool {
        didSet { save() }
    }
    
    // MARK: - Video Settings
    var defaultQuality: StreamQuality {
        didSet { save() }
    }
    
    var maxBandwidthUsage: Double {
        didSet { save() }
    }
    
    var bufferSize: Double {
        didSet { save() }
    }
    
    var enableAdaptiveBitrate: Bool {
        didSet { save() }
    }
    
    // MARK: - Touch Settings
    var enableTouchControls: Bool {
        didSet { save() }
    }
    
    var touchSensitivity: Double {
        didSet { save() }
    }
    
    var showTouchIndicator: Bool {
        didSet { save() }
    }
    
    // MARK: - Appearance Settings
    var preferredColorScheme: ColorScheme? {
        didSet { save() }
    }
    
    var interfaceOpacity: Double {
        didSet { save() }
    }
    
    var accentColor: Color {
        didSet { save() }
    }
    
    // MARK: - Sync Settings
    var enableCloudSync: Bool {
        didSet { save() }
    }
    
    var syncLastAttempted: Date? {
        didSet { save() }
    }
    
    var syncLastSuccessful: Date? {
        didSet { save() }
    }
    
    var deviceSpecificSettings: Bool {
        didSet { save() }
    }
    
    // MARK: - Initialization
    
    static let shared = UserSettings()
    private let cloudSync: CloudKitSettingsSyncProtocol
    private let deviceID: String
    
    /// Public initializer that can take a custom CloudKitSettingsSync for testing
    internal init(cloudSync: CloudKitSettingsSyncProtocol? = nil) {
        // Get device ID
        self.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Set default values
        autoConnect = false
        connectionTimeout = 30.0
        maxReconnectionAttempts = 3
        rememberLastDevice = true
        
        defaultQuality = .auto
        maxBandwidthUsage = 0 // Unlimited
        bufferSize = 3.0 // 3 seconds
        enableAdaptiveBitrate = true
        
        enableTouchControls = true
        touchSensitivity = 1.0 // Normal
        showTouchIndicator = true
        
        preferredColorScheme = nil // System default
        interfaceOpacity = 0.8
        accentColor = .blue
        
        // Sync settings
        enableCloudSync = true
        syncLastAttempted = nil
        syncLastSuccessful = nil
        deviceSpecificSettings = true
        
        // Initialize cloud sync
        self.cloudSync = cloudSync ?? CloudKitSettingsSync()
        
        // Load saved settings if available
        load()
    }
    
    // MARK: - Persistence
    
    private let userDefaults = UserDefaults.standard
    internal var settingsKey = "com.cursormirror.userSettings"
    internal var deviceSpecificSettingsKey: String {
        return "\(settingsKey).\(deviceID)"
    }
    
    private func save() {
        saveToDisk()
        
        // Sync to CloudKit if enabled
        if enableCloudSync {
            syncToCloud()
        }
    }
    
    /// Save settings to UserDefaults
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            let settingsData = try encoder.encode(self.asDictionary())
            
            // Save to appropriate key based on device-specific setting
            let key = deviceSpecificSettings ? deviceSpecificSettingsKey : settingsKey
            userDefaults.set(settingsData, forKey: key)
            userDefaults.synchronize()
        } catch {
            print("Error saving settings to disk: \(error.localizedDescription)")
        }
    }
    
    /// Sync settings to CloudKit
    private func syncToCloud() {
        // Update sync timestamp
        syncLastAttempted = Date()
        
        Task {
            do {
                // Sync to CloudKit
                try await cloudSync.syncSettings(self.asDictionary(), forDeviceID: deviceID)
                
                // Update last successful sync time
                await MainActor.run {
                    syncLastSuccessful = Date()
                    saveToDisk() // Save the updated sync timestamps
                }
            } catch {
                print("Error syncing settings to CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    /// Load settings from disk and CloudKit
    internal func load() {
        // First load from disk
        loadFromDisk()
        
        // Then try to load from CloudKit if enabled
        if enableCloudSync {
            loadFromCloud()
        }
    }
    
    /// Load settings from UserDefaults
    private func loadFromDisk() {
        // Determine which key to use based on device-specific setting
        let key = deviceSpecificSettings ? deviceSpecificSettingsKey : settingsKey
        
        guard let settingsData = userDefaults.data(forKey: key) else { return }
        
        do {
            let decoder = JSONDecoder()
            if let settingsDict = try decoder.decode([String: Any].self, from: settingsData) as? [String: Any] {
                self.update(from: settingsDict)
            }
        } catch {
            print("Error loading settings from disk: \(error.localizedDescription)")
        }
    }
    
    /// Load settings from CloudKit
    private func loadFromCloud() {
        Task {
            do {
                // Load from CloudKit
                if let cloudSettings = try await cloudSync.loadSettings(forDeviceID: deviceID) {
                    // Update settings on main thread
                    await MainActor.run {
                        self.update(from: cloudSettings)
                        syncLastSuccessful = Date()
                        saveToDisk() // Save the merged settings
                    }
                }
            } catch {
                print("Error loading settings from CloudKit: \(error.localizedDescription)")
            }
        }
    }
    
    /// Reset settings to default values
    func resetToDefaults() {
        autoConnect = false
        connectionTimeout = 30.0
        maxReconnectionAttempts = 3
        rememberLastDevice = true
        
        defaultQuality = .auto
        maxBandwidthUsage = 0 // Unlimited
        bufferSize = 3.0 // 3 seconds
        enableAdaptiveBitrate = true
        
        enableTouchControls = true
        touchSensitivity = 1.0 // Normal
        showTouchIndicator = true
        
        preferredColorScheme = nil // System default
        interfaceOpacity = 0.8
        accentColor = .blue
        
        // Keep sync settings as they are
        
        save()
        
        // If cloud sync is enabled, also clear cloud settings
        if enableCloudSync {
            Task {
                do {
                    try await cloudSync.deleteSettings(forDeviceID: deviceID)
                } catch {
                    print("Error deleting cloud settings: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Toggle device-specific settings
    func toggleDeviceSpecificSettings() {
        let oldValue = deviceSpecificSettings
        deviceSpecificSettings = !oldValue
        
        // If turning on device-specific settings, migrate existing settings
        if deviceSpecificSettings && !oldValue {
            // Current settings are already stored in the object
            // Just save them to the device-specific key
            saveToDisk()
        } else if !deviceSpecificSettings && oldValue {
            // If turning off device-specific settings, load global settings
            let tempSettings = userDefaults.data(forKey: settingsKey)
            if tempSettings != nil {
                // Global settings exist, load them
                loadFromDisk()
            } else {
                // No global settings, save current as global
                saveToDisk()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        // Connection settings
        dict["autoConnect"] = autoConnect
        dict["connectionTimeout"] = connectionTimeout
        dict["maxReconnectionAttempts"] = maxReconnectionAttempts
        dict["rememberLastDevice"] = rememberLastDevice
        
        // Video settings
        dict["defaultQuality"] = defaultQuality.rawValue
        dict["maxBandwidthUsage"] = maxBandwidthUsage
        dict["bufferSize"] = bufferSize
        dict["enableAdaptiveBitrate"] = enableAdaptiveBitrate
        
        // Touch settings
        dict["enableTouchControls"] = enableTouchControls
        dict["touchSensitivity"] = touchSensitivity
        dict["showTouchIndicator"] = showTouchIndicator
        
        // Appearance settings
        if let scheme = preferredColorScheme {
            dict["preferredColorScheme"] = scheme == .dark ? "dark" : "light"
        } else {
            dict["preferredColorScheme"] = "system"
        }
        dict["interfaceOpacity"] = interfaceOpacity
        
        // For Color, we need to store RGB values
        if let components = UIColor(accentColor).cgColor.components {
            dict["accentColorR"] = components[0]
            dict["accentColorG"] = components[1]
            dict["accentColorB"] = components[2]
            dict["accentColorA"] = components[3]
        }
        
        // Sync settings
        dict["enableCloudSync"] = enableCloudSync
        dict["deviceSpecificSettings"] = deviceSpecificSettings
        if let syncLastAttempted = syncLastAttempted {
            dict["syncLastAttempted"] = syncLastAttempted.timeIntervalSince1970
        }
        if let syncLastSuccessful = syncLastSuccessful {
            dict["syncLastSuccessful"] = syncLastSuccessful.timeIntervalSince1970
        }
        
        return dict
    }
    
    private func update(from dict: [String: Any]) {
        // Connection settings
        autoConnect = dict["autoConnect"] as? Bool ?? autoConnect
        connectionTimeout = dict["connectionTimeout"] as? TimeInterval ?? connectionTimeout
        maxReconnectionAttempts = dict["maxReconnectionAttempts"] as? Int ?? maxReconnectionAttempts
        rememberLastDevice = dict["rememberLastDevice"] as? Bool ?? rememberLastDevice
        
        // Video settings
        if let qualityString = dict["defaultQuality"] as? String,
           let quality = StreamQuality(rawValue: qualityString) {
            defaultQuality = quality
        }
        maxBandwidthUsage = dict["maxBandwidthUsage"] as? Double ?? maxBandwidthUsage
        bufferSize = dict["bufferSize"] as? Double ?? bufferSize
        enableAdaptiveBitrate = dict["enableAdaptiveBitrate"] as? Bool ?? enableAdaptiveBitrate
        
        // Touch settings
        enableTouchControls = dict["enableTouchControls"] as? Bool ?? enableTouchControls
        touchSensitivity = dict["touchSensitivity"] as? Double ?? touchSensitivity
        showTouchIndicator = dict["showTouchIndicator"] as? Bool ?? showTouchIndicator
        
        // Appearance settings
        if let schemeString = dict["preferredColorScheme"] as? String {
            switch schemeString {
            case "dark":
                preferredColorScheme = .dark
            case "light":
                preferredColorScheme = .light
            default:
                preferredColorScheme = nil
            }
        }
        
        interfaceOpacity = dict["interfaceOpacity"] as? Double ?? interfaceOpacity
        
        // Reconstruct color from components
        if let r = dict["accentColorR"] as? CGFloat,
           let g = dict["accentColorG"] as? CGFloat,
           let b = dict["accentColorB"] as? CGFloat,
           let a = dict["accentColorA"] as? CGFloat {
            accentColor = Color(uiColor: UIColor(red: r, green: g, blue: b, alpha: a))
        }
        
        // Sync settings (only update if present in dictionary)
        if let enableCloudSyncValue = dict["enableCloudSync"] as? Bool {
            enableCloudSync = enableCloudSyncValue
        }
        if let deviceSpecificSettingsValue = dict["deviceSpecificSettings"] as? Bool {
            deviceSpecificSettings = deviceSpecificSettingsValue
        }
        if let syncLastAttemptedTimestamp = dict["syncLastAttempted"] as? TimeInterval {
            syncLastAttempted = Date(timeIntervalSince1970: syncLastAttemptedTimestamp)
        }
        if let syncLastSuccessfulTimestamp = dict["syncLastSuccessful"] as? TimeInterval {
            syncLastSuccessful = Date(timeIntervalSince1970: syncLastSuccessfulTimestamp)
        }
    }
}

// MARK: - Extensions for UserSettings Compatibility

extension JSONEncoder {
    func encode(_ value: [String: Any]) throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: value)
        return data
    }
}

extension JSONDecoder {
    func decode(_ type: [String: Any].Type, from data: Data) throws -> Any {
        let result = try JSONSerialization.jsonObject(with: data)
        return result
    }
} 