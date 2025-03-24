import Foundation

enum ConnectionStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case disconnecting = "Disconnecting..."
    case error = "Connection Error"
}

@Observable
class ConnectionState {
    var status: ConnectionStatus
    var selectedDevice: DeviceInfo?
    private(set) var lastError: Error?
    private(set) var discoveredDevices: [DeviceInfo]
    var lastUpdated: Date
    
    init(
        status: ConnectionStatus = .disconnected,
        selectedDevice: DeviceInfo? = nil,
        lastError: Error? = nil,
        discoveredDevices: [DeviceInfo] = [],
        lastUpdated: Date = Date()
    ) {
        self.status = status
        self.selectedDevice = selectedDevice
        self.lastError = lastError
        self.discoveredDevices = discoveredDevices
        self.lastUpdated = lastUpdated
    }
    
    func selectDevice(_ device: DeviceInfo) {
        selectedDevice = device
        status = .connecting
    }
    
    func updateDiscoveredDevices(_ devices: [DeviceInfo]) {
        discoveredDevices = devices
    }
    
    func handleError(_ error: Error) {
        lastError = error
        status = .error
    }
    
    func clearError() {
        lastError = nil
        status = .disconnected
    }
}

extension ConnectionState {
    var isConnected: Bool {
        status == .connected
    }
    
    var isConnecting: Bool {
        status == .connecting
    }
    
    var hasError: Bool {
        lastError != nil
    }
    
    var statusText: String {
        if let error = lastError {
            return "Error: \(error.localizedDescription)"
        }
        return status.rawValue
    }
} 