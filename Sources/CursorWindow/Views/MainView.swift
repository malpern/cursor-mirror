#if os(macOS)
import SwiftUI
#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif
import AVFoundation
import CursorWindowCore
import Foundation

// MARK: - Environment Keys for View Models
struct CapturePreviewViewModelKey: EnvironmentKey {
    static let defaultValue: CapturePreviewViewModel? = nil
}

struct EncodingControlViewModelKey: EnvironmentKey {
    static let defaultValue: EncodingControlViewModel? = nil
}

extension EnvironmentValues {
    var capturePreviewViewModel: CapturePreviewViewModel? {
        get { self[CapturePreviewViewModelKey.self] }
        set { self[CapturePreviewViewModelKey.self] = newValue }
    }
    
    var encodingControlViewModel: EncodingControlViewModel? {
        get { self[EncodingControlViewModelKey.self] }
        set { self[EncodingControlViewModelKey.self] = newValue }
    }
}

// MARK: - View Model Protocols
protocol CapturePreviewViewModel {
    var frameProcessor: BasicFrameProcessorProtocol { get }
    var captureManager: FrameCaptureManagerProtocol { get }
}

protocol EncodingControlViewModel {
    var frameProcessor: EncodingFrameProcessorProtocol { get }
}

protocol BasicFrameProcessorProtocol {
    func processFrame(_ frame: CMSampleBuffer)
}

protocol EncodingFrameProcessorProtocol: BasicFrameProcessorProtocol {
    func startEncoding(to url: URL, width: Int, height: Int) throws
    func stopEncoding()
}

protocol FrameCaptureManagerProtocol {
    func startCapture(frameProcessor: AnyObject) async throws
    func stopCapture() async throws
}

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
            
            // Server controls tab
            ServerControlView()
                .tabItem {
                    Label("Server", systemImage: "server.rack")
                }
                .tag(2)
        }
        .frame(minWidth: 600, minHeight: 700)
    }
}

struct CapturePreviewView: View {
    let viewModel: CapturePreviewViewModel
    
    var body: some View {
        // Implement your capture preview view here
        Text("Capture Preview")
    }
}

struct EncodingControlView: View {
    let viewModel: EncodingControlViewModel
    
    var body: some View {
        // Implement your encoding control view here
        Text("Encoding Control")
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

class MockServerControlViewModel: ServerControlViewModel {
    override init() {
        super.init()
        self.serverStatus = "Server ready (mock)"
    }
}

#Preview {
    MainView()
        .environment(\.capturePreviewViewModel, MockCapturePreviewViewModel())
        .environment(\.encodingControlViewModel, MockEncodingControlViewModel())
        .environmentObject(MockServerControlViewModel())
}

#else
#error("MainView is only available on macOS 14.0 or later")
#endif 