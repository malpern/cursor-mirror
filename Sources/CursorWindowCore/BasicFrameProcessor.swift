import Foundation
import AVFoundation

/// A basic implementation of frame processing for preview and analysis.
/// This class provides a foundation for implementing frame processing
/// without encoding, suitable for real-time preview and frame analysis.
public class BasicFrameProcessor: BasicFrameProcessorProtocol {
    /// Initialize a new basic frame processor
    public init() {}
    
    /// Process a single frame from the screen capture stream
    /// - Parameter frame: A CMSampleBuffer containing the captured frame data
    /// Currently, this is a placeholder implementation. Subclasses should
    /// override this method to implement specific frame processing logic.
    public func processFrame(_ frame: CMSampleBuffer) {
        // Basic frame processing implementation
        // For now, just a placeholder that does nothing
        // Subclasses should override this method to implement:
        // - Frame analysis
        // - Preview generation
        // - Image processing
        // - Performance metrics collection
    }
} 