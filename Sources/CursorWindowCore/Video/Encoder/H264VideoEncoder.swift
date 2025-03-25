import Foundation
import AVFoundation
import VideoToolbox
import Combine

/// H.264 video encoder implementation
@available(macOS 14.0, *)
public final class H264VideoEncoder: VideoEncoder, ObservableObject {
    private var compressionSession: VTCompressionSession?
    private let viewportSize: ViewportSize
    public weak var delegate: VideoEncoderDelegate?
    private var _formatDescription: CMFormatDescription?
    
    @Published public var isEncoding = false
    @Published public var error: Error?
    
    public var formatDescription: CMFormatDescription? {
        return _formatDescription
    }
    
    // Convenience initializer for SwiftUI
    public convenience init() {
        do {
            try self.init(viewportSize: ViewportSize.defaultSize(), delegate: nil)
        } catch {
            fatalError("Failed to initialize encoder: \(error)")
        }
    }
    
    public init(viewportSize: ViewportSize, delegate: VideoEncoderDelegate?) throws {
        self.viewportSize = viewportSize
        self.delegate = delegate
        try configureCompressionSession()
    }
    
    deinit {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }
    
    public func encode(_ buffer: CVPixelBuffer) throws {
        guard let session = compressionSession else {
            throw VideoEncoderError.compressionSessionCreationFailed
        }
        
        let presentationTimeStamp = CMTime(value: CMTimeValue(Date().timeIntervalSince1970 * 1000), timescale: 1000)
        let duration = CMTime(value: 1, timescale: 30)  // 30 fps
        
        var flags = VTEncodeInfoFlags()
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: buffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )
        
        guard status == noErr else {
            throw VideoEncoderError.encodingFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }
    
    public func finishEncoding() throws {
        guard let session = compressionSession else { return }
        let status = VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        guard status == noErr else {
            throw VideoEncoderError.encodingFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }
    
    public func startEncoding(settings: [String: Any], completionHandler: @escaping (Data, CMTime, Bool) -> Void) async throws {
        print("Starting encoding with settings")
        isEncoding = true
    }
    
    public func startEncoding(to outputURL: URL, width: Int, height: Int) async throws {
        print("Starting encoding to \(outputURL)")
        isEncoding = true
    }
    
    public func stopEncoding() async {
        print("Stopping encoding")
        try? finishEncoding()
        isEncoding = false
    }
    
    private func configureCompressionSession() throws {
        let compressionProperties: [String: Any] = [
            String(kVTCompressionPropertyKey_ProfileLevel): kVTProfileLevel_H264_High_AutoLevel,
            String(kVTCompressionPropertyKey_RealTime): true,
            String(kVTCompressionPropertyKey_ExpectedFrameRate): 30,
            String(kVTCompressionPropertyKey_AverageBitRate): 2_000_000,
            String(kVTCompressionPropertyKey_MaxKeyFrameInterval): 60,
            String(kVTCompressionPropertyKey_AllowFrameReordering): false
        ]
        
        var pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: Int(viewportSize.width),
            kCVPixelBufferHeightKey as String: Int(viewportSize.height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]
        
        var formatDescriptionRef: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_H264,
            width: Int32(viewportSize.width),
            height: Int32(viewportSize.height),
            extensions: nil,
            formatDescriptionOut: &formatDescriptionRef
        )
        
        if status == noErr {
            _formatDescription = formatDescriptionRef
        }
        
        var sessionStatus = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(viewportSize.width),
            height: Int32(viewportSize.height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: pixelBufferAttributes as CFDictionary,
            compressedDataAllocator: nil,
            outputCallback: outputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &compressionSession
        )
        
        guard sessionStatus == noErr, let session = compressionSession else {
            throw VideoEncoderError.compressionSessionCreationFailed
        }
        
        sessionStatus = VTSessionSetProperties(session, propertyDictionary: compressionProperties as CFDictionary)
        guard sessionStatus == noErr else {
            throw VideoEncoderError.encodingFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(sessionStatus)))
        }
        
        sessionStatus = VTCompressionSessionPrepareToEncodeFrames(session)
        guard sessionStatus == noErr else {
            throw VideoEncoderError.encodingFailed(NSError(domain: NSOSStatusErrorDomain, code: Int(sessionStatus)))
        }
    }
}

private let outputCallback: VTCompressionOutputCallback = { refcon, _, status, flags, sampleBuffer in
    guard let sampleBuffer = sampleBuffer else { return }
    guard status == noErr else { return }
    
    let encoder = Unmanaged<H264VideoEncoder>.fromOpaque(refcon!).takeUnretainedValue()
    encoder.delegate?.videoEncoder(encoder, didOutputSampleBuffer: sampleBuffer)
} 