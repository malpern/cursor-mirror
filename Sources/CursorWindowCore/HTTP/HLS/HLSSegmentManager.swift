import Foundation
import AVFoundation
import CoreMedia
import os.log

/// Sendable wrapper for CMSampleBuffer to safely pass across actor boundaries
@available(macOS 14.0, *)
public struct SendableSampleBuffer: @unchecked Sendable {
    private let buffer: CMSampleBuffer
    
    public init(_ buffer: CMSampleBuffer) {
        self.buffer = buffer
    }
    
    public var unwrapped: CMSampleBuffer {
        return buffer
    }
}

/// Manages HLS video segments
public actor HLSSegmentManager {
    /// Target duration for segments in seconds
    private let targetSegmentDuration: Double
    
    /// Maximum number of segments to keep per quality
    private let maxSegmentCount: Int
    
    /// Directory where segments are stored
    private let segmentDirectory: URL
    
    /// Current segments by quality
    private var segments: [StreamQuality: [HLSPlaylistGenerator.SegmentInfo]] = [:]
    
    /// Current segment writers by quality
    private var segmentWriters: [StreamQuality: HLSSegmentWriter] = [:]
    
    /// Current segment number by quality
    private var currentSegmentNumbers: [StreamQuality: Int] = [:]
    
    /// Current segment start times by quality
    private var segmentStartTimes: [StreamQuality: CMTime] = [:]
    
    /// Logger
    private let logger = Logger(subsystem: "com.cursor-window", category: "HLSSegmentManager")
    
    /// Initialize the segment manager
    /// - Parameters:
    ///   - segmentDirectory: Directory to store segments
    ///   - targetSegmentDuration: Target duration for segments (seconds)
    ///   - maxSegmentCount: Maximum number of segments to keep per quality
    public init(
        segmentDirectory: URL,
        targetSegmentDuration: Double = 4.0,
        maxSegmentCount: Int = 5
    ) {
        self.segmentDirectory = segmentDirectory
        self.targetSegmentDuration = targetSegmentDuration
        self.maxSegmentCount = maxSegmentCount
        
        // Create the segment directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: segmentDirectory,
            withIntermediateDirectories: true
        )
        
        // Initialize the segments dictionary
        for quality in StreamQuality.allCases {
            segments[quality] = []
            currentSegmentNumbers[quality] = 0
            
            // Create quality-specific directories
            let qualityDir = segmentDirectory.appendingPathComponent(quality.directoryName)
            try? FileManager.default.createDirectory(
                at: qualityDir,
                withIntermediateDirectories: true
            )
        }
    }
    
    /// Start a new segment for a specific quality
    /// - Parameters:
    ///   - quality: Stream quality
    ///   - formatDescription: Format description for segment
    /// - Returns: Segment number
    public func startNewSegment(quality: StreamQuality, formatDescription: CMFormatDescription) throws -> Int {
        // End any existing segment
        if segmentWriters[quality] != nil {
            let _ = try endSegment(quality: quality)
        }
        
        // Create a new segment writer
        let segmentNumber = currentSegmentNumbers[quality, default: 0]
        let segmentFileName = "segment\(segmentNumber).ts"
        let segmentPath = segmentDirectory
            .appendingPathComponent(quality.directoryName)
            .appendingPathComponent(segmentFileName)
        
        // Create a new segment writer
        let writer = try HLSSegmentWriter(outputURL: segmentPath, formatDescription: formatDescription)
        segmentWriters[quality] = writer
        
        // Update state
        segmentStartTimes[quality] = CMTime.zero
        currentSegmentNumbers[quality] = segmentNumber + 1
        
        return segmentNumber
    }
    
    /// Append a sample buffer to the current segment
    /// - Parameters:
    ///   - sampleBuffer: Video sample buffer
    ///   - quality: Stream quality
    /// - Returns: True if a new segment was started due to duration
    public func appendSampleBuffer(_ sampleBuffer: SendableSampleBuffer, quality: StreamQuality) throws -> Bool {
        guard let writer = segmentWriters[quality] else {
            throw NSError(domain: "HLSSegmentManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No active segment writer for quality \(quality)"
            ])
        }
        
        // Get the presentation timestamp
        let buffer = sampleBuffer.unwrapped
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        
        // If this is the first sample, store the start time
        if segmentStartTimes[quality] == CMTime.zero {
            segmentStartTimes[quality] = pts
        }
        
        // Calculate duration since segment start
        let startTime = segmentStartTimes[quality, default: CMTime.zero]
        let duration = CMTimeGetSeconds(CMTimeSubtract(pts, startTime))
        
        // Append the sample buffer
        try writer.append(sampleBuffer: buffer)
        
        // Check if we've reached the target duration
        if duration >= targetSegmentDuration {
            _ = try endSegment(quality: quality)
            return true
        }
        
        return false
    }
    
    /// End the current segment for a quality
    /// - Parameter quality: Stream quality
    /// - Returns: Segment info if a segment was ended
    public func endSegment(quality: StreamQuality) throws -> HLSPlaylistGenerator.SegmentInfo? {
        guard let writer = segmentWriters[quality] else {
            return nil
        }
        
        // Get segment number and duration
        let segmentNumber = currentSegmentNumbers[quality, default: 1] - 1
        let fileName = "segment\(segmentNumber).ts"
        
        // Remove unused variable and just access directly
        let duration = writer.duration
        
        // Close the writer
        try writer.finish()
        segmentWriters[quality] = nil
        
        // Create segment info
        let info = HLSPlaylistGenerator.SegmentInfo(
            filename: fileName,
            duration: duration,
            isDiscontinuity: false
        )
        
        // Add to segments and maintain max count
        var qualitySegments = segments[quality, default: []]
        qualitySegments.append(info)
        
        if qualitySegments.count > maxSegmentCount {
            // Remove the oldest segment
            let oldestSegment = qualitySegments.removeFirst()
            
            // Delete the file for the oldest segment
            let oldPath = segmentDirectory
                .appendingPathComponent(quality.directoryName)
                .appendingPathComponent(oldestSegment.filename)
            
            try? FileManager.default.removeItem(at: oldPath)
        }
        
        segments[quality] = qualitySegments
        
        logger.info("Ended segment \(segmentNumber) for quality \(quality.rawValue), duration: \(duration)s")
        
        return info
    }
    
    /// Get all segments for a specific quality
    /// - Parameter quality: Stream quality
    /// - Returns: Array of segment info
    public func getSegments(for quality: StreamQuality) -> [HLSPlaylistGenerator.SegmentInfo] {
        return segments[quality, default: []]
    }
    
    /// Get the data for a specific segment
    /// - Parameters:
    ///   - segmentName: Segment filename
    ///   - quality: Stream quality
    /// - Returns: Segment data
    public func getSegmentData(fileName: String, quality: StreamQuality) throws -> Data {
        let segmentPath = segmentDirectory
            .appendingPathComponent(quality.directoryName)
            .appendingPathComponent(fileName)
        
        return try Data(contentsOf: segmentPath)
    }
    
    /// Clean up all segments
    public func cleanUp() {
        // End all active segments
        for quality in segmentWriters.keys {
            do {
                let _ = try endSegment(quality: quality)
            } catch {
                // Log the error but continue cleanup
                logger.error("Error ending segment during cleanup: \(error.localizedDescription)")
            }
        }
        
        // Clear segments
        segments.removeAll()
        
        // Delete segment files
        try? FileManager.default.removeItem(at: segmentDirectory)
        try? FileManager.default.createDirectory(
            at: segmentDirectory,
            withIntermediateDirectories: true
        )
    }
}

