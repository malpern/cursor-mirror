import SwiftUI
import ScreenCaptureKit
import cursor_window

/// A view that displays captured frames
struct CapturePreview: View {
    /// The frame processor that provides images
    @ObservedObject var frameProcessor: BasicFrameProcessor
    
    /// The frame capture manager
    @ObservedObject var captureManager: FrameCaptureManager
    
    var body: some View {
        ZStack {
            // Display the latest image if available
            if let image = frameProcessor.latestImage {
                Image(nsImage: image)
                    .resizable()
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
                
                // Frame rate control
                HStack {
                    Text("Frame Rate: \(captureManager.frameRate) fps")
                    
                    Slider(value: Binding(
                        get: { Double(captureManager.frameRate) },
                        set: { captureManager.frameRate = Int($0) }
                    ), in: 1...60, step: 1)
                    .frame(width: 150)
                }
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
                .padding()
            }
        }
    }
}

#Preview {
    Text("CapturePreview Preview")
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.2))
} 