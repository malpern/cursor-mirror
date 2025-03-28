import Foundation
import AVFoundation
import CoreVideo
import VideoToolbox
import Combine
import CoreMedia
import OSLog

// Add logger definition
private let logger = Logger(subsystem: "com.cursor-window", category: "H264VideoEncoder")

/// A wrapper to make CVPixelBuffer Sendable
@available(macOS 14.0, *)
fileprivate struct SendablePixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

/// H.264 video encoder implementation
@available(macOS 14.0, *)
@MainActor
public class H264VideoEncoder: ObservableObject, EncodingFrameProcessorProtocol, FrameProcessor {
    // MARK: - Public properties
    @Published public private(set) var isEncoding: Bool = false
    @Published public private(set) var error: Error?
    
    // MARK: - Private properties
    private var compressionSession: VTCompressionSession?
    private var currentSettings: (width: Int, height: Int, frameRate: Double, quality: Double)?
    internal var callbackHandler: ((CMSampleBuffer, Error?, Bool) -> Void)?
    private let viewportSize: ViewportSize
    private var frameCount: UInt64 = 0
    private var encodeStartTime: CFAbsoluteTime = 0
    private var _delegate: VideoEncoderDelegate?
    private var _formatDescription: CMFormatDescription?
    
    public nonisolated var delegate: VideoEncoderDelegate? {
        get async {
            await _delegate
        }
    }
    
    public nonisolated var formatDescription: CMFormatDescription? {
        get async {
            await _formatDescription
        }
    }
    
    public init(viewportSize: ViewportSize) async throws {
        self.viewportSize = viewportSize
        
        // Verify VideoToolbox is available on this device
        guard VTIsHardwareDecodeSupported(kCMVideoCodecType_H264) else {
            logger.error("H264VideoEncoder: H.264 hardware decoding is not supported on this device")
            throw EncoderError.hardwareEncodingNotSupported
        }
    }
    
    deinit {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }
    
