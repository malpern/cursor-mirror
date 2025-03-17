import Foundation
import SwiftUI
import CursorWindowCore

/// ViewModel for controlling the HTTP server and stream access
class ServerControlViewModel: ObservableObject {
    private var httpServerManager: HTTPServerManager?
    private var hlsStreamManager: HLSStreamManager?
    private var cloudKitManager: CloudKitManager?
    
    @Published var isServerRunning = false
    @Published var hostname = "127.0.0.1"
    @Published var port = 8080
    @Published var enableSSL = false
    @Published var adminDashboardEnabled = true
    @Published var streamURL = ""
    @Published var streamActive = false
    @Published var qrCodeImage: NSImage?
    @Published var serverStatus = "Server not running"
    
    // CloudKit status
    @Published var iCloudAvailable = false
    @Published var iCloudStatus = "Checking iCloud availability..."
    @Published var deviceName = Host.current().localizedName ?? "My Mac"
    
    // Add this property to ServerControlViewModel
    @Published var availableServers: [ServerInstance] = []
    
    init() {
        // Default initialization
        hlsStreamManager = HLSStreamManager()
        let config = HTTPServerConfig(
            hostname: hostname,
            port: port,
            useSSL: enableSSL
        )
        
        // Save server configuration to UserDefaults
        saveServerConfigToUserDefaults()
        
        // Initialize CloudKit manager
        setupCloudKit()
        
        Task {
            do {
                httpServerManager = try await HTTPServerManager(
                    config: config,
                    streamManager: hlsStreamManager ?? HLSStreamManager(),
                    authManager: AuthenticationManager(username: "admin", password: "admin")
                )
                await MainActor.run {
                    self.serverStatus = "Server initialized"
                }
            } catch {
                await MainActor.run {
                    self.serverStatus = "Error initializing server: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func startServer() async throws {
        guard let httpServerManager = httpServerManager, !isServerRunning else {
            return
        }
        
        // Update config if needed
        let config = HTTPServerConfig(
            hostname: hostname,
            port: port,
            useSSL: enableSSL,
            enableAdmin: adminDashboardEnabled
        )
        
        // Create new server manager with updated config if needed
        
        try await httpServerManager.start()
        
        await MainActor.run {
            isServerRunning = true
            updateStreamURL()
            serverStatus = "Server running"
            generateQRCode()
            
            // Save server configuration to UserDefaults
            saveServerConfigToUserDefaults()
            
            // Update CloudKit with server status
            updateCloudKitServerStatus()
        }
    }
    
    func stopServer() async throws {
        guard let httpServerManager = httpServerManager, isServerRunning else {
            return
        }
        
        try await httpServerManager.stop()
        
        await MainActor.run {
            isServerRunning = false
            streamURL = ""
            qrCodeImage = nil
            serverStatus = "Server stopped"
            
            // Update CloudKit with server status
            updateCloudKitServerStatus()
        }
    }
    
    func toggleServer() async {
        do {
            if isServerRunning {
                try await stopServer()
            } else {
                try await startServer()
            }
        } catch {
            await MainActor.run {
                serverStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    func openAdminDashboard() {
        guard isServerRunning, let url = URL(string: "http\(enableSSL ? "s" : "")://\(hostname):\(port)/admin") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    func checkStreamStatus() async {
        guard let hlsStreamManager = hlsStreamManager else {
            return
        }
        
        // Try to get access - if it fails, a stream is active
        do {
            let token = try await hlsStreamManager.requestAccess()
            await hlsStreamManager.releaseAccess(token)
            await MainActor.run {
                streamActive = false
            }
        } catch {
            await MainActor.run {
                streamActive = true
            }
        }
    }
    
    private func updateStreamURL() {
        streamURL = "http\(enableSSL ? "s" : "")://\(hostname):\(port)/stream/index.m3u8"
    }
    
    func copyStreamURLToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(streamURL, forType: .string)
    }
    
    private func generateQRCode() {
        guard !streamURL.isEmpty else {
            qrCodeImage = nil
            return
        }
        
        // Use our QRCodeGenerator utility
        if let appIcon = NSImage(named: "AppIcon") {
            // Generate QR code with app logo
            qrCodeImage = QRCodeGenerator.generateStyledQRCode(
                from: streamURL,
                size: 250,
                logo: appIcon,
                logoSize: 0.25,
                foregroundColor: .black,
                backgroundColor: .white
            )
        } else {
            // Fallback to basic QR code
            qrCodeImage = QRCodeGenerator.generateQRCode(from: streamURL, size: 250)
        }
    }
    
    // MARK: - CloudKit Integration
    
    private func setupCloudKit() {
        // Initialize CloudKit manager
        cloudKitManager = CloudKitManager()
        
        // Start network address monitoring
        NetworkAddressDetector.shared.startMonitoring { [weak self] addresses in
            self?.updateCloudKitServerStatus()
        }
        
        // Start CloudKit services
        cloudKitManager?.start()
        
        // Subscribe to server instances changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleServerInstancesChanged(_:)),
            name: .serverInstancesChanged,
            object: nil
        )
        
        // Set up other CloudKit observers
        setupCloudKitObservers()
    }
    
    private func setupCloudKitObservers() {
        // Subscribe to CloudKit status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitStatusChanged(_:)),
            name: .cloudKitStatusChanged,
            object: nil
        )
        
        // Subscribe to record save errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitSaveError(_:)),
            name: .cloudKitRecordSaveError,
            object: nil
        )
        
        // Subscribe to record saved notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitRecordSaved(_:)),
            name: .cloudKitRecordSaved,
            object: nil
        )
    }
    
    @objc private func handleServerInstancesChanged(_ notification: Notification) {
        if let records = notification.userInfo?["records"] as? [CKRecord] {
            DispatchQueue.main.async {
                self.iCloudAvailable = true
                self.iCloudStatus = "Connected to iCloud"
                
                // Convert records to ServerInstance objects
                self.availableServers = ServerInstance.createFrom(records: records)
            }
        }
    }
    
    @objc private func handleCloudKitStatusChanged(_ notification: Notification) {
        if let status = notification.userInfo?["status"] as? String, status == "available" {
            DispatchQueue.main.async {
                self.iCloudAvailable = true
                self.iCloudStatus = "Connected to iCloud"
            }
        } else if let error = notification.userInfo?["error"] as? CloudKitError {
            DispatchQueue.main.async {
                self.iCloudAvailable = false
                self.iCloudStatus = "iCloud error: \(error.localizedDescription)"
            }
        }
    }
    
    @objc private func handleCloudKitSaveError(_ notification: Notification) {
        if let error = notification.userInfo?["error"] as? CloudKitError {
            DispatchQueue.main.async {
                self.iCloudStatus = "Error saving to iCloud: \(error.localizedDescription)"
            }
        }
    }
    
    @objc private func handleCloudKitRecordSaved(_ notification: Notification) {
        DispatchQueue.main.async {
            self.iCloudStatus = "iCloud record updated successfully"
        }
    }
    
    private func updateCloudKitServerStatus() {
        // Get current network addresses
        let addresses = NetworkAddressDetector.shared.currentAddresses
        
        // Update CloudKit with current server status
        cloudKitManager?.updateServerStatus(isRunning: isServerRunning, addresses: addresses)
    }
    
    private func saveServerConfigToUserDefaults() {
        UserDefaults.standard.set(hostname, forKey: "server_hostname")
        UserDefaults.standard.set(port, forKey: "server_port")
        UserDefaults.standard.set(enableSSL, forKey: "server_useSSL")
        UserDefaults.standard.set(adminDashboardEnabled, forKey: "server_adminEnabled")
    }
} 