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
    @State private var serverManager = HTTPServerManager.shared
    @State private var isServerRunning = false
    @State private var isEncoding = false
    @State private var encodingError: Error?
    @State private var showError = false
    
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
                Button {
                    Task {
                        if !screenCaptureManager.isCapturing {
                            // Set the capturing state immediately for UI feedback
                            screenCaptureManager.setManualCapturingState(true)
                            
                            do {
                                print("Starting capture...")
                                try await screenCaptureManager.startCaptureForViewport(
                                    frameProcessor: BasicFrameProcessor(),
                                    viewportManager: viewportManager
                                )
                                print("Capture started successfully")
                            } catch {
                                // Revert on error
                                screenCaptureManager.setManualCapturingState(false)
                                print("Capture error: \(error)")
                                encodingError = error
                                showError = true
                            }
                        } else {
                            // Set the capturing state immediately for UI feedback
                            screenCaptureManager.setManualCapturingState(false)
                            
                            do {
                                print("Stopping capture...")
                                try await screenCaptureManager.stopCapture()
                                print("Capture stopped successfully")
                            } catch {
                                // Revert on error
                                screenCaptureManager.setManualCapturingState(true)
                                print("Capture error: \(error)")
                                encodingError = error
                                showError = true
                            }
                        }
                    }
                } label: {
                    Text(screenCaptureManager.isCapturing ? "Stop Capture" : "Start Capture")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(screenCaptureManager.isCapturing ? .red : .blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 3. SERVER BUTTON
                Button(action: {
                    Task {
                        do {
                            if isServerRunning {
                                try await serverManager.stop()
                                isServerRunning = false
                            } else {
                                try await serverManager.start()
                                isServerRunning = true
                            }
                        } catch {
                            print("Error toggling server: \(error)")
                            await MainActor.run {
                                self.encodingError = error
                                self.showError = true
                            }
                        }
                    }
                }) {
                    Text(isServerRunning ? "Stop Server" : "Start Server")
                }
                .buttonStyle(.borderedProminent)
                .tint(isServerRunning ? .red : .blue)
                .disabled(!screenCaptureManager.isCapturing) // Direct check against the screenCaptureManager.isCapturing property
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
                                    try serverManager.connectVideoEncoder(encoder)
                                    
                                    try await encoder.startEncoding(
                                        to: URL(fileURLWithPath: encodingSettings.outputPath),
                                        width: encodingSettings.width,
                                        height: encodingSettings.height
                                    )
                                    print("[MenuBarView] Encoder started successfully")
                                    
                                    // Start streaming through HTTP server
                                    try await serverManager.startStreaming()
                                } else {
                                    print("[MenuBarView] Stopping encoding process...")
                                    try? await serverManager.stopStreaming()
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
                Task { @MainActor in
                    print("User initiated quit from menu bar")
                    
                    // First try a normal termination
                    NSApp.terminate(nil)
                    
                    // If terminate gets stuck due to CloudKit, force quit after 1.5 seconds
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) {
                        print("Termination taking too long, forcing exit...")
                        AppDelegate.immediateForceQuit()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keyboardShortcut("q", modifiers: [.command])
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
            // Refresh server status when the view appears
            isServerRunning = serverManager.isRunning
            
            // Refresh permission status when the view appears
            Task {
                await screenCaptureManager.forceRefreshPermissionStatus()
            }
        }
    }
} 