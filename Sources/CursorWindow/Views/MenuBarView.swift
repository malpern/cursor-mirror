import SwiftUI
import CursorWindowCore
import AppKit

@available(macOS 14.0, *)
struct MenuBarView: View {
    @EnvironmentObject var viewportManager: ViewportManager
    @EnvironmentObject private var screenCaptureManager: ScreenCaptureManager
    @State private var isEncoding = false
    @State private var outputPath = NSHomeDirectory() + "/Desktop/output.mp4"
    @State private var showEncodingSettings = false
    @State private var encodingSettings = EncodingSettings()
    
    var body: some View {
        VStack(spacing: 16) {
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
                
                Button(isEncoding ? "Stop Encoding" : "Start Encoding") {
                    isEncoding.toggle()
                    if isEncoding {
                        let encoder = H264VideoEncoder()
                        Task {
                            try? encoder.startEncoding(
                                to: URL(fileURLWithPath: encodingSettings.outputPath),
                                width: encodingSettings.width,
                                height: encodingSettings.height
                            )
                        }
                    } else {
                        // Stop encoding
                    }
                }
                .buttonStyle(.bordered)
                .tint(isEncoding ? .red : .green)
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