    public nonisolated func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) async {
        // Call the renamed implementation
        await processEncoderFrame(pixelBuffer, timestamp: timestamp)
    }
    
    public nonisolated func startEncoding(to outputURL: URL, width: Int, height: Int) async throws {
        try await MainActor.run {
            do {
                // Store the current settings
                self.currentSettings = (width: width, height: height, frameRate: 30.0, quality: 0.8)
                
                // Configure the compression session with the current settings
                try configureCompressionSession()
                
                // Mark as encoding
                self.isEncoding = true
                self.error = nil
                self.frameCount = 0
                self.encodeStartTime = CFAbsoluteTimeGetCurrent()
                
                logger.info("H264VideoEncoder: Started encoding with resolution \(width)x\(height)")
            } catch {
                self.error = error
                logger.error("H264VideoEncoder: Failed to start encoding: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    public nonisolated func startEncoding(to outputURL: URL, width: Int, height: Int, completionHandler: @escaping (CMSampleBuffer, Error?, Bool) -> Void) async throws {
        try await MainActor.run {
            do {
                // Store the current settings
                self.currentSettings = (width: width, height: height, frameRate: 30.0, quality: 0.8)
                self.callbackHandler = completionHandler
                
                // Configure the compression session with the current settings
                try configureCompressionSession()
                
                // Mark as encoding
                self.isEncoding = true
                self.error = nil
                self.frameCount = 0
                self.encodeStartTime = CFAbsoluteTimeGetCurrent()
                
                logger.info("H264VideoEncoder: Started encoding with callback handler")
            } catch {
                self.error = error
                logger.error("H264VideoEncoder: Failed to start encoding: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    public nonisolated func stopEncoding() async {
        await MainActor.run {
            if let session = compressionSession {
                VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
                VTCompressionSessionInvalidate(session)
                compressionSession = nil
            }
            
            callbackHandler = nil
            isEncoding = false
            
            logger.info("H264VideoEncoder: Stopped encoding")
        }
    }
    
    // MARK: - Private methods
    
    private func configureCompressionSession() throws {
        // Clean up any existing session
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        
        guard let settings = currentSettings else {
            throw EncoderError.encodingSettingsNotConfigured
        }
        
        // Create a new compression session
        var session: VTCompressionSession?
        var status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(settings.width),
            height: Int32(settings.height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: compressionOutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )
        
        guard status == noErr, let session = session else {
            logger.error("H264VideoEncoder: Failed to create compression session with status \(status)")
            throw EncoderError.compressionSessionCreationFailed
        }
        
        // Configure session properties
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        
        // Set frame rate
        let frameRate = settings.frameRate
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: frameRate))
        
        // Calculate bitrate based on resolution
        let bitrate = 1000000 * Int(settings.quality * 2) // Base bitrate * quality factor
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: bitrate))
        
        // Configure key frame interval
        let keyframeInterval = Int32(frameRate) * 2 // Key frame every 2 seconds
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: keyframeInterval))
        
        // Prepare the session
        status = VTCompressionSessionPrepareToEncodeFrames(session)
        guard status == noErr else {
            logger.error("H264VideoEncoder: Failed to prepare compression session with status \(status)")
            throw EncoderError.compressionSessionPreparationFailed
        }
        
        // Store the session
        compressionSession = session
        logger.info("H264VideoEncoder: Configured compression session with \(settings.width)x\(settings.height) at \(settings.frameRate) fps")
    }
    
    private func updateDelegate(_ delegate: VideoEncoderDelegate?) {
        self._delegate = delegate
    }
    
    public nonisolated func setDelegate(_ delegate: VideoEncoderDelegate?) async {
        await updateDelegate(delegate)
    }
    
    // MARK: - Error types
    
    public enum EncoderError: Error {
        case hardwareEncodingNotSupported
        case compressionSessionCreationFailed
        case compressionSessionPreparationFailed
        case encodingSettingsNotConfigured
    }
    
    // Add implementation for FrameProcessor protocol
    public func processFrame(_ frame: CVPixelBuffer, timestamp: CMTime) async throws -> Data? {
        // Process the frame without returning data - for FrameProcessor conformance
        await self.processEncoderFrame(frame, timestamp: timestamp)
        return nil
    }
    
    // Rename to avoid ambiguity
    private nonisolated func processEncoderFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) async {
        await MainActor.run {
            guard isEncoding, let session = compressionSession else {
                logger.warning("H264VideoEncoder: Cannot process frame - not encoding or session is nil")
                return
            }
            
            // Update frame count and log performance
            frameCount += 1
            if frameCount % 100 == 0 {
                let elapsedTime = CFAbsoluteTimeGetCurrent() - encodeStartTime
                let fps = Double(frameCount) / elapsedTime
                logger.info("H264VideoEncoder: Processed \(self.frameCount) frames at \(String(format: "%.2f", fps)) fps")
            }
            
            // Prepare frame properties
            let frameProperties: [String: Any] = [
                kVTEncodeFrameOptionKey_ForceKeyFrame as String: (frameCount % 60) == 0
            ]
            
            // Encode the frame
            var flags: VTEncodeInfoFlags = []
            let status = VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: pixelBuffer,
                presentationTimeStamp: timestamp,
                duration: .invalid,
                frameProperties: frameProperties as CFDictionary,
                sourceFrameRefcon: nil,
                infoFlagsOut: &flags
            )
            
            if status != noErr {
                let error = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to encode frame"])
                self.error = error
                logger.error("H264VideoEncoder: Failed to encode frame: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Compression callback

private let compressionOutputCallback: VTCompressionOutputCallback = { outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer in
    guard let sampleBuffer = sampleBuffer else {
        return
    }
    
    guard status == noErr else {
        print("Error in compression callback: \(status)")
        return
    }
    
    guard let refCon = outputCallbackRefCon else {
        return
    }
    
    let encoderObject = Unmanaged<H264VideoEncoder>.fromOpaque(refCon).takeUnretainedValue()
    
    Task { @MainActor in
        if let callbackHandler = encoderObject.callbackHandler {
            callbackHandler(sampleBuffer, nil, false)
        }
    }
} 