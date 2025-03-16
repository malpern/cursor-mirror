#if os(macOS)
import SwiftUI
import ScreenCaptureKit
import AppKit
import AVFoundation
import CursorWindowCore

@main
struct CursorWindowApp: App {
    @StateObject private var screenCaptureManager = ScreenCaptureManager()
    @StateObject private var capturePreviewVM = LiveCapturePreviewViewModel()
    @StateObject private var encodingControlVM = LiveEncodingControlViewModel()
    
    var body: some Scene {
        WindowGroup("Cursor Mirror") {
            MainView()
                .environment(\.capturePreviewViewModel, capturePreviewVM)
                .environment(\.encodingControlViewModel, encodingControlVM)
                .environmentObject(screenCaptureManager)
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