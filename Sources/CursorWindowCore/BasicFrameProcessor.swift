import Foundation
import AVFoundation
import CoreImage
import CoreVideo

#if os(macOS)
/// A basic implementation of frame processing that can be used as a starting point
/// for more complex frame processing operations.
@available(macOS 14.0, *)
public final class BasicFrameProcessor: FrameProcessor, @unchecked Sendable {
    /// Configuration options for frame processing
    public struct Configuration: Sendable {
        /// Target frame rate for processing
        public let targetFrameRate: Int
        /// Whether to collect statistics
        public let collectStatistics: Bool
        /// Whether to apply basic image processing
        public let enableImageProcessing: Bool
        
        public init(
            targetFrameRate: Int = 30,
            collectStatistics: Bool = true,
            enableImageProcessing: Bool = false
        ) {
            self.targetFrameRate = targetFrameRate
            self.collectStatistics = collectStatistics
            self.enableImageProcessing = enableImageProcessing
        }
    }
    
    /// Statistics about frame processing
    public struct Statistics: Sendable {
        /// Number of frames processed
        public var processedFrameCount: Int = 0
        /// Average processing time per frame in milliseconds
        public var averageProcessingTime: Double = 0
        /// Current frames per second
        public var currentFPS: Double = 0
        /// Time of last frame processing
        public var lastFrameTime: Date?
        /// Number of dropped frames
        public var droppedFrameCount: Int = 0
        
        mutating func update(processingTime: TimeInterval, targetFrameRate: Int) {
            let now = Date()
            
            // Check for dropped frames before updating lastFrameTime
            if let lastTime = lastFrameTime {
                let timeSinceLastFrame = now.timeIntervalSince(lastTime)
                let expectedFrameInterval = 1.0 / Double(targetFrameRate)
                
                if timeSinceLastFrame > expectedFrameInterval * 1.5 {
                    // If the time between frames is more than 1.5x the expected interval,
                    // count the extra frames as dropped
                    let droppedFrames = Int((timeSinceLastFrame / expectedFrameInterval) - 1)
                    droppedFrameCount += droppedFrames
                }
            }
            
            lastFrameTime = now
            processedFrameCount += 1
            
            // Update average processing time using exponential moving average
            let alpha = 0.1 // Smoothing factor
            averageProcessingTime = (averageProcessingTime * (1 - alpha)) + (processingTime * 1000 * alpha)
            
            // Calculate current FPS based on time since last frame
            if let lastTime = lastFrameTime {
                let timeSinceLastFrame = now.timeIntervalSince(lastTime)
                if timeSinceLastFrame > 0 {
                    currentFPS = 1.0 / timeSinceLastFrame
                }
            }
        }
    }
    
    private let configuration: Configuration
    private var statistics: Statistics
    private let ciContext: CIContext
    
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.statistics = Statistics()
        self.ciContext = CIContext()
    }
    
    public func processFrame(_ frame: CVPixelBuffer, timestamp: CMTime) async throws -> Data? {
        let startTime = Date()
        
        // Create CIImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: frame)
        
        // Apply basic image processing if enabled
        let processedImage = configuration.enableImageProcessing ? applyImageProcessing(to: ciImage) : ciImage
        
        // Convert processed image back to pixel buffer
        var processedBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(frame),
            CVPixelBufferGetHeight(frame),
            CVPixelBufferGetPixelFormatType(frame),
            nil,
            &processedBuffer
        )
        
        if let processedBuffer = processedBuffer {
            ciContext.render(processedImage, to: processedBuffer)
            
            // Update statistics if enabled
            if configuration.collectStatistics {
                let processingTime = Date().timeIntervalSince(startTime)
                statistics.update(processingTime: processingTime, targetFrameRate: configuration.targetFrameRate)
            }
            
            // Convert pixel buffer to Data
            return try encodePixelBuffer(processedBuffer)
        }
        
        return nil
    }
    
    private func applyImageProcessing(to image: CIImage) -> CIImage {
        // Apply basic color adjustments
        var processedImage = image
        
        // Example: Adjust brightness and contrast
        if let brightnessFilter = CIFilter(name: "CIColorControls") {
            brightnessFilter.setValue(processedImage, forKey: kCIInputImageKey)
            brightnessFilter.setValue(1.1, forKey: kCIInputBrightnessKey) // Slight brightness boost
            brightnessFilter.setValue(1.1, forKey: kCIInputContrastKey)   // Slight contrast boost
            if let outputImage = brightnessFilter.outputImage {
                processedImage = outputImage
            }
        }
        
        return processedImage
    }
    
    private func encodePixelBuffer(_ buffer: CVPixelBuffer) throws -> Data {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw NSError(domain: "BasicFrameProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create color space"])
        }
        
        guard let data = context.jpegRepresentation(of: ciImage, colorSpace: colorSpace) else {
            throw NSError(domain: "BasicFrameProcessor", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create JPEG representation"])
        }
        
        return data
    }
}
#endif 