#if os(macOS)
import SwiftUI
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif
import AVFoundation
import CursorWindowCore

struct MainView: View {
    @Environment(\.encodingControlViewModel) private var viewModel
    @State private var localSettings: EncodingSettings?
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading settings...")
            } else if let settings = localSettings {
                EncodingSettingsFormView(
                    settings: settings,
                    onUpdate: { update in
                        await settings.apply(update)
                    }
                )
            }
        }
        .task {
            do {
                localSettings = await viewModel?.encodingSettings
                isLoading = false
            } catch {
                print("Error loading settings: \(error)")
            }
        }
    }
}

struct CapturePreviewView: View {
    let viewModel: CapturePreviewViewModel
    @EnvironmentObject var screenCaptureManager: ScreenCaptureManager
    
    var body: some View {
        VStack {
            Text("Position the viewport over the area you want to capture")
                .font(.headline)
                .padding()
            
            ZStack {
                Color.black.opacity(0.1)
                    .edgesIgnoringSafeArea(.all)
                
                DraggableViewport()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack {
                Button("Start Capture") {
                    Task {
                        try? await screenCaptureManager.startCapture(frameProcessor: viewModel.frameProcessor)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Stop Capture") {
                    Task {
                        try? await screenCaptureManager.stopCapture()
                    }
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
    }
}

// MARK: - Preview Helpers
class MockFrameProcessor: BasicFrameProcessorProtocol {
    func processFrame(_ frame: CMSampleBuffer) async throws -> Data? {
        return nil
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) async throws -> Data? {
        return nil
    }
}

class MockCaptureManager: FrameCaptureManagerProtocol {
    func startCapture(frameProcessor: AnyObject) async throws {}
    func stopCapture() async throws {}
}

struct MockCapturePreviewViewModel: CapturePreviewViewModel {
    let frameProcessor: BasicFrameProcessorProtocol = MockFrameProcessor()
    let captureManager: FrameCaptureManagerProtocol = MockCaptureManager()
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environment(\.capturePreviewViewModel, MockCapturePreviewViewModel())
            .environment(\.encodingControlViewModel, MockEncodingControlViewModel.shared)
    }
}
#endif

#else
#error("MainView is only available on macOS 14.0 or later")
#endif
