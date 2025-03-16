import SwiftUI
import ScreenCaptureKit
import AVFoundation

struct MainView: View {
    // We'll initialize these in onAppear to avoid import issues
    @State private var frameProcessor: EncodingFrameProcessor?
    @State private var captureManager: FrameCaptureManager?
    @State private var basicFrameProcessor: BasicFrameProcessor?
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            // Tab selector
            Picker("Mode", selection: $selectedTab) {
                Text("Preview").tag(0)
                Text("Encoding").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Tab content
            TabView(selection: $selectedTab) {
                // Preview tab
                if let basicProcessor = basicFrameProcessor {
                    CapturePreview(frameProcessor: basicProcessor)
                        .tag(0)
                        .padding()
                } else {
                    ProgressView("Loading preview...")
                        .tag(0)
                        .padding()
                }
                
                // Encoding tab
                if let encodingProcessor = frameProcessor {
                    EncodingControlView(frameProcessor: encodingProcessor)
                        .tag(1)
                        .padding()
                } else {
                    ProgressView("Loading encoder...")
                        .tag(1)
                        .padding()
                }
            }
            .tabViewStyle(DefaultTabViewStyle())
        }
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            // Initialize components
            let basicProcessor = BasicFrameProcessor()
            let encoder = H264VideoEncoder()
            let encodingProcessor = EncodingFrameProcessor(encoder: encoder)
            let manager = FrameCaptureManager()
            
            self.basicFrameProcessor = basicProcessor
            self.frameProcessor = encodingProcessor
            self.captureManager = manager
            
            // Start the capture when the view appears
            Task {
                do {
                    try await manager.startCapture(
                        frameProcessor: selectedTab == 0 ? 
                            basicProcessor : 
                            encodingProcessor
                    )
                } catch {
                    print("Failed to start capture: \(error)")
                }
            }
        }
        .onChange(of: selectedTab) { newValue in
            // Switch the frame processor when the tab changes
            guard let manager = captureManager,
                  let basicProcessor = basicFrameProcessor,
                  let encodingProcessor = frameProcessor else {
                return
            }
            
            Task {
                do {
                    try await manager.stopCapture()
                    try await manager.startCapture(
                        frameProcessor: newValue == 0 ? 
                            basicProcessor : 
                            encodingProcessor
                    )
                } catch {
                    print("Failed to switch capture: \(error)")
                }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 