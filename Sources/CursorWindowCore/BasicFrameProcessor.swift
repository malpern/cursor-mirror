import Foundation
import AVFoundation

#if os(macOS)
/// A basic implementation of frame processing that can be used as a starting point
/// for more complex frame processing operations.
@available(macOS 14.0, *)
public final class BasicFrameProcessor {
    /// Initialize a new BasicFrameProcessor
    public init() {}
}

@available(macOS 14.0, *)
extension BasicFrameProcessor: BasicFrameProcessorProtocol {
    /// Process a single frame from the screen capture stream
    /// This base implementation does nothing and should be overridden by subclasses
    /// - Parameter frame: A CMSampleBuffer containing the captured frame data
    nonisolated public func processFrame(_ frame: CMSampleBuffer) {
        // Base implementation does nothing
        // Subclasses should override this to implement actual frame processing
    }
}
#endif 