import SwiftUI
import CursorWindowCore
import AppKit
import Logging
import Vapor

@available(macOS 14.0, *)
struct MenuBarView: SwiftUI.View {
    @EnvironmentObject var viewportManager: ViewportManager
    @EnvironmentObject private var screenCaptureManager: ScreenCaptureManager
    @State private var showEncodingSettings = false
    @State private var encodingSettings = EncodingSettings()
    @StateObject private var encoder = H264VideoEncoder()
    @State private var encodingError: Error?
    @State private var showError = false
    @State var serverManager: HTTPServerManager?
    @State private var isServerRunning = false
    
    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            if screenCaptureManager.isScreenCapturePermissionGranted {
                // 1. VIEWPORT BUTTON (converted from toggle)
                Button(viewportManager.isVisible ? "Hide Viewport" : "Show Viewport") {
                    if !viewportManager.isVisible {
                        viewportManager.showViewport()
                    } else {
                        viewportManager.hideViewport()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(viewportManager.isVisible ? .red : .blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 2. CAPTURE BUTTON
                Button(screenCaptureManager.isCapturing ? "Stop Capture" : "Start Capture") {
                    Task {
                        do {
                            if !screenCaptureManager.isCapturing {
                                print("Starting capture...")
                                try await screenCaptureManager.startCaptureForViewport(
                                    frameProcessor: BasicFrameProcessor(),
                                    viewportManager: viewportManager
                                )
                                print("Capture started successfully")
                            } else {
                                print("Stopping capture...")
                                try await screenCaptureManager.stopCapture()
                                print("Capture stopped successfully")
                            }
                        } catch {
                            print("Capture error: \(error)")
                            encodingError = error
                            showError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(screenCaptureManager.isCapturing ? .red : .blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 3. SERVER BUTTON
                Button(isServerRunning ? "Stop Server" : "Start Server") {
                    Task {
                        do {
                            if isServerRunning {
                                try await serverManager?.stop()
                                // Update UI on main thread immediately
                                await MainActor.run {
                                    isServerRunning = false
                                }
                            } else {
                                try await serverManager?.start()
                                // Update UI on main thread immediately
                                await MainActor.run {
                                    isServerRunning = true
                                }
                            }
                        } catch {
                            print("Server error: \(error)")
                            encodingError = error
                            showError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isServerRunning ? .red : .blue)
                .disabled(encoder.isEncoding && !isServerRunning)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if isServerRunning {
                    Text("Server running at:")
                        .font(.caption)
                    Text("http://localhost:8080")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            NSWorkspace.shared.open(URL(string: "http://localhost:8080")!)
                        }
                }
                
                // 4. ENCODING BUTTON WITH SETTINGS ICON
                HStack(spacing: 8) {
                    Button(encoder.isEncoding ? "Stop Encoding" : "Start Encoding") {
                        Task {
                            do {
                                if !encoder.isEncoding {
                                    print("[MenuBarView] Starting encoding process...")
                                    print("[MenuBarView] Initializing encoder with settings - Path: \(encodingSettings.outputPath), Dimensions: \(encodingSettings.width)x\(encodingSettings.height)")
                                    
                                    // Connect encoder to HTTP server for streaming
                                    try serverManager?.connectVideoEncoder(encoder)
                                    
                                    try await encoder.startEncoding(
                                        to: URL(fileURLWithPath: encodingSettings.outputPath),
                                        width: encodingSettings.width,
                                        height: encodingSettings.height
                                    )
                                    print("[MenuBarView] Encoder started successfully")
                                    
                                    // Start streaming through HTTP server
                                    try await serverManager?.startStreaming()
                                } else {
                                    print("[MenuBarView] Stopping encoding process...")
                                    try? await serverManager?.stopStreaming()
                                    Task {
                                        await encoder.stopEncoding()
                                    }
                                }
                            } catch {
                                print("[MenuBarView] Encoding error: \(error)")
                                encodingError = error
                                showError = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(encoder.isEncoding ? .red : .blue)
                    .disabled(!screenCaptureManager.isCapturing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Settings gear icon
                    Button(action: {
                        showEncodingSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .help("Encoding Settings")
                }
                
                Divider()
                
            } else {
                // Show permission UI if permission not granted
                Text("Screen Recording Permission Required")
                    .font(.headline)
                
                Text("Cursor Window needs permission to capture your screen.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                
                if screenCaptureManager.isCheckingPermission {
                    ProgressView()
                        .padding(.vertical, 8)
                    Text("Checking permission status...")
                        .font(.caption)
                } else {
                    Button("Check Permission Status") {
                        Task {
                            await screenCaptureManager.forceRefreshPermissionStatus()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button("Open System Settings") {
                    screenCaptureManager.openSystemPreferencesScreenCapture()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(screenCaptureManager.isCheckingPermission)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
            }
            
            Button("Quit") {
                // First make sure the server is stopped
                if isServerRunning {
                    Task {
                        do {
                            try await serverManager?.stop()
                        } catch {
                            print("Error stopping server during quit: \(error)")
                        }
                        
                        // Add a small delay to allow for cleanup
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        
                        // Then terminate the app
                        NSApp.terminate(nil)
                    }
                } else {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(width: 250)
        .sheet(isPresented: $showEncodingSettings) {
            EncodingSettingsView(settings: $encodingSettings)
        }
        .alert("Encoding Error", isPresented: $showError, presenting: encodingError) { _ in
            Button("OK") {
                showError = false
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .onAppear {
            // Initialize server manager
            if serverManager == nil {
                serverManager = HTTPServerManager(
                    config: ServerConfig(hostname: "localhost", port: 8080),
                    logger: Logger(label: "com.cursor-window.server"),
                    streamManager: HLSStreamManager(),
                    authManager: AuthenticationManager()
                )
            }
            
            // Check if server is running
            isServerRunning = serverManager?.isRunning ?? false
            
            // Refresh permission status when the view appears
            Task {
                await screenCaptureManager.forceRefreshPermissionStatus()
            }
        }
    }
}

struct EncodingSettings {
    var outputPath = NSHomeDirectory() + "/Desktop/output.mov"
    var width = 393
    var height = 852
    var frameRate = 30
    var quality: Double = 0.8
} 