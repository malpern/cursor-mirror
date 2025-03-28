import Foundation
import AVFoundation

/// Errors that can occur during video encoding
public enum VideoEncoderError: Error {
    case compressionSessionCreationFailed
    case compressionSessionConfigurationFailed
    case compressionSessionPreparationFailed
    case formatDescriptionCreationFailed
    case frameEncodingFailed
}

/// Protocol for receiving encoded video frames
@preconcurrency
public protocol VideoEncoderDelegate: AnyObject {
    /// Called when a new encoded video frame is available
    /// - Parameters:
    ///   - encoder: The video encoder that produced the frame
    ///   - sampleBuffer: The encoded video frame as a CMSampleBuffer
    func videoEncoder(_ encoder: any VideoEncoder, didOutputSampleBuffer: CMSampleBuffer) async
}

/// Protocol for video encoders
@preconcurrency
public protocol VideoEncoder: AnyObject {
    /// The delegate to receive encoded video frames
    nonisolated var delegate: VideoEncoderDelegate? { get async }
    
    /// Set the delegate for receiving encoded video frames
    /// - Parameter delegate: The delegate to set
    nonisolated func setDelegate(_ delegate: VideoEncoderDelegate?) async
    
    /// The format description for the encoded video
    nonisolated var formatDescription: CMFormatDescription? { get async }
    
    /// Encode a video frame
    /// - Parameter buffer: The video frame to encode
    /// - Throws: VideoEncoderError if encoding fails
    func encode(_ buffer: CVPixelBuffer) async throws
    
    /// Finish encoding and clean up resources
    /// - Throws: VideoEncoderError if cleanup fails
    func finishEncoding() async throws
    
    func startEncoding(settings: [String: Any], completionHandler: @escaping (Data, CMTime, Bool) -> Void) async throws
    func startEncoding(to outputURL: URL, width: Int, height: Int) async throws
    func stopEncoding() async
} 