/// Writes HLS compatible MPEG-TS segments from sample buffers
private class HLSSegmentWriter {
    /// Output URL
    private let outputURL: URL
    
    /// Format description for the video stream
    private let formatDescription: CMFormatDescription
    
    /// Asset writer for writing media
    private var assetWriter: AVAssetWriter?
    
    /// Video input for the asset writer
    private var assetWriterInput: AVAssetWriterInput?
    
    /// Whether the writer is currently writing
    private var isWriting = false
    
    /// Current segment duration
    private(set) var duration: Double = 0.0
    
    /// Start time of the current segment
    private var startTime: CMTime?
    
    init(outputURL: URL, formatDescription: CMFormatDescription) throws {
        self.outputURL = outputURL
        self.formatDescription = formatDescription
        
        // Create asset writer with MPEG-4 format (we'll convert to TS segments later)
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        
        // Configure writer input with video settings for HLS compatibility
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 393,  // Match viewport size
            AVVideoHeightKey: 852,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,  // Important for streaming
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ]
        
        assetWriterInput = AVAssetWriterInput(mediaType: .video,
                                            outputSettings: videoSettings,
                                            sourceFormatHint: formatDescription)
        assetWriterInput?.expectsMediaDataInRealTime = true
        
        if let input = assetWriterInput, let writer = assetWriter {
            writer.add(input)
            try writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            isWriting = true
        }
    }
    
    func append(sampleBuffer: CMSampleBuffer) throws {
        guard let input = assetWriterInput,
              input.isReadyForMoreMediaData else {
            return
        }
        
        // Update duration
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if startTime == nil {
            startTime = presentationTime
        }
        
        if let start = startTime {
            duration = CMTimeGetSeconds(CMTimeSubtract(presentationTime, start))
        }
        
        input.append(sampleBuffer)
    }
    
    func finish() throws {
        guard let writer = assetWriter, isWriting else { return }
        
        assetWriterInput?.markAsFinished()
        
        let finishGroup = DispatchGroup()
        finishGroup.enter()
        
        writer.finishWriting {
            self.isWriting = false
            finishGroup.leave()
        }
        
        finishGroup.wait()
    }
} 