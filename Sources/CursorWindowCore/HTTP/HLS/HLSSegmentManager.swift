import Foundation
import AVFoundation
import CoreMedia
import os.log

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
            _ = try endSegment(quality: quality)
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
    public func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, quality: StreamQuality) throws -> Bool {
        guard let writer = segmentWriters[quality] else {
            throw NSError(domain: "HLSSegmentManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No active segment writer for quality \(quality)"
            ])
        }
        
        // Get the presentation timestamp
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // If this is the first sample, store the start time
        if segmentStartTimes[quality] == CMTime.zero {
            segmentStartTimes[quality] = pts
        }
        
        // Calculate duration since segment start
        let startTime = segmentStartTimes[quality, default: CMTime.zero]
        let duration = CMTimeGetSeconds(CMTimeSubtract(pts, startTime))
        
        // Append the sample buffer
        try writer.append(sampleBuffer: sampleBuffer)
        
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
        let _ = segmentStartTimes[quality, default: CMTime.zero]
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
            _ = try? endSegment(quality: quality)
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
    
    /// MPEG-2 Transport Stream writer
    private var writer: AVAssetWriter
    
    /// Video input
    private var videoInput: AVAssetWriterInput
    
    /// Segment duration
    private(set) var duration: Double = 0
    
    /// Initialize with output URL and format description
    /// - Parameters:
    ///   - outputURL: Output file URL
    ///   - formatDescription: Video format description
    init(outputURL: URL, formatDescription: CMFormatDescription) throws {
        self.outputURL = outputURL
        
        // Create asset writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: AVFileType(rawValue: "org.mpegts.mpeg-ts"))
        self.writer = writer
        
        // Configure video settings
        let _ = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: CMFormatDescriptionGetExtension(
                formatDescription,
                extensionKey: kCMFormatDescriptionExtension_FormatName
            ) as Any
        ]
        
        // Create input
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: nil,
            sourceFormatHint: formatDescription
        )
        videoInput.expectsMediaDataInRealTime = true
        
        // Add input to writer
        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        } else {
            throw NSError(domain: "HLSSegmentWriter", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cannot add video input to asset writer"
            ])
        }
        
        self.videoInput = videoInput
        
        // Start the session
        writer.startWriting()
        writer.startSession(atSourceTime: CMTime.zero)
    }
    
    /// Append a sample buffer to the segment
    /// - Parameter sampleBuffer: Video sample buffer
    func append(sampleBuffer: CMSampleBuffer) throws {
        // Check if we can append
        guard writer.status == .writing else {
            throw NSError(domain: "HLSSegmentWriter", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Writer is not in writing state: \(writer.status.rawValue)"
            ])
        }
        
        // Wait for input to be ready
        guard videoInput.isReadyForMoreMediaData else {
            throw NSError(domain: "HLSSegmentWriter", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Video input is not ready for more data"
            ])
        }
        
        // Append the sample buffer
        if !videoInput.append(sampleBuffer) {
            throw NSError(domain: "HLSSegmentWriter", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to append sample buffer: \(writer.error?.localizedDescription ?? "unknown error")"
            ])
        }
        
        // Update duration
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        self.duration = CMTimeGetSeconds(presentationTime)
    }
    
    /// Finish writing and close the segment
    func finish() throws {
        // Mark as finished
        videoInput.markAsFinished()
        
        // Finish writing
        let finishGroup = DispatchGroup()
        finishGroup.enter()
        
        writer.finishWriting {
            finishGroup.leave()
        }
        
        // Wait for finish
        finishGroup.wait()
        
        // Check for errors
        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "HLSSegmentWriter", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Unknown error finishing asset writer"
            ])
        }
    }
} 