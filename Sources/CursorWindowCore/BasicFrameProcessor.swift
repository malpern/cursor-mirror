import Foundation
import AVFoundation
import CoreImage
import CoreVideo

#if os(macOS)
/// A basic implementation of frame processing that can be used as a starting point
/// for more complex frame processing operations.
@available(macOS 14.0, *)
public final class BasicFrameProcessor: @unchecked Sendable {
    /// Configuration options for frame processing
    public struct Configuration: Sendable {
        /// Target frame rate for processing
        public let targetFrameRate: Int
        /// Whether to collect frame timing statistics
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
                    droppedFrameCount += 1
                }
            }
            
            processedFrameCount += 1
            averageProcessingTime = (averageProcessingTime * Double(processedFrameCount - 1) + processingTime * 1000) / Double(processedFrameCount)
            
            if let lastTime = lastFrameTime {
                currentFPS = 1.0 / now.timeIntervalSince(lastTime)
            }
            lastFrameTime = now
        }
    }
    
    /// Current configuration
    public private(set) var configuration: Configuration
    
    /// Current statistics
    public private(set) var statistics: Statistics
    
    /// CIContext for image processing
    private lazy var ciContext: CIContext = {
        CIContext(options: [.useSoftwareRenderer: false])
    }()
    
    /// Queue for frame processing
    private let processingQueue = DispatchQueue(
        label: "com.cursorwindow.basicframeprocessor",
        qos: .userInitiated
    )
    
    /// Frame rate limiter
    private var lastProcessingTime: Date?
    private var targetProcessingInterval: TimeInterval {
        1.0 / Double(configuration.targetFrameRate)
    }
    
    /// Actor for thread-safe state updates
    private actor StateManager {
        var statistics: Statistics
        var configuration: Configuration
        var onStatisticsUpdate: ((Statistics) -> Void)?
        
        init(statistics: Statistics, configuration: Configuration) {
            self.statistics = statistics
            self.configuration = configuration
        }
        
        func updateStatistics(_ update: (inout Statistics) -> Void) {
            update(&statistics)
            onStatisticsUpdate?(statistics)
        }
        
        func updateConfiguration(_ newConfig: Configuration) {
            configuration = newConfig
        }
        
        func getConfiguration() -> Configuration {
            configuration
        }
        
        func getStatistics() -> Statistics {
            statistics
        }
        
        func resetStatistics() {
            statistics = Statistics()
        }
        
        func setStatisticsCallback(_ callback: @escaping (Statistics) -> Void) {
            onStatisticsUpdate = callback
        }
    }
    
    /// State manager for thread-safe updates
    private let stateManager: StateManager
    
    /// Initialize a new BasicFrameProcessor
    /// - Parameter configuration: Configuration options for frame processing
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.statistics = Statistics()
        self.stateManager = StateManager(statistics: Statistics(), configuration: configuration)
    }
    
    /// Update the processor configuration
    /// - Parameter configuration: New configuration to apply
    public func updateConfiguration(_ configuration: Configuration) {
        Task {
            await stateManager.updateConfiguration(configuration)
            self.configuration = configuration
        }
    }
    
    /// Reset processing statistics
    public func resetStatistics() {
        Task {
            await stateManager.resetStatistics()
            self.statistics = Statistics()
        }
    }
    
    /// Set the callback for statistics updates
    /// - Parameter callback: The function to call when statistics are updated
    public func setStatisticsCallback(_ callback: @escaping (Statistics) -> Void) {
        Task {
            await stateManager.setStatisticsCallback(callback)
        }
    }
    
    /// Extract metadata from a frame
    /// - Parameter frame: The frame to extract metadata from
    /// - Returns: Dictionary containing frame metadata
    private func extractMetadata(from frame: CMSampleBuffer) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        // Extract basic timing information
        metadata["presentationTime"] = CMSampleBufferGetPresentationTimeStamp(frame)
        metadata["duration"] = CMSampleBufferGetDuration(frame)
        
        // Extract format description
        if let formatDescription = CMSampleBufferGetFormatDescription(frame) {
            metadata["mediaType"] = CMFormatDescriptionGetMediaType(formatDescription)
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            metadata["width"] = dimensions.width
            metadata["height"] = dimensions.height
        }
        
        // Extract attachments if any
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(frame, createIfNecessary: false) as? [[CFString: Any]],
           let firstAttachment = attachments.first {
            metadata["attachments"] = firstAttachment
        }
        
        return metadata
    }
    
    /// Apply basic image processing to a frame
    /// - Parameter pixelBuffer: The pixel buffer to process
    /// - Returns: Processed pixel buffer, or nil if processing failed
    private func processImage(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        guard configuration.enableImageProcessing else { return pixelBuffer }
        
        // Create CIImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply basic adjustments (example: brightness and contrast)
        let adjustedImage = ciImage
            .applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: 0.0,
                kCIInputContrastKey: 1.1,
                kCIInputSaturationKey: 1.0
            ])
        
        // Create a new pixel buffer for the processed image
        var processedBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            nil,
            &processedBuffer
        )
        
        guard let processedBuffer = processedBuffer else { return nil }
        
        // Render the processed image into the new pixel buffer
        ciContext.render(adjustedImage, to: processedBuffer)
        
        return processedBuffer
    }
    
    /// Get the current statistics
    /// - Returns: Current processing statistics
    public func getCurrentStatistics() async -> Statistics {
        await stateManager.getStatistics()
    }
}

@available(macOS 14.0, *)
extension BasicFrameProcessor: BasicFrameProcessorProtocol {
    /// Process a single frame from the screen capture stream
    /// - Parameter frame: A CMSampleBuffer containing the captured frame data
    nonisolated public func processFrame(_ frame: CMSampleBuffer) {
        // Frame rate limiting
        let now = Date()
        if let lastTime = lastProcessingTime {
            let timeSinceLastFrame = now.timeIntervalSince(lastTime)
            if timeSinceLastFrame < targetProcessingInterval {
                return // Skip frame if we're processing too fast
            }
        }
        lastProcessingTime = now
        
        // Extract frame data in the nonisolated context
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame) else { return }
        
        // Lock the buffer for reading
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Create a copy of the pixel buffer for thread safety
        guard let pixelBufferCopy = createPixelBufferCopy(from: pixelBuffer) else { return }
        
        let startTime = Date()
        
        Task { [weak self] in
            guard let self = self else { return }
            
            let config = await self.stateManager.getConfiguration()
            
            // Process image if enabled
            if config.enableImageProcessing {
                _ = self.processImage(pixelBuffer: pixelBufferCopy)
            }
            
            // Update statistics
            if config.collectStatistics {
                let processingTime = Date().timeIntervalSince(startTime)
                await self.stateManager.updateStatistics { stats in
                    stats.update(processingTime: processingTime, targetFrameRate: config.targetFrameRate)
                }
            }
        }
    }
    
    /// Create a copy of a pixel buffer
    /// - Parameter source: The source pixel buffer to copy
    /// - Returns: A new pixel buffer containing the same data
    private nonisolated func createPixelBufferCopy(from source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
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
            let bytesPerRow = CVPixelBufferGetBytesPerRow(source)
            memcpy(dstAddress, srcAddress, bytesPerRow * height)
        }
        
        return pixelBufferCopy
    }
}
#endif 