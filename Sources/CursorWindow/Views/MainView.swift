#if os(macOS)
import SwiftUI
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif
import AVFoundation
import CursorWindowCore

struct MainView: View {
    @Environment(\.capturePreviewViewModel) private var capturePreviewViewModel: CapturePreviewViewModel?
    @Environment(\.encodingControlViewModel) private var encodingControlViewModel: EncodingControlViewModel?
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            if let previewVM = capturePreviewViewModel {
                CapturePreviewView(viewModel: previewVM)
                    .tabItem {
                        Label("Preview", systemImage: "video")
                    }
                    .tag(0)
            }
            
            if let encodingVM = encodingControlViewModel {
                EncodingControlView(viewModel: encodingVM)
                    .tabItem {
                        Label("Encoding", systemImage: "gear")
                    }
                    .tag(1)
            }
        }
        .frame(minWidth: 600, minHeight: 700)
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

struct EncodingControlView: View {
    let viewModel: EncodingControlViewModel
    @State private var outputPath: String = NSHomeDirectory() + "/Desktop/output.mp4"
    @State private var isEncoding: Bool = false
    @State private var width: Int = 393
    @State private var height: Int = 852
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Encoding Settings")
                .font(.headline)
                .padding(.bottom)
            
            HStack {
                Text("Output File:")
                TextField("Output Path", text: $outputPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Browse") {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.mpeg4Movie]
                    panel.canCreateDirectories = true
                    
                    if panel.runModal() == .OK, let url = panel.url {
                        outputPath = url.path
                    }
                }
            }
            
            HStack {
                Text("Resolution:")
                TextField("Width", value: $width, formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("x")
                TextField("Height", value: $height, formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Button(isEncoding ? "Stop Encoding" : "Start Encoding") {
                    if isEncoding {
                        viewModel.frameProcessor.stopEncoding()
                        isEncoding = false
                    } else {
                        do {
                            try viewModel.frameProcessor.startEncoding(
                                to: URL(fileURLWithPath: outputPath),
                                width: width,
                                height: height
                            )
                            isEncoding = true
                        } catch {
                            print("Error starting encoding: \(error)")
                        }
                    }
                }
                .padding()
                .background(isEncoding ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview Helpers
class MockFrameProcessor: BasicFrameProcessorProtocol {
    func processFrame(_ frame: CMSampleBuffer) {}
}

class MockEncodingProcessor: EncodingFrameProcessorProtocol {
    func processFrame(_ frame: CMSampleBuffer) {}
    func startEncoding(to url: URL, width: Int, height: Int) throws {}
    func stopEncoding() {}
}

class MockCaptureManager: FrameCaptureManagerProtocol {
    func startCapture(frameProcessor: AnyObject) async throws {}
    func stopCapture() async throws {}
}

struct MockCapturePreviewViewModel: CapturePreviewViewModel {
    let frameProcessor: BasicFrameProcessorProtocol = MockFrameProcessor()
    let captureManager: FrameCaptureManagerProtocol = MockCaptureManager()
}

struct MockEncodingControlViewModel: EncodingControlViewModel {
    let frameProcessor: EncodingFrameProcessorProtocol = MockEncodingProcessor()
}

#Preview {
    MainView()
        .environment(\.capturePreviewViewModel, MockCapturePreviewViewModel())
        .environment(\.encodingControlViewModel, MockEncodingControlViewModel())
}

#else
#error("MainView is only available on macOS 14.0 or later")
#endif 