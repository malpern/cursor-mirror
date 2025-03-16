import Foundation
import AVFoundation
import VideoToolbox
import CoreMedia

/// Errors that can occur during video encoding
enum VideoEncodingError: Error {
    case sessionSetupFailed
    case compressionSessionCreationFailed
    case pixelBufferCreationFailed
    case encodingFailed
    case invalidConfiguration
    
    var localizedDescription: String {
        switch self {
        case .sessionSetupFailed:
            return "Failed to set up encoding session"
        case .compressionSessionCreationFailed:
            return "Failed to create compression session"
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer from image"
        case .encodingFailed:
            return "Failed to encode frame"
        case .invalidConfiguration:
            return "Invalid encoder configuration"
        }
    }
}

/// Protocol defining the interface for a video encoder
protocol VideoEncoderProtocol {
    /// Start the encoding session
    func startSession(width: Int, height: Int, frameRate: Int) throws
    
    /// Encode a single frame
    func encodeFrame(_ image: NSImage, presentationTimeStamp: CMTime) throws -> Data?
    
    /// End the encoding session
    func endSession()
}

/// Configuration for the video encoder
struct VideoEncoderConfiguration {
    /// Width of the video in pixels
    let width: Int
    
    /// Height of the video in pixels
    let height: Int
    
    /// Target frame rate
    let frameRate: Int
    
    /// Target bitrate in bits per second (default: 2,000,000 = 2Mbps)
    let bitrate: Int
    
    /// Key frame interval (default: 60 frames)
    let keyframeInterval: Int
    
    /// Profile level (default: H264 High Profile)
    let profileLevel: CFString
    
    /// Initialize with default values
    init(
        width: Int,
        height: Int,
        frameRate: Int,
        bitrate: Int = 2_000_000,
        keyframeInterval: Int = 60,
        profileLevel: CFString = kVTProfileLevel_H264_High_AutoLevel
    ) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.bitrate = bitrate
        self.keyframeInterval = keyframeInterval
        self.profileLevel = profileLevel
    }
}

/// H.264 video encoder using VideoToolbox
@MainActor
class H264VideoEncoder: VideoEncoderProtocol {
    /// The compression session
    private var compressionSession: VTCompressionSession?
    
    /// Configuration for the encoder
    private var configuration: VideoEncoderConfiguration?
    
    /// Frame count for keyframe interval calculation
    private var frameCount: Int = 0
    
    /// Callback for when a frame is encoded
    private var encodedFrameCallback: ((Data, CMTime) -> Void)?
    
    /// Initialize the encoder
    init() {}
    
    /// Start the encoding session with the specified parameters
    func startSession(width: Int, height: Int, frameRate: Int) throws {
        // Create a default configuration
        let config = VideoEncoderConfiguration(
            width: width,
            height: height,
            frameRate: frameRate
        )
        
        try startSessionWithConfiguration(config)
    }
    
