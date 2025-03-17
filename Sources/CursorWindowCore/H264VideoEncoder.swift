#if os(macOS)
import Foundation
@preconcurrency import AVFoundation
@preconcurrency import CoreVideo
import VideoToolbox

/// A video encoder that uses H.264 compression to encode captured frames
/// into a video file suitable for playback or streaming.
@available(macOS 14.0, *)
public actor H264VideoEncoder: VideoEncoder {
    /// The current encoding state
    private var isEncoding = false
    
    /// The video writer for the current encoding session
    private var videoWriter: AVAssetWriter?
    
    /// The video writer input for the current encoding session
    private var videoWriterInput: AVAssetWriterInput?
    
    /// A serial queue for frame processing
    private let processingQueue = DispatchQueue(label: "com.cursorwindow.encoder.processing")
    
    /// Initialize a new H264 video encoder
    public init() {}
}

/// A struct to hold frame data in a Sendable way
@available(macOS 14.0, *)
private struct FrameData: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let duration: CMTime
    let presentationTime: CMTime
}

@available(macOS 14.0, *)
extension H264VideoEncoder: EncodingFrameProcessorProtocol {
    /// Process and encode a single frame
    /// - Parameter frame: A CMSampleBuffer containing the captured frame data
    nonisolated public func processFrame(_ frame: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame) else { return }
        
        // Lock the buffer and extract its properties
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Create a copy of the pixel buffer for thread safety
        guard let pixelBufferCopy = createPixelBufferCopy(from: pixelBuffer) else { return }
        
        // Get timing information
        let frameData = FrameData(
            pixelBuffer: pixelBufferCopy,
            duration: CMSampleBufferGetDuration(frame),
            presentationTime: CMSampleBufferGetPresentationTimeStamp(frame)
        )
        
        // Process the frame on a serial queue to maintain order
        Task { @MainActor [weak self] in
            await self?.processFrameInternal(frameData)
        }
    }
    
    /// Create a copy of a pixel buffer
    /// - Parameter source: The source pixel buffer to copy
    /// - Returns: A new pixel buffer containing the same data
    private nonisolated func createPixelBufferCopy(from source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(source)
        let format = CVPixelBufferGetPixelFormatType(source)
        
        var pixelBufferCopy: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            nil,
            &pixelBufferCopy
        )
        
        guard let pixelBufferCopy = pixelBufferCopy else { return nil }
        
        // Lock the destination buffer
        CVPixelBufferLockBaseAddress(pixelBufferCopy, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBufferCopy, []) }
        
        // Copy pixel data
        if let srcAddress = CVPixelBufferGetBaseAddress(source),
           let dstAddress = CVPixelBufferGetBaseAddress(pixelBufferCopy) {
            memcpy(dstAddress, srcAddress, bytesPerRow * height)
        }
        
        return pixelBufferCopy
    }
    
    /// Internal method to process frames within the actor's isolation domain
    /// - Parameter frameData: The frame data to process
    private func processFrameInternal(_ frameData: FrameData) {
        guard isEncoding,
              let videoWriterInput = videoWriterInput,
              let videoWriter = videoWriter else {
            print("Cannot process frame: encoding=\(isEncoding), input=\(videoWriterInput != nil), writer=\(videoWriter != nil)")
            return
        }
        
        guard videoWriterInput.isReadyForMoreMediaData else {
            print("Writer input not ready for more data")
            return
        }
        
        // Create format description
        var videoInfo: CMFormatDescription?
        let err = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frameData.pixelBuffer,
            formatDescriptionOut: &videoInfo
        )
        
        guard err == noErr, let videoInfo = videoInfo else {
            print("Failed to create format description: \(err)")
            return
        }
        
        // Create timing info
        var timingInfo = CMSampleTimingInfo(
            duration: frameData.duration,
            presentationTimeStamp: frameData.presentationTime,
            decodeTimeStamp: frameData.presentationTime
        )
        
        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        let createErr = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frameData.pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoInfo,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        guard createErr == noErr,
              let sampleBuffer = sampleBuffer,
              CMSampleBufferDataIsReady(sampleBuffer) else {
            print("Failed to create sample buffer: \(createErr)")
            return
        }
        
        // Mark the sample buffer for immediate display
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [[CFString: Any]],
           let dict = attachments.first as? NSMutableDictionary {
            dict[kCMSampleAttachmentKey_DisplayImmediately] = true
        }
        
        if !videoWriterInput.append(sampleBuffer) {
            print("Failed to append sample buffer with error: \(String(describing: videoWriter.error))")
            return
        }
    }
    
    /// Start encoding video to a specified URL
    /// - Parameters:
    ///   - url: The destination URL for the encoded video file
    ///   - width: The width of the video in pixels
    ///   - height: The height of the video in pixels
    /// - Throws: An error if encoding initialization fails
    nonisolated public func startEncoding(to url: URL, width: Int, height: Int) throws {
        // Start the encoding session synchronously
        let semaphore = DispatchSemaphore(value: 0)
        var setupError: Error?
        
        Task { @MainActor [weak self] in
            do {
                try await self?.startEncodingInternal(to: url, width: width, height: height)
            } catch {
                setupError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        if let error = setupError {
            throw error
        }
    }
    
    /// Internal method to start encoding within the actor's isolation domain
    private func startEncodingInternal(to url: URL, width: Int, height: Int) throws {
        // Remove any existing file
        try? FileManager.default.removeItem(at: url)
        
        // Create video writer
        videoWriter = try AVAssetWriter(url: url, fileType: .mp4)
        
        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Baseline_AutoLevel,
                kVTCompressionPropertyKey_RealTime: true,
                kVTCompressionPropertyKey_MaxKeyFrameInterval: 30,
                kVTCompressionPropertyKey_ExpectedFrameRate: 30,
                kVTCompressionPropertyKey_AverageBitRate: 2_000_000
            ]
        ]
        
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
        Task { @MainActor [weak self] in
            await self?.stopEncodingInternal()
        }
    }
    
    /// Internal method to stop encoding within the actor's isolation domain
    private func stopEncodingInternal() {
        guard isEncoding else { return }
        
        isEncoding = false
        videoWriterInput?.markAsFinished()
        
        if let writer = videoWriter {
            writer.finishWriting { [weak self] in
                if let error = writer.error {
                    print("Writer finished with error: \(error)")
                }
                Task { @MainActor [weak self] in
                    await self?.cleanupEncoding()
                }
            }
        }
    }
    
    /// Clean up the encoding session by resetting state
    private func cleanupEncoding() {
        videoWriter = nil
        videoWriterInput = nil
    }
}

#else
#error("H264VideoEncoder is only available on macOS 14.0 or later")
#endif
