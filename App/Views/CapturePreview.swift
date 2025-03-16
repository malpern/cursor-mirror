import SwiftUI
import ScreenCaptureKit
import Combine

/// A view that displays captured frames
struct CapturePreview: View {
    /// The frame processor that provides images
    @ObservedObject var frameProcessor: BasicFrameProcessor
    
    /// The frame capture manager
    @ObservedObject var captureManager: FrameCaptureManager
    
    /// State for debounced frame rate
    @State private var localFrameRate: Double
    @State private var frameRateDebouncer = PassthroughSubject<Int, Never>()
    @State private var cancellables = Set<AnyCancellable>()
    
    init(frameProcessor: BasicFrameProcessor, captureManager: FrameCaptureManager) {
        self.frameProcessor = frameProcessor
        self.captureManager = captureManager
        self._localFrameRate = State(initialValue: Double(captureManager.frameRate))
    }
    
    var body: some View {
        ZStack {
            // Display the latest image if available
            Group {
                if let image = frameProcessor.latestImage {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.medium) // Better performance than high
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                } else {
                    // Show a placeholder when no image is available
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .overlay {
                            Text("No capture available")
                                .foregroundColor(.secondary)
                        }
                }
            }
            .drawingGroup() // Use Metal rendering for better performance
            
            // Show an error message if there's an error
            if let error = captureManager.error ?? frameProcessor.error {
                VStack {
                    Spacer()
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding()
                }
            }
            
            // Show a loading indicator when starting capture
            if captureManager.isCapturing && frameProcessor.latestImage == nil {
                ProgressView("Starting capture...")
                    .padding()
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .overlay {
            VStack {
                HStack {
                    Spacer()
                    
                    // Capture control button
                    Button {
                        if captureManager.isCapturing {
                            captureManager.stopCapture()
                        } else {
                            Task {
                                do {
                                    try await captureManager.startCapture()
                                } catch {
                                    print("Failed to start capture: \(error)")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: captureManager.isCapturing ? "stop.circle.fill" : "record.circle")
                            .font(.title)
                            .foregroundColor(captureManager.isCapturing ? .red : .green)
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                
                Spacer()
                
                // Frame rate control with debouncing
                HStack {
                    Text("Frame Rate: \(Int(localFrameRate)) fps")
                    
                    Slider(value: $localFrameRate, in: 1...60, step: 1)
                        .frame(width: 150)
                        .onChange(of: localFrameRate) { newValue in
                            // Send the new value to the debouncer
                            frameRateDebouncer.send(Int(newValue))
                        }
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
                .padding()
            }
        }
        .onAppear {
            // Set up debouncing for frame rate changes
            frameRateDebouncer
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .sink { [weak captureManager] newFrameRate in
                    captureManager?.frameRate = newFrameRate
                }
                .store(in: &cancellables)
        }
    }
}

#Preview {
    let frameProcessor = BasicFrameProcessor()
    let displayConfig = DisplayConfiguration()
    let filter = SCContentFilter()
    let captureManager = FrameCaptureManager(contentFilter: filter, frameProcessor: frameProcessor)
    
    return CapturePreview(frameProcessor: frameProcessor, captureManager: captureManager)
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.2))
} 