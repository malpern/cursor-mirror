import Foundation
import AVFoundation
import CoreMedia
import ScreenCaptureKit

/// A frame processor that encodes frames using H.264
@MainActor
class EncodingFrameProcessor: FrameProcessor {
    /// The latest captured image
    @Published private(set) var latestImage: NSImage?
    
    /// Any error that occurred during capture
    @Published private(set) var error: Error?
    
    /// The video encoder
    private let encoder: VideoEncoderProtocol
    
    /// The file writer for saving encoded frames
    private let fileWriter: VideoFileWriter
    
    /// The frame rate for encoding
    private let frameRate: Int
    
    /// The time of the first frame
    private var startTime: CMTime?
    
    /// The frame count
    private var frameCount: Int = 0
    
    /// Callback for when a frame is encoded
    private var encodedFrameCallback: ((Data?, CMTime) -> Void)?
    
    /// The output URL for the encoded video
    private var outputURL: URL?
    
    /// Initialize with a video encoder
    init(encoder: VideoEncoderProtocol, frameRate: Int = 30) {
        self.encoder = encoder
        self.frameRate = frameRate
        self.fileWriter = VideoFileWriter()
    }
    
    /// Process a captured frame
    func processFrame(_ frame: CMSampleBuffer) {
        do {
            // Convert the sample buffer to an image
            guard let image = createImage(from: frame) else {
                throw CaptureError.frameConversionFailed
            }
            
            // Update the latest image
            self.latestImage = image
            
            // Get the presentation timestamp
            let pts = CMSampleBufferGetPresentationTimeStamp(frame)
            
            // If this is the first frame, store the start time
            if startTime == nil {
                startTime = pts
            }
            
            // Calculate the frame time based on frame count and frame rate
            let frameTime = CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(frameRate))
            frameCount += 1
            
            // Encode the frame
            if let encodedData = try encoder.encodeFrame(image, presentationTimeStamp: frameTime) {
                // If we have an output URL, write the encoded data to the file
                if let outputURL = outputURL {
                    try fileWriter.appendEncodedData(encodedData, presentationTime: frameTime)
                }
                
                // Call the callback with the encoded data
                encodedFrameCallback?(encodedData, frameTime)
            }
            
            // Clear any previous error
            self.error = nil
        } catch {
            // Store the error
            self.error = error
        }
    }
    
    /// Handle an error during capture
    func handleError(_ error: Error) {
        self.error = error
    }
    
    /// Start the encoding session
    func startEncoding(width: Int, height: Int, frameRate: Int? = nil) throws {
        // Reset state
        startTime = nil
        frameCount = 0
        
        // Start the encoding session
        try encoder.startSession(width: width, height: height, frameRate: frameRate ?? self.frameRate)
        
        // Clear any previous error
        DispatchQueue.main.async {
            self.error = nil
        }
    }
    
    /// Stop the encoding session
    func stopEncoding() {
        encoder.endSession()
        startTime = nil
    }
    
    /// Set a callback to be called when a frame is encoded
    func setEncodedFrameCallback(_ callback: @escaping (Data?, CMTime) -> Void) {
        self.encodedFrameCallback = callback
    }
    
    /// Start recording to a file
    func startRecording(to url: URL, width: Int, height: Int, frameRate: Int? = nil) throws {
        // Create the file
        try fileWriter.createFile(at: url, width: width, height: height, frameRate: frameRate ?? self.frameRate)
        
        // Store the output URL
        outputURL = url
        
        // Start the encoding session
        try startEncoding(width: width, height: height, frameRate: frameRate)
    }
    
    /// Stop recording and finalizes the file
    func stopRecording() async throws -> URL? {
        guard let outputURL = outputURL else {
            return nil
        }
        
        // Stop the encoding session
        stopEncoding()
        
        // Finish writing the file
        try await fileWriter.finishWriting()
        
        // Clear the output URL
        let finalURL = outputURL
        self.outputURL = nil
        
        return finalURL
    }
    
    /// Cancel recording and deletes the file
    func cancelRecording() {
        // Stop the encoding session
        stopEncoding()
        
        // Cancel writing the file
        fileWriter.cancelWriting()
        
        // Clear the output URL
        outputURL = nil
    }
    
    /// Convert a CMSampleBuffer to an NSImage
    private func createImage(from sampleBuffer: CMSampleBuffer) -> NSImage? {
        // Get the image buffer from the sample buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // Create a CGImage from the CIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return nil
        }
        
        // Create an NSImage from the CGImage
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        
        return nsImage
    }
} 