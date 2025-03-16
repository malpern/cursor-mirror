import Foundation
import ScreenCaptureKit
import SwiftUI
import Combine

/// Protocol for processing captured frames
protocol FrameProcessor: NSObjectProtocol {
    /// Process a new frame
    /// - Parameter frame: The captured frame
    func processFrame(_ frame: CMSampleBuffer)
    
    /// Handle an error that occurred during capture
    /// - Parameter error: The error that occurred
    func handleError(_ error: Error)
}

/// A basic implementation of FrameProcessor that converts frames to images
class BasicFrameProcessor: NSObject, FrameProcessor, ObservableObject {
    /// The latest processed image
    @Published var latestImage: NSImage?
    
    /// Any error that occurred during processing
    @Published var error: Error?
    
    /// Process a new frame by converting it to an image
    /// - Parameter frame: The captured frame
    func processFrame(_ frame: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(frame) else {
            handleError(NSError(domain: "FrameProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get image buffer"]))
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            handleError(NSError(domain: "FrameProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"]))
            return
        }
        
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        DispatchQueue.main.async {
            self.latestImage = image
            self.error = nil
        }
    }
    
    /// Handle an error that occurred during capture
    /// - Parameter error: The error that occurred
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.error = error
        }
    }
}

/// Manager for capturing frames from the screen
class FrameCaptureManager: NSObject, ObservableObject {
    /// The content filter to use for capture
    @Published var contentFilter: SCContentFilter
    
    /// The frame processor to use for processing captured frames
    @Published var frameProcessor: FrameProcessor
    
    /// The frame rate to capture at
    @Published var frameRate: Int
    
    /// Whether capture is currently active
    @Published var isCapturing: Bool = false
    
    /// Any error that occurred during capture
    @Published var error: Error?
    
    /// The capture stream
    private var captureStream: SCStream?
    
    /// Initializes a new frame capture manager
    /// - Parameters:
    ///   - contentFilter: The content filter to use for capture
    ///   - frameProcessor: The frame processor to use for processing captured frames
    ///   - frameRate: The frame rate to capture at (default: 30)
    init(contentFilter: SCContentFilter, frameProcessor: FrameProcessor, frameRate: Int = 30) {
        self.contentFilter = contentFilter
        self.frameProcessor = frameProcessor
        self.frameRate = frameRate
        super.init()
    }
    
    /// Start capturing frames
    func startCapture() async throws {
        guard !isCapturing else { return }
        
        // Create stream configuration
        let configuration = SCStreamConfiguration()
        
        // Set the minimum frame interval based on the frame rate
        // For example, a frame rate of 30 fps corresponds to a minimum frame interval of 1/30 seconds
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        
        // Create stream
        let stream = SCStream(filter: contentFilter, configuration: configuration, delegate: nil)
        
        // Add stream output
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        
        // Start the stream
        try await stream.startCapture()
        
        self.captureStream = stream
        
        DispatchQueue.main.async {
            self.isCapturing = true
            self.error = nil
        }
    }
    
    /// Stop capturing frames
    func stopCapture() {
        guard isCapturing, let stream = captureStream else { return }
        
        Task {
            do {
                try await stream.stopCapture()
                self.captureStream = nil
                
                DispatchQueue.main.async {
                    self.isCapturing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }
    
    /// Update the content filter
    /// - Parameter filter: The new content filter
    func updateContentFilter(_ filter: SCContentFilter) {
        self.contentFilter = filter
        
        // If we're capturing, restart with the new filter
        if isCapturing {
            stopCapture()
            Task {
                do {
                    try await startCapture()
                } catch {
                    DispatchQueue.main.async {
                        self.error = error
                    }
                }
            }
        }
    }
    
    /// Set a new frame processor
    /// - Parameter processor: The new frame processor
    func setFrameProcessor(_ processor: FrameProcessor) {
        self.frameProcessor = processor
    }
}

// MARK: - SCStreamOutput
extension FrameCaptureManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isCapturing, type == .screen else { return }
        
        // Process the frame
        frameProcessor.processFrame(sampleBuffer)
    }
} 