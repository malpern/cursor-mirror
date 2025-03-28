import Foundation
import AVFoundation
import CoreMedia
import os.log

/// Errors that can occur during HLS encoding
public enum HLSEncodingError: Error, CustomStringConvertible {
    /// Format description not available
    case formatDescriptionMissing
    
    /// Encoding not active
    case encodingNotActive
    
    /// Failed to create sample buffer
    case sampleBufferCreationFailed(status: OSStatus)
    
    /// Failed to append sample buffer
    case appendSampleBufferFailed(reason: String)
    
    /// Failed to start segment
    case segmentStartFailed(reason: String)
    
    /// Invalid stream quality
    case invalidStreamQuality
    
    /// Encoding session already active
    case encodingAlreadyActive
    
    /// Encoding session already encoding
    case alreadyEncoding
    
    /// Human-readable description of the error
    public var description: String {
        switch self {
        case .formatDescriptionMissing:
            return "Video format description is missing"
        case .encodingNotActive:
            return "HLS encoding is not active"
        case .sampleBufferCreationFailed(let status):
            return "Failed to create sample buffer (status: \(status))"
        case .appendSampleBufferFailed(let reason):
            return "Failed to append sample buffer: \(reason)"
        case .segmentStartFailed(let reason):
            return "Failed to start new segment: \(reason)"
        case .invalidStreamQuality:
            return "Invalid stream quality configuration"
        case .encodingAlreadyActive:
            return "HLS encoding session is already active"
        case .alreadyEncoding:
            return "HLS encoding session is already encoding"
        }
    }
}

