import Foundation
import AVFoundation
import VideoToolbox

/// A class that handles real-time H.264 video encoding of captured frames.
/// This encoder is optimized for screen recording and supports high-quality
/// video encoding with configurable parameters.
public class H264VideoEncoder: EncodingFrameProcessorProtocol {
    /// Indicates whether encoding is currently active
    private var isEncoding = false
    
    /// The asset writer responsible for writing encoded video to disk
    private var videoWriter: AVAssetWriter?
    
    /// The input for writing video samples to the asset writer
    private var videoWriterInput: AVAssetWriterInput?
    
    /// Initialize a new H.264 video encoder
    public init() {}
    
    /// Process and encode a single frame
    /// - Parameter frame: The CMSampleBuffer containing the frame to encode
    /// This method will only process frames if encoding is active and the writer
    /// is ready for more data. Frames are dropped if the encoder cannot keep up.
    public func processFrame(_ frame: CMSampleBuffer) {
        guard isEncoding,
              let videoWriterInput = videoWriterInput,
              videoWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        videoWriterInput.append(frame)
    }
    
    /// Start encoding video to the specified URL with given dimensions
    /// - Parameters:
    ///   - url: The destination URL for the encoded video file
    ///   - width: The width of the video in pixels
    ///   - height: The height of the video in pixels
    /// - Throws: CursorWindowError if encoding initialization fails
    /// This method configures the video encoder with high-quality H.264 settings
    /// suitable for screen recording, including:
    /// - High profile level for better quality
    /// - 2 Mbps target bitrate
    /// - 30 frame keyframe interval
    public func startEncoding(to url: URL, width: Int, height: Int) throws {
        guard !isEncoding else { return }
        
        // Create asset writer
        videoWriter = try AVAssetWriter(url: url, fileType: .mp4)
        
        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2000000,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        // Create and add video input
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true
        
        if let videoWriterInput = videoWriterInput {
            videoWriter?.add(videoWriterInput)
        }
        
        // Start writing session
        videoWriter?.startWriting()
        videoWriter?.startSession(atSourceTime: .zero)
        
        isEncoding = true
    }
    
    /// Stop the current encoding session and finalize the video file
    /// This method ensures proper cleanup of encoding resources and
    /// finalizes the video file for playback.
    public func stopEncoding() {
        guard isEncoding else { return }
        
        isEncoding = false
        videoWriterInput?.markAsFinished()
        
        videoWriter?.finishWriting { [weak self] in
            self?.videoWriter = nil
            self?.videoWriterInput = nil
        }
    }
} 