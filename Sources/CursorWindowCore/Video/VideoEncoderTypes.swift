import Foundation
import AVFoundation

/// Error types for video encoding operations
public enum VideoEncoderError: Error {
    case compressionSessionCreationFailed
    case encodingFailed(Error)
}

/// Protocol for video encoders
@available(macOS 14.0, *)
public protocol VideoEncoder: AnyObject {
    var formatDescription: CMFormatDescription? { get }
    func encode(_ buffer: CVPixelBuffer) throws
    func finishEncoding() throws
}

/// Delegate protocol for handling encoded video samples
@available(macOS 14.0, *)
public protocol VideoEncoderDelegate: AnyObject {
    func videoEncoder(_ encoder: VideoEncoder, didOutputSampleBuffer sampleBuffer: CMSampleBuffer)
} 