    /// Start the encoding session with a specific configuration
    func startSessionWithConfiguration(_ config: VideoEncoderConfiguration) throws {
        // End any existing session
        endSession()
        
        // Store the configuration
        self.configuration = config
        
        // Create a compression session
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(config.width),
            height: Int32(config.height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        
        // Check if session creation was successful
        guard status == noErr, let session = session else {
            throw VideoEncodingError.compressionSessionCreationFailed
        }
        
        // Store the session
        self.compressionSession = session
        
        // Configure the session
        configureSession(session, with: config)
        
        // Prepare the session
        let prepareStatus = VTCompressionSessionPrepareToEncodeFrames(session)
        guard prepareStatus == noErr else {
            throw VideoEncodingError.sessionSetupFailed
        }
        
        // Reset frame count
        frameCount = 0
    }
    
    /// Configure the compression session with the specified parameters
    private func configureSession(_ session: VTCompressionSession, with config: VideoEncoderConfiguration) {
        // Set properties on the session
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: config.profileLevel)
        
        // Set average and max bitrate
        let bitrate = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &config.bitrate)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate)
        
        // Set keyframe interval
        let interval = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &config.keyframeInterval)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: interval)
        
        // Set frame rate
        let frameRate = CFNumberCreate(kCFAllocatorDefault, CFNumberType.intType, &config.frameRate)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: frameRate)
        
        // Allow frame reordering for better compression
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanTrue)
        
        // Use hardware acceleration if available
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder, value: kCFBooleanTrue)
    }
    
    /// Encode a single frame
    func encodeFrame(_ image: NSImage, presentationTimeStamp: CMTime) throws -> Data? {
        guard let compressionSession = compressionSession,
              let config = configuration else {
            throw VideoEncodingError.invalidConfiguration
        }
        
        // Convert NSImage to CVPixelBuffer
        guard let pixelBuffer = createPixelBuffer(from: image, width: config.width, height: config.height) else {
            throw VideoEncodingError.pixelBufferCreationFailed
        }
        
        // Create a semaphore to wait for encoding completion
        let semaphore = DispatchSemaphore(value: 0)
        var encodedData: Data?
        var encodingError: Error?
        
        // Determine if this should be a keyframe
        let forceKeyframe = frameCount % config.keyframeInterval == 0
        frameCount += 1
        
        // Create frame properties dictionary
        var frameProperties: [CFString: Any] = [:]
        if forceKeyframe {
            frameProperties[kVTEncodeFrameOptionKey_ForceKeyFrame] = kCFBooleanTrue
        }
        
        // Encode the frame
        let status = VTCompressionSessionEncodeFrame(
            compressionSession,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: CMTime.invalid,
            frameProperties: frameProperties as CFDictionary,
            infoFlagsOut: nil
        ) { status, flags, sampleBuffer in
            defer { semaphore.signal() }
            
            // Check for encoding errors
            guard status == noErr else {
                encodingError = VideoEncodingError.encodingFailed
                return
            }
            
            // Extract data from the sample buffer
            if let sampleBuffer = sampleBuffer {
                encodedData = self.extractDataFromSampleBuffer(sampleBuffer)
            }
        }
        
        // Check for immediate errors
        guard status == noErr else {
            throw VideoEncodingError.encodingFailed
        }
        
        // Wait for encoding to complete
        semaphore.wait()
        
        // Check for errors during encoding
        if let error = encodingError {
            throw error
        }
        
        return encodedData
    }
    
    /// End the encoding session
    func endSession() {
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        configuration = nil
        frameCount = 0
    }
    
    /// Convert an NSImage to a CVPixelBuffer
    private func createPixelBuffer(from image: NSImage, width: Int, height: Int) -> CVPixelBuffer? {
        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        // Lock the pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        
        // Get the pixel buffer base address
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        // Create a CGContext with the pixel buffer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        // Draw the image into the context
        if let context = context, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        return pixelBuffer
    }
    
    /// Extract data from a CMSampleBuffer
    private func extractDataFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Data? {
        // Get the format description
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        
        // Get the sample attachment dictionary
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]]
        let isKeyframe = attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool == false
        
        // Get the data buffer
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        // Get the size of the data buffer
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        
        guard status == noErr, let dataPointer = dataPointer else {
            return nil
        }
        
        // Create a Data object from the buffer
        var data = Data(bytes: dataPointer, count: totalLength)
        
        // If this is a keyframe, prepend the SPS and PPS NAL units
        if isKeyframe {
            var parameterSetCount: Int = 0
            var parameterSetPointers: UnsafePointer<UnsafePointer<UInt8>>?
            var parameterSetSizes: UnsafePointer<Int>?
            
            let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDescription,
                parameterSetIndex: 0,
                parameterSetPointerOut: &parameterSetPointers,
                parameterSetSizeOut: &parameterSetSizes,
                parameterSetCountOut: &parameterSetCount,
                nalUnitHeaderLengthOut: nil
            )
            
            if status == noErr, let parameterSetPointers = parameterSetPointers, let parameterSetSizes = parameterSetSizes {
                // Create a new data object with the SPS and PPS NAL units
                var newData = Data()
                
                // Add SPS NAL unit
                let spsSize = parameterSetSizes[0]
                let spsBytes = parameterSetPointers[0]
                let spsData = Data(bytes: spsBytes, count: spsSize)
                
                // Add PPS NAL unit if available
                if parameterSetCount > 1 {
                    let ppsSize = parameterSetSizes[1]
                    let ppsBytes = parameterSetPointers[1]
                    let ppsData = Data(bytes: ppsBytes, count: ppsSize)
                    
                    // Add NAL unit header and SPS
                    newData.append(contentsOf: [0x00, 0x00, 0x00, 0x01])  // NAL unit header
                    newData.append(spsData)
                    
                    // Add NAL unit header and PPS
                    newData.append(contentsOf: [0x00, 0x00, 0x00, 0x01])  // NAL unit header
                    newData.append(ppsData)
                }
                
                // Add NAL unit header and frame data
                newData.append(contentsOf: [0x00, 0x00, 0x00, 0x01])  // NAL unit header
                newData.append(data)
                
                data = newData
            }
        } else {
            // For non-keyframes, just add the NAL unit header
            var newData = Data()
            newData.append(contentsOf: [0x00, 0x00, 0x00, 0x01])  // NAL unit header
            newData.append(data)
            data = newData
        }
        
        return data
    }
    
    /// Set a callback to be called when a frame is encoded
    func setEncodedFrameCallback(_ callback: @escaping (Data, CMTime) -> Void) {
        self.encodedFrameCallback = callback
    }
    
    /// Deinitializer to clean up resources
    deinit {
        endSession()
    }
} 