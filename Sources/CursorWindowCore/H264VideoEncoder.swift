import Foundation
import AVFoundation
import VideoToolbox

public class H264VideoEncoder: EncodingFrameProcessorProtocol {
    private var isEncoding = false
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    
    public init() {}
    
    public func processFrame(_ frame: CMSampleBuffer) {
        guard isEncoding,
              let videoWriterInput = videoWriterInput,
              videoWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        videoWriterInput.append(frame)
    }
    
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