/// Adapter to connect H264 video encoder with HLS segmenting system
public actor HLSEncodingAdapter {
    /// Video encoder that provides H264 encoded frames
    private let videoEncoder: H264VideoEncoder
    
    /// HLS segment manager for handling segments
    private let segmentManager: HLSSegmentManager
    
    /// HLS stream manager for state tracking
    private let streamManager: HLSStreamManager
    
    /// Current stream quality
    private var streamQuality: StreamQuality
    
    /// Whether encoding is currently active
    private var isEncoding = false
    
    /// Logger
    private let logger = Logger(subsystem: "com.cursor-window", category: "HLSEncodingAdapter")
    
    /// Format description for the current encode session
    private var formatDescription: CMFormatDescription?
    
    /// Initialize with dependencies
    /// - Parameters:
    ///   - videoEncoder: H264 video encoder
    ///   - segmentManager: HLS segment manager
    ///   - streamManager: HLS stream manager
    ///   - quality: Default stream quality
    public init(
        videoEncoder: H264VideoEncoder,
        segmentManager: HLSSegmentManager,
        streamManager: HLSStreamManager,
        quality: StreamQuality = .hd
    ) {
        self.videoEncoder = videoEncoder
        self.segmentManager = segmentManager
        self.streamManager = streamManager
        self.streamQuality = quality
    }
    
    /// Start encoding and streaming
    /// - Parameter settings: Optional encoder settings
    public func start(settings: H264EncoderSettings? = nil) async throws {
        // Check if already encoding
        if isEncoding {
            logger.warning("Encoding is already active, stopping before restart")
            try await stop()
        }
        
        // Start streaming session
        let streamToken = try await streamManager.startStreaming()
        logger.info("Received stream token: \(streamToken)")
        
        // Use provided settings or default for the quality
        let encoderSettings = settings ?? streamQuality.encoderSettings
        
        // Create format description for h264
        let formatDescriptionPtr = UnsafeMutablePointer<CMFormatDescription?>.allocate(capacity: 1)
        defer { formatDescriptionPtr.deallocate() }
        
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_H264,
            width: Int32(encoderSettings.resolution.width),
            height: Int32(encoderSettings.resolution.height),
            extensions: nil,
            formatDescriptionOut: formatDescriptionPtr
        )
        
        guard status == noErr, let formatDescription = formatDescriptionPtr.pointee else {
            throw NSError(domain: "HLSEncodingAdapter", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create format description"
            ])
        }
        
        self.formatDescription = formatDescription
        
        // Start a new segment
        _ = try await segmentManager.startNewSegment(quality: streamQuality, formatDescription: formatDescription)
        logger.info("Started new segment")
        
        // Create a temporary URL for the encoder
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_hls_stream.mp4")
        
        // Start encoder with callback using the new method signature
        try await videoEncoder.startEncoding(
            to: tempURL,
            width: Int(encoderSettings.resolution.width),
            height: Int(encoderSettings.resolution.height),
            completionHandler: { [weak self] sampleBuffer, error, isComplete in
                guard let self = self, error == nil else {
                    self?.logger.error("Error in encoding callback: \(error?.localizedDescription ?? "unknown error")")
                    return
                }
                
                // Extract CMBlockBuffer and create Data from it
                guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                    return
                }
                
                var dataLength = 0
                var dataPointer: UnsafeMutablePointer<Int8>?
                let status = CMBlockBufferGetDataPointer(
                    dataBuffer,
                    atOffset: 0,
                    lengthAtOffsetOut: nil,
                    totalLengthOut: &dataLength,
                    dataPointerOut: &dataPointer
                )
                
                guard status == kCMBlockBufferNoErr, let ptr = dataPointer else {
                    return
                }
                
                let data = Data(bytes: ptr, count: dataLength)
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                // Determine if frame is a keyframe
                var isKeyFrame = false
                if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]] {
                    if let notSync = attachments.first?[kCMSampleAttachmentKey_NotSync] as? Bool {
                        isKeyFrame = !notSync
                    }
                }
                
                // Process the encoded data
                Task {
                    do {
                        try await self.processEncodedData(
                            data: data,
                            presentationTimeStamp: presentationTime,
                            isKeyFrame: isKeyFrame
                        )
                    } catch {
                        self.logger.error("Failed to process encoded data: \(error)")
                    }
                }
            }
        )
        
        isEncoding = true
        logger.info("Started encoding for HLS streaming at quality \(self.streamQuality.rawValue)")
    }
    
    /// Stop encoding and streaming
    public func stop() async throws {
        guard isEncoding else {
            return
        }
        
        // Stop encoder
        await videoEncoder.stopEncoding()
        
        // End current segment
        let segmentInfo = try await segmentManager.endSegment(quality: streamQuality)
        if let info = segmentInfo {
            logger.info("Ended segment with duration: \(info.duration)s")
        }
        
        // Stop streaming
        await streamManager.stopStreaming()
        
        isEncoding = false
        formatDescription = nil
        
        logger.info("Stopped encoding for HLS streaming")
    }
    
    /// Process encoded data from the video encoder
    /// - Parameters:
    ///   - data: H264 encoded frame data
    ///   - presentationTimeStamp: Presentation timestamp for the frame
    ///   - isKeyFrame: Whether this is a key frame
    private func processEncodedData(
        data: Data,
        presentationTimeStamp: CMTime,
        isKeyFrame: Bool
    ) async throws {
        guard isEncoding else {
            throw HLSEncodingError.encodingNotActive
        }
        
        guard let formatDescription = self.formatDescription else {
            throw HLSEncodingError.formatDescriptionMissing
        }
        
        // Create a data buffer
        var blockBuffer: CMBlockBuffer?
        let result = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard result == kCMBlockBufferNoErr, let buffer = blockBuffer else {
            throw HLSEncodingError.sampleBufferCreationFailed(status: result)
        }
        
        // Copy data into block buffer
        let copyResult = data.withUnsafeBytes { (bufferPtr: UnsafeRawBufferPointer) -> OSStatus in
            return CMBlockBufferReplaceDataBytes(
                with: bufferPtr.baseAddress!,
                blockBuffer: buffer,
                offsetIntoDestination: 0,
                dataLength: data.count
            )
        }
        
        guard copyResult == kCMBlockBufferNoErr else {
            throw HLSEncodingError.sampleBufferCreationFailed(status: copyResult)
        }
        
        // Create a sample buffer
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: CMTime.invalid
        )
        
        let createResult = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard createResult == noErr, let sampleBuffer = sampleBuffer else {
            throw HLSEncodingError.sampleBufferCreationFailed(status: createResult)
        }
        
        // Attach key frame attachment if needed
        if isKeyFrame {
            let keyFrameDict = [kCMSampleAttachmentKey_NotSync: false] as [CFString: Any]
            CMSetAttachment(sampleBuffer, key: kCMSampleAttachmentKey_NotSync, value: keyFrameDict as CFTypeRef, attachmentMode: kCMAttachmentMode_ShouldPropagate)
        }
        
        // Append to segment manager
        let sendableBuffer = SendableSampleBuffer(sampleBuffer)
        do {
            let startedNewSegment = try await segmentManager.appendSampleBuffer(sendableBuffer, quality: streamQuality)
            
            // If we started a new segment and have a format description, initialize it
            if startedNewSegment {
                do {
                    _ = try await segmentManager.startNewSegment(quality: streamQuality, formatDescription: formatDescription)
                } catch {
                    throw HLSEncodingError.segmentStartFailed(reason: error.localizedDescription)
                }
            }
        } catch {
            throw HLSEncodingError.appendSampleBufferFailed(reason: error.localizedDescription)
        }
    }
}

