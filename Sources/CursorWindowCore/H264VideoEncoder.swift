#if os(macOS)
import Foundation
@preconcurrency import AVFoundation
@preconcurrency import CoreVideo
import VideoToolbox
import os.log

/// A video encoder that uses H.264 compression to encode captured frames
/// into a video file suitable for playback or streaming.
@available(macOS 14.0, *)
public actor H264VideoEncoder: VideoEncoder, ObservableObject {
    /// The current encoding state
    private var encodingState = false
    
    /// Published encoding state for UI updates
    @MainActor @Published public private(set) var isEncoding = false
    
    /// The video writer for the current encoding session
    private var videoWriter: AVAssetWriter?
    
    /// The video writer input for the current encoding session
    private var videoWriterInput: AVAssetWriterInput?
    
    /// A serial queue for frame processing
    private let processingQueue = DispatchQueue(label: "com.cursorwindow.encoder.processing")
    
    /// Logger instance
    private let logger = Logger(subsystem: "com.cursor-window", category: "H264VideoEncoder")
    
    /// Encoded data callback
    nonisolated(unsafe) private var encodedDataCallback: ((_ data: Data, _ pts: CMTime, _ isKeyFrame: Bool) -> Void)?
    
    /// Error domain for H264VideoEncoder
    private static let errorDomain = "com.cursor-window.H264VideoEncoder"
    
    /// Initialize a new H264 video encoder
    public init() {}
    
    /// Update the published state on the main actor
    private func updatePublishedState(_ state: Bool) {
        Task { @MainActor in
            isEncoding = state
        }
    }
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
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame) else {
            print("[H264VideoEncoder] Failed to get pixel buffer from sample buffer")
            return
        }
        
        // Lock the buffer and extract its properties
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Create a copy of the pixel buffer for thread safety
        guard let pixelBufferCopy = createPixelBufferCopy(from: pixelBuffer) else {
            print("[H264VideoEncoder] Failed to create pixel buffer copy")
            return
        }
        
        // Get timing information
        let frameData = FrameData(
            pixelBuffer: pixelBufferCopy,
            duration: CMSampleBufferGetDuration(frame),
            presentationTime: CMSampleBufferGetPresentationTimeStamp(frame)
        )
        
        print("[H264VideoEncoder] Processing frame at time: \(frameData.presentationTime.seconds)s")
        
        // Process the frame on a serial queue to maintain order
        Task {
            await self.processFrameInternal(frameData)
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
        guard encodingState else {
            logger.warning("Attempted to process frame while not encoding")
            return
        }
        
        guard let videoWriterInput = videoWriterInput else {
            logger.error("Video writer input is nil")
            return
        }
        
        // Wait until the writer is ready
        while !videoWriterInput.isReadyForMoreMediaData {
            logger.info("Waiting for writer to be ready...")
            Thread.sleep(forTimeInterval: 0.1)
            
            if let error = videoWriter?.error {
                logger.error("Writer error while waiting: \(error.localizedDescription)")
                return
            }
        }
        
        // Create format description
        var formatDescription: CMFormatDescription?
        let err = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frameData.pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard err == noErr, let formatDescription = formatDescription else {
            logger.error("Failed to create format description: \(err)")
            return
        }
        
        // Create sample buffer from pixel buffer
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: frameData.duration,
            presentationTimeStamp: frameData.presentationTime,
            decodeTimeStamp: .invalid
        )
        
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frameData.pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if status != noErr {
            logger.error("Failed to create sample buffer: \(status)")
            return
        }
        
        guard let sampleBuffer = sampleBuffer else {
            logger.error("Sample buffer is nil after creation")
            return
        }
        
        if !videoWriterInput.append(sampleBuffer) {
            if let error = videoWriter?.error {
                logger.error("Failed to append sample buffer: \(error.localizedDescription)")
            } else {
                logger.error("Failed to append sample buffer with unknown error")
            }
            return
        }
        
        logger.info("Successfully processed frame at time: \(frameData.presentationTime.seconds)s")
    }
    
    /// Start encoding video to a specified URL
    /// - Parameters:
    ///   - outputURL: The destination URL for the encoded video file
    ///   - width: The width of the video in pixels
    ///   - height: The height of the video in pixels
    /// - Throws: An error if encoding initialization fails
    public func startEncoding(to outputURL: URL, width: Int, height: Int) async throws {
        try await startEncodingInternal(to: outputURL, width: width, height: height)
    }
    
    /// Internal method to start encoding within the actor's isolation domain
    private func startEncodingInternal(to outputURL: URL, width: Int, height: Int) async throws {
        logger.info("Starting encoding to \(outputURL.path) with dimensions \(width)x\(height)")
        
        // Check if already encoding - do this synchronously within the actor
        if encodingState {
            logger.warning("Encoding is already in progress")
            throw EncodingError.encodingAlreadyInProgress
        }
        
        // Remove any existing file
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
            logger.info("Removed existing file at \(outputURL.path)")
        }
        
        // Create video writer
        do {
            videoWriter = try AVAssetWriter(url: outputURL, fileType: .mp4)
            logger.info("Created AVAssetWriter successfully")
        } catch {
            logger.error("Failed to create AVAssetWriter: \(error.localizedDescription)")
            throw error
        }
        
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
            logger.info("Added video writer input to writer")
            
            videoWriter.startWriting()
            logger.info("Started writing session")
            
            videoWriter.startSession(atSourceTime: .zero)
            logger.info("Started writing session at time zero")
            
            // Update both the internal and published state
            encodingState = true
            updatePublishedState(true)
            logger.info("Encoding started successfully")
        } else {
            logger.error("Failed to initialize video writer or input")
            throw EncodingError.encoderInitializationFailed
        }
    }
    
    /// Stop the current encoding session and finalize the video file
    public func stopEncoding() async {
        await stopEncodingInternal()
    }
    
    /// Internal method to stop encoding within the actor's isolation domain
    private func stopEncodingInternal() async {
        guard encodingState else {
            logger.warning("Attempted to stop encoding when not encoding")
            return
        }
        
        logger.info("Stopping encoding session")
        encodingState = false
        updatePublishedState(false)
        
        videoWriterInput?.markAsFinished()
        
        if let writer = videoWriter {
            writer.finishWriting { [weak self] in
                if let error = writer.error {
                    self?.logger.error("Writer finished with error: \(error.localizedDescription)")
                } else {
                    self?.logger.info("Writer finished successfully")
                }
                Task { @MainActor [weak self] in
                    await self?.cleanupEncoding()
                }
            }
        }
    }
    
    /// Clean up the encoding session by resetting state
    private func cleanupEncoding() {
        logger.info("Cleaning up encoding session")
        videoWriter = nil
        videoWriterInput = nil
    }
    
    /// Start encoding with specific settings and a callback for encoded data
    /// - Parameters:
    ///   - settings: The encoder settings to use
    ///   - callback: Callback to receive encoded frame data
    public func startEncoding(settings: H264EncoderSettings, callback: @escaping (_ data: Data, _ pts: CMTime, _ isKeyFrame: Bool) -> Void) async throws {
        // Get the current encoding state
        let isCurrentlyEncoding = encodingState
        
        guard !isCurrentlyEncoding else {
            throw EncodingError.alreadyEncoding
        }
        
        // Set the callback
        self.encodedDataCallback = callback
        
        // Initialize encoding with settings
        try await startEncodingInternal(
            to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_video.mp4"),
            width: Int(settings.resolution.width),
            height: Int(settings.resolution.height)
        )
    }
    
    /// Nonisolated version of startEncoding
    /// - Parameters:
    ///   - outputURL: The destination URL for the encoded video file
    ///   - width: The width of the video in pixels
    ///   - height: The height of the video in pixels
    /// - Throws: An error if encoding initialization fails
    nonisolated private func nonisolated_startEncoding(to outputURL: URL, width: Int, height: Int) throws {
        guard width > 0 else { throw EncodingError.invalidWidth }
        guard height > 0 else { throw EncodingError.invalidHeight }
        
        // Check if the output directory exists and is writable
        let outputDirectory = outputURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: outputDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw EncodingError.outputPathError
        }
        
        // Check if we can write to the output directory
        guard FileManager.default.isWritableFile(atPath: outputDirectory.path) else {
            throw EncodingError.outputPathError
        }
        
        // Start the encoding session synchronously
        let semaphore = DispatchSemaphore(value: 0)
        var setupError: Error?
        
        Task { @MainActor [weak self] in
            do {
                try await self?.startEncodingInternal(to: outputURL, width: width, height: height)
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
}

/// Errors that can occur during video encoding
public enum EncodingError: Error {
    case invalidWidth
    case invalidHeight
    case formatDescriptionCreationFailed
    case sampleBufferCreationFailed
    case pixelBufferCreationFailed
    case encodingNotStarted
    case encodingAlreadyInProgress
    case outputPathError
    case encoderInitializationFailed
    case alreadyEncoding
}

#else
#error("H264VideoEncoder is only available on macOS 14.0 or later")
#endif
