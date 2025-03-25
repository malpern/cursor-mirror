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
    
    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            if screenCaptureManager.isScreenCapturePermissionGranted {
                // Show normal UI if permission granted
                Toggle("Show Viewport", isOn: Binding(
                    get: { viewportManager.isVisible },
                    set: { newValue in
                        if newValue {
                            viewportManager.showViewport()
                        } else {
                            viewportManager.hideViewport()
                        }
                    }
                ))
                .toggleStyle(.switch)
                
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
                .tag("captureButton")
                
                Divider()
                
                Button("Encoding Settings...") {
                    showEncodingSettings.toggle()
                }
                
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
                .buttonStyle(.bordered)
                .tint(encoder.isEncoding ? .red : .green)
                .disabled(!screenCaptureManager.isCapturing)
                
                Divider()
                
                // HTTP Server Controls
                Button(serverManager?.isRunning == true ? "Stop Server" : "Start Server") {
                    Task {
                        do {
                            if serverManager?.isRunning == true {
                                try await serverManager?.stop()
                            } else {
                                try await serverManager?.start()
                            }
                        } catch {
                            print("Server error: \(error)")
                            encodingError = error
                            showError = true
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(serverManager?.isRunning == true ? .red : .green)
                
                if serverManager?.isRunning == true {
                    Text("Server running at:")
                        .font(.caption)
                    Text("http://localhost:8080")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
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
                    .buttonStyle(.bordered)
                }
                
                Button("Open System Settings") {
                    screenCaptureManager.openSystemPreferencesScreenCapture()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(screenCaptureManager.isCheckingPermission)
            }
            
            Divider()
            
            Button("Quit") {
                NSApp.terminate(nil)
            }
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