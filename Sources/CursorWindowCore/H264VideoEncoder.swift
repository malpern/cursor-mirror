#if os(macOS)
import Foundation
import AVFoundation
import VideoToolbox

/// A video encoder that uses H.264 compression to encode captured frames
/// into a video file suitable for playback or streaming.
@available(macOS 14.0, *)
public final class H264VideoEncoder {
    /// The current encoding state
    private var isEncoding = false
    
    /// The video writer for the current encoding session
    private var videoWriter: AVAssetWriter?
    
    /// The video writer input for the current encoding session
    private var videoWriterInput: AVAssetWriterInput?
    
    /// Initialize a new H264 video encoder
    public init() {}
}

@available(macOS 14.0, *)
extension H264VideoEncoder: EncodingFrameProcessorProtocol {
    /// Process and encode a single frame
    /// - Parameter frame: A CMSampleBuffer containing the captured frame data
    nonisolated public func processFrame(_ frame: CMSampleBuffer) {
        guard isEncoding,
              let videoWriterInput = videoWriterInput,
              videoWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        videoWriterInput.append(frame)
    }
    
    /// Start encoding video to a specified URL
    /// - Parameters:
    ///   - url: The destination URL for the encoded video file
    ///   - width: The width of the video in pixels
    ///   - height: The height of the video in pixels
    /// - Throws: An error if encoding initialization fails
    nonisolated public func startEncoding(to url: URL, width: Int, height: Int) throws {
        // Create video writer
        videoWriter = try AVAssetWriter(url: url, fileType: .mp4)
        
        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_AutoLevel,
                kVTCompressionPropertyKey_AverageBitRate: 5_000_000,
                kVTCompressionPropertyKey_MaxKeyFrameInterval: 60
            ]
        ]
        
        // Create and add video input
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true
        
        if let videoWriterInput = videoWriterInput,
           let videoWriter = videoWriter {
            videoWriter.add(videoWriterInput)
            videoWriter.startWriting()
            videoWriter.startSession(atSourceTime: .zero)
            isEncoding = true
        }
    }
    
    /// Stop the current encoding session and finalize the video file
    nonisolated public func stopEncoding() {
        isEncoding = false
        videoWriterInput?.markAsFinished()
        videoWriter?.finishWriting { [weak self] in
            self?.videoWriter = nil
            self?.videoWriterInput = nil
        }
    }
}

#else
#error("H264VideoEncoder is only available on macOS 14.0 or later")
#endif 