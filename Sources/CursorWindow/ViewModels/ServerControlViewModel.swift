import Foundation
import SwiftUI
import CursorWindowCore

/// ViewModel for controlling the HTTP server and stream access
class ServerControlViewModel: ObservableObject {
    private var httpServerManager: HTTPServerManager?
    private var hlsStreamManager: HLSStreamManager?
    
    @Published var isServerRunning = false
    @Published var hostname = "127.0.0.1"
    @Published var port = 8080
    @Published var enableSSL = false
    @Published var adminDashboardEnabled = true
    @Published var streamURL = ""
    @Published var streamActive = false
    @Published var qrCodeImage: NSImage?
    @Published var serverStatus = "Server not running"
    
    init() {
        // Default initialization
        hlsStreamManager = HLSStreamManager()
        let config = HTTPServerConfig(
            hostname: hostname,
            port: port,
            useSSL: enableSSL
        )
        
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
} 