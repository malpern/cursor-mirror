import Foundation
import AVFoundation
import CoreMedia
import os.log

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
        let segmentInfo = try await segmentManager.startNewSegment(quality: streamQuality, formatDescription: formatDescription)
        logger.info("Started new segment with index: \(segmentInfo)")
        
        // Start encoder with callback
        try await videoEncoder.startEncoding(settings: encoderSettings) { [weak self] encodedData, presentationTimeStamp, isKeyFrame in
            guard let self = self else { return }
            
            Task {
                try await self.handleEncodedData(
                    data: encodedData,
                    presentationTimeStamp: presentationTimeStamp,
                    isKeyFrame: isKeyFrame
                )
            }
        }
        
        isEncoding = true
        logger.info("Started encoding for HLS streaming at quality \(self.streamQuality.rawValue)")
    }
    
    /// Stop encoding and streaming
    public func stop() async throws {
        guard isEncoding else {
            return
        }
        
        // Stop encoder
        videoEncoder.stopEncoding()
        
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
    
    /// Handle encoded data from the video encoder
    /// - Parameters:
    ///   - data: Encoded video frame data
    ///   - presentationTimeStamp: PTS of the frame
    ///   - isKeyFrame: Whether this is a keyframe
    private func handleEncodedData(
        data: Data,
        presentationTimeStamp: CMTime,
        isKeyFrame: Bool
    ) async throws {
        guard isEncoding, let formatDescription = formatDescription else {
            return
        }
        
        // Create a CMBlockBuffer from the encoded data
        var blockBuffer: CMBlockBuffer?
        let dataLength = data.count
        let result = data.withUnsafeBytes { (bufferPtr: UnsafeRawBufferPointer) -> OSStatus in
            return CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: dataLength,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: dataLength,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
        }
        
        guard result == kCMBlockBufferNoErr, let buffer = blockBuffer else {
            throw NSError(domain: "HLSEncodingAdapter", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create block buffer"
            ])
        }
        
        // Copy data into block buffer
        let copyResult = data.withUnsafeBytes { (bufferPtr: UnsafeRawBufferPointer) -> OSStatus in
            return CMBlockBufferReplaceDataBytes(
                with: bufferPtr.baseAddress!,
                blockBuffer: buffer,
                offsetIntoDestination: 0,
                dataLength: dataLength
            )
        }
        
        guard copyResult == kCMBlockBufferNoErr else {
            throw NSError(domain: "HLSEncodingAdapter", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to copy data to block buffer"
            ])
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
            throw NSError(domain: "HLSEncodingAdapter", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create sample buffer"
            ])
        }
        
        // Attach key frame attachment if needed
        if isKeyFrame {
            let keyFrameDict = [kCMSampleAttachmentKey_NotSync: false] as CFDictionary
            CMSetAttachment(sampleBuffer, key: kCMSampleAttachmentKey_NotSync as CFString, value: keyFrameDict, attachmentMode: kCMAttachmentMode_ShouldPropagate)
        }
        
        // Append to segment manager
        let startedNewSegment = try await segmentManager.appendSampleBuffer(sampleBuffer, quality: streamQuality)
        
        // If we started a new segment and have a format description, initialize it
        if startedNewSegment {
            _ = try await segmentManager.startNewSegment(quality: streamQuality, formatDescription: formatDescription)
        }
    }
} 