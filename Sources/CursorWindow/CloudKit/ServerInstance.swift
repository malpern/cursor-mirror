#if os(macOS)
import Foundation
import CloudKit

/// Model class for a server instance record from CloudKit
class ServerInstance {
    /// Unique identifier for the device
    let deviceIdentifier: String
    
    /// Device name
    let deviceName: String
    
    /// Whether the server is currently running
    let isServerRunning: Bool
    
    /// List of network addresses for the server
    let networkAddresses: [String]
    
    /// When the record was last updated
    let lastUpdated: Date
    
    /// Stream configuration
    let streamConfig: [String: Any]
    
    /// The CloudKit record
    let record: CKRecord
    
    /// Initialize from a CloudKit record
    init?(from record: CKRecord) {
        guard record.recordType == CloudKitRecordType.serverInstance,
              let deviceIdentifier = record[ServerInstanceField.deviceIdentifier] as? String,
              let deviceName = record[ServerInstanceField.deviceName] as? String,
              let isServerRunning = record[ServerInstanceField.serverStatus] as? Bool,
              let lastUpdated = record[ServerInstanceField.lastUpdated] as? Date else {
            return nil
        }
        
        self.record = record
        self.deviceIdentifier = deviceIdentifier
        self.deviceName = deviceName
        self.isServerRunning = isServerRunning
        self.lastUpdated = lastUpdated
        
        // Handle optional fields
        if let addresses = record[ServerInstanceField.networkAddresses] as? [String] {
            self.networkAddresses = addresses
        } else {
            self.networkAddresses = []
        }
        
        if let config = record[ServerInstanceField.streamConfig] as? [String: Any] {
            self.streamConfig = config
        } else {
            self.streamConfig = [:]
        }
    }
    
    /// Get the hostname from the stream configuration
    var hostname: String {
        return streamConfig["hostname"] as? String ?? "127.0.0.1"
    }
    
    /// Get the port from the stream configuration
    var port: Int {
        return streamConfig["port"] as? Int ?? 8080
    }
    
    /// Get the SSL setting from the stream configuration
    var useSSL: Bool {
        return streamConfig["useSSL"] as? Bool ?? false
    }
    
    /// Get the stream URL for this server instance
    var streamURL: String {
        let protocol = useSSL ? "https" : "http"
        
        // Prefer the first non-loopback address, if available
        if let address = networkAddresses.first(where: { 
            !$0.hasPrefix("127.") && !$0.hasPrefix("::1") && !$0.hasPrefix("fe80")
        }) {
            return "\(protocol)://\(address):\(port)/stream/index.m3u8"
        }
        
        // Fall back to the hostname
        return "\(protocol)://\(hostname):\(port)/stream/index.m3u8"
    }
    
    /// Create array of server instances from CloudKit records
    static func createFrom(records: [CKRecord]) -> [ServerInstance] {
        return records.compactMap { ServerInstance(from: $0) }
    }
}
#endif 