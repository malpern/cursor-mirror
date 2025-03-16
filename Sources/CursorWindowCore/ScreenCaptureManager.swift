import Foundation
import ScreenCaptureKit
import SwiftUI

/// An actor that provides thread-safe access to frame processors.
/// This ensures that frame processor references are managed safely across concurrent operations.
actor FrameProcessor {
    /// The current frame processor instance
    private var processor: AnyObject?
    
    /// Set a new frame processor
    /// - Parameter processor: The frame processor to set, or nil to clear
    func set(_ processor: AnyObject?) {
        self.processor = processor
    }
    
    /// Get the current frame processor
    /// - Returns: The current frame processor, if one is set
    func get() -> AnyObject? {
        processor
    }
}

/// A class that manages screen capture operations with thread-safe frame processing.
/// This class is designed to run on the main actor and coordinates between the UI
/// and the capture system while ensuring thread safety through actor isolation.
@MainActor
public class ScreenCaptureManager: NSObject, ObservableObject, FrameCaptureManagerProtocol {
    /// Indicates whether screen recording permission has been granted
    @Published public var isScreenCapturePermissionGranted: Bool = false
    
    /// The active screen capture stream
    private var stream: SCStream?
    
    /// Configuration for the capture stream
    private var configuration: SCStreamConfiguration?
    
    /// A serial queue for processing captured frames
    /// This ensures frames are processed in order and prevents thread contention
    private let frameProcessingQueue = DispatchQueue(label: "com.cursor-window.frame-processing")
    
    /// An actor that provides thread-safe access to the current frame processor
    private let frameProcessor = FrameProcessor()
    
    /// Initialize the screen capture manager and check initial permission status
    public override init() {
        super.init()
        Task {
            await checkPermission()
        }
    }
    
    /// Check if screen recording permission has been granted
    /// This method updates the `isScreenCapturePermissionGranted` property
    public func checkPermission() async {
        do {
            let content = try await SCShareableContent.current
            isScreenCapturePermissionGranted = !content.displays.isEmpty
        } catch {
            isScreenCapturePermissionGranted = false
            print("Error checking screen capture permission: \(error)")
        }
    }
    
    /// Start capturing screen content with the specified frame processor
    /// - Parameter processor: An object conforming to either BasicFrameProcessorProtocol or EncodingFrameProcessorProtocol
    /// - Throws: An error if capture initialization fails or permission is denied
    public func startCapture(frameProcessor processor: AnyObject) async throws {
        await frameProcessor.set(processor)
        do {
            let content = try await SCShareableContent.current
            if let display = content.displays.first {
                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                config.queueDepth = 5
                
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameProcessingQueue)
                try await stream?.startCapture()
                
                await checkPermission()
            }
        } catch {
            print("Error starting capture: \(error)")
            throw error
        }
    }
    
    /// Stop the current capture session
    /// - Throws: An error if stopping the capture fails
    public func stopCapture() async throws {
        do {
            try await stream?.stopCapture()
            stream = nil
            await frameProcessor.set(nil)
        } catch {
            print("Error stopping capture: \(error)")
            throw error
        }
    }
}

// MARK: - SCStreamOutput Implementation

extension ScreenCaptureManager: SCStreamOutput {
    /// Handle incoming frames from the capture stream
    /// This method is called on the frameProcessingQueue and safely processes frames
    /// through the actor-isolated frame processor
    nonisolated public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        Task {
            // Get the current frame processor in an actor-safe way
            if let processor = await frameProcessor.get() {
                if let basicProcessor = processor as? BasicFrameProcessorProtocol {
                    basicProcessor.processFrame(sampleBuffer)
                } else if let encodingProcessor = processor as? EncodingFrameProcessorProtocol {
                    encodingProcessor.processFrame(sampleBuffer)
                }
            }
        }
    }
} 