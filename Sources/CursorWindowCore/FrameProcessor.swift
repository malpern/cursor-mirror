import Foundation
import AVFoundation
import CoreImage
import CoreVideo

#if os(macOS)
/// Protocol defining the interface for frame processors
@available(macOS 14.0, *)
public protocol FrameProcessor: Sendable {
    /// Process a frame from the screen capture stream
    /// - Parameters:
    ///   - frame: The frame to process
    ///   - timestamp: The timestamp of the frame
    /// - Returns: The processed frame data
    func processFrame(_ frame: CVPixelBuffer, timestamp: CMTime) async throws -> Data?
}
#endif 