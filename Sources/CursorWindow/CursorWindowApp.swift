#if os(macOS)
import SwiftUI
import ScreenCaptureKit
import AppKit
import AVFoundation
import CursorWindowCore
import CloudKit

@main
struct CursorWindowApp: App {
    @StateObject private var screenCaptureManager = ScreenCaptureManager()
    @StateObject private var capturePreviewVM = LiveCapturePreviewViewModel()
    @StateObject private var encodingControlVM = LiveEncodingControlViewModel()
    @StateObject private var serverControlVM = ServerControlViewModel()
    
    // App initialization
    init() {
        // Set up CloudKit container if needed
        setupCloudKit()
    }
    
    var body: some Scene {
        WindowGroup("Cursor Mirror") {
            MainView()
                .environment(\.capturePreviewViewModel, capturePreviewVM)
                .environment(\.encodingControlViewModel, encodingControlVM)
                .environmentObject(screenCaptureManager)
                .environmentObject(serverControlVM)
                .onAppear {
                    // Verify iCloud is available when app launches
                    verifyCloudKitAvailability()
                }
        }
    }
    
    // Set up CloudKit container
    private func setupCloudKit() {
        // Verify container configuration
        #if DEBUG
        let container = CKContainer.default()
        print("CloudKit container identifier: \(container.containerIdentifier ?? "Unknown")")
        #endif
    }
    
    // Verify CloudKit availability
    private func verifyCloudKitAvailability() {
        let container = CKContainer.default()
        container.accountStatus { status, error in
            if let error = error {
                print("CloudKit availability check error: \(error.localizedDescription)")
                return
            }
            
            switch status {
            case .available:
                print("CloudKit is available and ready")
            case .noAccount:
                print("No iCloud account found. Please sign in to use CloudKit features.")
            case .restricted:
                print("iCloud account is restricted")
            case .couldNotDetermine:
                print("Could not determine iCloud account status")
            case .temporarilyUnavailable:
                print("iCloud account is temporarily unavailable")
            @unknown default:
                print("Unknown iCloud account status")
            }
        }
    }
}

// MARK: - Live View Models
@MainActor
class LiveCapturePreviewViewModel: ObservableObject, CapturePreviewViewModel {
    nonisolated let frameProcessor: BasicFrameProcessorProtocol
    nonisolated let captureManager: FrameCaptureManagerProtocol
    
    init() {
        // Initialize with your actual implementations
        self.frameProcessor = BasicFrameProcessor()
        self.captureManager = ScreenCaptureManager()
    }
}

@MainActor
class LiveEncodingControlViewModel: ObservableObject, EncodingControlViewModel {
    nonisolated let frameProcessor: EncodingFrameProcessorProtocol
    
    init() {
        // Initialize with your actual implementation
        self.frameProcessor = H264VideoEncoder()
    }
}

#else
#error("CursorWindowApp is only available on macOS 14.0 or later")
#endif 