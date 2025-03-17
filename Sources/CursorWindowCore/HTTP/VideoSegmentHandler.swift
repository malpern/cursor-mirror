import Foundation
import AVFoundation

/// Handles the creation, storage, and delivery of video segments for HLS streaming
@available(macOS 14.0, *)
public actor VideoSegmentHandler {
    /// Configuration for segment handling
    private let config: VideoSegmentConfig
    
    /// Writer for creating MPEG-TS segments
    private let segmentWriter: TSSegmentWriterProtocol
    
    /// Queue for managing segment storage
    private let storageQueue: OperationQueue
    
    /// Active segments by quality level
    private var activeSegments: [String: [TSSegment]]
    
    /// Initializes a new video segment handler
    /// - Parameters:
    ///   - config: Configuration for segment handling
    ///   - segmentWriter: Writer for creating MPEG-TS segments
    public init(config: VideoSegmentConfig, segmentWriter: TSSegmentWriterProtocol) {
        self.config = config
        self.segmentWriter = segmentWriter
        self.activeSegments = [:]
        
        self.storageQueue = OperationQueue()
        self.storageQueue.maxConcurrentOperationCount = 1
        self.storageQueue.qualityOfService = .userInitiated
    }
    
    /// Process encoded video data and create new segments
    /// - Parameters:
    ///   - data: Encoded video data
    ///   - presentationTime: Presentation timestamp for the data
    ///   - quality: Quality level identifier
    public func processVideoData(_ data: Data, presentationTime: Double, quality: String) async throws {
        try await segmentWriter.writeEncodedData(data, presentationTime: presentationTime)
        
        if let segment = try await segmentWriter.getCurrentSegment() {
            if activeSegments[quality] == nil {
                activeSegments[quality] = []
            }
            
            // Start a new segment if the current one is long enough
            if segment.duration >= config.targetSegmentDuration {
                try await segmentWriter.startNewSegment()
                activeSegments[quality]?.append(segment)
                
                // Clean up old segments if we have too many
                await cleanupOldSegments(for: quality)
            }
        }
    }
    
    /// Get segments for a specific quality level
    /// - Parameter quality: Quality level identifier
    /// - Returns: Array of segments for the quality level
    public func getSegments(for quality: String) async -> [TSSegment] {
        return activeSegments[quality] ?? []
    }
    
    /// Get a specific segment's data with proper headers
    /// - Parameters:
    ///   - quality: Quality level identifier
    ///   - filename: Segment filename
    /// - Returns: Tuple containing the segment data and HTTP headers
    public func getSegmentData(quality: String, filename: String) async throws -> (Data, [String: String]) {
        guard let segments = activeSegments[quality],
              let segment = segments.first(where: { $0.path.contains(filename) })
        else {
            throw HLSError.fileOperationFailed("Segment not found: \(filename)")
        }
        
        let segmentPath = (config.segmentDirectory as NSString).appendingPathComponent(segment.path)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: segmentPath)) else {
            throw HLSError.fileOperationFailed("Failed to read segment data: \(filename)")
        }
        
        // Set appropriate headers for MPEG-TS segments
        let headers = [
            "Content-Type": "video/mp2t",
            "Cache-Control": "no-cache",
            "Access-Control-Allow-Origin": "*",
            "Content-Length": "\(data.count)"
        ]
        
        return (data, headers)
    }
    
    /// Clean up old segments for a specific quality level
    /// - Parameter quality: Quality level identifier
    private func cleanupOldSegments(for quality: String) async {
        guard var segments = activeSegments[quality] else { return }
        
        // Keep only the configured number of segments
        if segments.count > config.maxSegments {
            let segmentsToRemove = segments[0...(segments.count - config.maxSegments - 1)]
            segments = Array(segments.dropFirst(segmentsToRemove.count))
            activeSegments[quality] = segments
            
            // Remove segment files asynchronously
            for segment in segmentsToRemove {
                let segmentPath = (config.segmentDirectory as NSString).appendingPathComponent(segment.path)
                storageQueue.addOperation {
                    try? FileManager.default.removeItem(atPath: segmentPath)
                }
            }
        }
    }
}

/// Configuration for video segment handling
@available(macOS 14.0, *)
public struct VideoSegmentConfig {
    /// Target duration for each segment in seconds
    public let targetSegmentDuration: Double
    
    /// Maximum number of segments to keep per quality level
    public let maxSegments: Int
    
    /// Directory where segments are stored
    public let segmentDirectory: String
    
    public init(targetSegmentDuration: Double = 2.0,
                maxSegments: Int = 5,
                segmentDirectory: String) {
        self.targetSegmentDuration = targetSegmentDuration
        self.maxSegments = maxSegments
        self.segmentDirectory = segmentDirectory
    }
} 