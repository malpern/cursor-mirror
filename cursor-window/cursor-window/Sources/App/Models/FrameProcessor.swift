import Foundation
import ScreenCaptureKit
import SwiftUI
import Combine
import AppKit

/// Errors that can occur during screen capture
enum CaptureError: Error, LocalizedError {
    case permissionDenied
    case captureStartFailed(Error)
    case captureStopFailed(Error)
    case streamConfigurationFailed(Error)
    case frameProcessingFailed(Error)
    case noDisplaysAvailable
    case invalidContentFilter
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied"
        case .captureStartFailed(let error):
            return "Failed to start capture: \(error.localizedDescription)"
        case .captureStopFailed(let error):
            return "Failed to stop capture: \(error.localizedDescription)"
        case .streamConfigurationFailed(let error):
            return "Failed to configure stream: \(error.localizedDescription)"
        case .frameProcessingFailed(let error):
            return "Failed to process frame: \(error.localizedDescription)"
        case .noDisplaysAvailable:
            return "No displays available for capture"
        case .invalidContentFilter:
            return "Invalid content filter configuration"
        }
    }
}

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
    /// The latest image captured
    @Published var latestImage: NSImage?
    
    /// Any error that occurred during processing
    @Published var error: Error?
    
    /// Process a captured frame
    /// - Parameter sampleBuffer: The sample buffer containing the frame
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            handleError(CaptureError.frameProcessingFailed(NSError(domain: "com.cursor-window", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to get image buffer from sample buffer"])))
            return
        }
        
        // Create a CIImage from the CVPixelBuffer
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // Create a CGImage from the CIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            handleError(CaptureError.frameProcessingFailed(NSError(domain: "com.cursor-window", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage from CIImage"])))
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
    
    /// Clear any current error
    func clearError() {
        DispatchQueue.main.async {
            self.error = nil
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
        
        // Check screen recording permission
        do {
            let content = try await SCShareableContent.current
            // If we get here, permission is granted
            // Continue with capture setup
        } catch {
            let permissionError = CaptureError.permissionDenied
            DispatchQueue.main.async {
                self.error = permissionError
            }
            throw permissionError
        }
        
        // Create stream configuration
        let configuration = SCStreamConfiguration()
        
        // Set the minimum frame interval based on the frame rate
        // For example, a frame rate of 30 fps corresponds to a minimum frame interval of 1/30 seconds
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        
        do {
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
        } catch {
            let captureError = CaptureError.captureStartFailed(error)
            DispatchQueue.main.async {
                self.error = captureError
            }
            throw captureError
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
                let captureError = CaptureError.captureStopFailed(error)
                DispatchQueue.main.async {
                    self.error = captureError
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
    
    /// Clear any current error
    func clearError() {
        DispatchQueue.main.async {
            self.error = nil
        }
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