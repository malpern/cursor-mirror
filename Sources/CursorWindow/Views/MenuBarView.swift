import SwiftUI
import CursorWindowCore
import AppKit

@available(macOS 14.0, *)
struct MenuBarView: View {
    @EnvironmentObject var viewportManager: ViewportManager
    @EnvironmentObject private var screenCaptureManager: ScreenCaptureManager
    @State private var showEncodingSettings = false
    @State private var encodingSettings = EncodingSettings()
    @StateObject private var encoder = H264VideoEncoder()
    @State private var encodingError: Error?
    @State private var showError = false
    
    var body: some View {
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
                                try await encoder.startEncoding(
                                    to: URL(fileURLWithPath: encodingSettings.outputPath),
                                    width: encodingSettings.width,
                                    height: encodingSettings.height
                                )
                                print("[MenuBarView] Encoder started successfully")
                            } else {
                                print("[MenuBarView] Stopping encoding process...")
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
            // Refresh permission status when the view appears
            Task {
                await screenCaptureManager.forceRefreshPermissionStatus()
            }
        }
    }
}

struct EncodingSettings {
    var outputPath = NSHomeDirectory() + "/Desktop/output.mp4"
    var width = 393
    var height = 852
    var frameRate = 30
    var quality: Double = 0.8
} 