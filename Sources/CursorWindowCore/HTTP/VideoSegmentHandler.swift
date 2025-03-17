import Foundation
import AVFoundation
import NIO

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
    
    /// Cache for segment data to reduce disk I/O
    private var segmentDataCache: [String: CachedSegment]
    
    /// ByteBuffer allocator for efficient memory management
    private let allocator = ByteBufferAllocator()
    
    /// Initializes a new video segment handler
    /// - Parameters:
    ///   - config: Configuration for segment handling
    ///   - segmentWriter: Writer for creating MPEG-TS segments
    public init(config: VideoSegmentConfig, segmentWriter: TSSegmentWriterProtocol) {
        self.config = config
        self.segmentWriter = segmentWriter
        self.activeSegments = [:]
        self.segmentDataCache = [:]
        
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
                
                // Cache the completed segment data
                Task {
                    await cacheSegmentData(segment: segment, quality: quality)
                }
                
                // Clean up old segments if we have too many
                await cleanupOldSegments(for: quality)
            }
        }
    }
    
    /// Cache segment data in memory to avoid repeated disk reads
    /// - Parameters:
    ///   - segment: The segment to cache
    ///   - quality: Quality level identifier
    private func cacheSegmentData(segment: TSSegment, quality: String) async {
        let segmentPath = (config.segmentDirectory as NSString).appendingPathComponent(segment.path)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: segmentPath)) else {
            return
        }
        
        let cacheKey = createCacheKey(quality: quality, filename: segment.path)
        let headers = createSegmentHeaders(data: data)
        
        // Create a ByteBuffer for more efficient memory handling
        var buffer = allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        
        segmentDataCache[cacheKey] = CachedSegment(
            data: buffer,
            headers: headers,
            timestamp: Date(),
            size: data.count
        )
        
        // Manage cache size if it gets too large
        if segmentDataCache.count > config.maxCachedSegments {
            pruneCache()
        }
    }
    
    /// Create standard headers for segment data
    /// - Parameter data: The segment data
    /// - Returns: Dictionary of HTTP headers
    private func createSegmentHeaders(data: Data) -> [String: String] {
        return [
            "Content-Type": "video/mp2t",
            "Cache-Control": "max-age=\(Int(config.targetSegmentDuration * 2))",
            "Access-Control-Allow-Origin": "*",
            "Content-Length": "\(data.count)",
            "X-Content-Duration": "\(config.targetSegmentDuration)",
            "ETag": "\"seg-\(data.hashValue)\"",
            "Accept-Ranges": "bytes"
        ]
    }
    
    /// Create a cache key for a segment
    /// - Parameters:
    ///   - quality: Quality level identifier
    ///   - filename: Segment filename
    /// - Returns: String cache key
    private func createCacheKey(quality: String, filename: String) -> String {
        return "\(quality)_\(filename)"
    }
    
    /// Remove least recently used items from cache
    private func pruneCache() {
        let sortedEntries = segmentDataCache.sorted { $0.value.timestamp < $1.value.timestamp }
        let entriesToRemove = sortedEntries.prefix(sortedEntries.count / 4)
        for entry in entriesToRemove {
            segmentDataCache.removeValue(forKey: entry.key)
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
    ///   - range: Optional byte range for partial content requests
    /// - Returns: Tuple containing the segment data and HTTP headers
    public func getSegmentData(quality: String, filename: String, range: HTTPRange? = nil) async throws -> (Data, [String: String]) {
        // Check cache first
        let cacheKey = createCacheKey(quality: quality, filename: filename)
        if let cachedSegment = segmentDataCache[cacheKey] {
            var headers = cachedSegment.headers
            
            if let range = range {
                return try processRangeRequest(cachedSegment: cachedSegment, range: range, headers: headers)
            }
            
            return (Data(cachedSegment.data.readableBytesView), headers)
        }
        
        // Not in cache, check active segments
        guard let segments = activeSegments[quality],
              let segment = segments.first(where: { $0.path.contains(filename) })
        else {
            throw HLSError.fileOperationFailed("Segment not found: \(filename)")
        }
        
        let segmentPath = (config.segmentDirectory as NSString).appendingPathComponent(segment.path)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: segmentPath)) else {
            throw HLSError.fileOperationFailed("Failed to read segment data: \(filename)")
        }
        
        // Create headers
        let headers = createSegmentHeaders(data: data)
        
        // Handle range request if present
        if let range = range {
            return try processRangeRequest(data: data, range: range, headers: headers)
        }
        
        // Cache for future requests
        var buffer = allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        segmentDataCache[cacheKey] = CachedSegment(
            data: buffer,
            headers: headers,
            timestamp: Date(),
            size: data.count
        )
        
        return (data, headers)
    }
    
    /// Process a range request for partial content
    /// - Parameters:
    ///   - data: Full segment data
    ///   - range: HTTP range specification
    ///   - headers: Original headers to modify
    /// - Returns: Tuple with partial data and updated headers
    private func processRangeRequest(data: Data, range: HTTPRange, headers: [String: String]) throws -> (Data, [String: String]) {
        let totalLength = data.count
        
        // Calculate start and end positions
        let startPos = range.start ?? 0
        let endPos = range.end ?? (totalLength - 1)
        
        // Validate range
        guard startPos < totalLength && endPos >= startPos && endPos < totalLength else {
            throw HLSError.invalidRange
        }
        
        // Extract range data
        let length = endPos - startPos + 1
        let rangeData = data.subdata(in: startPos..<(startPos + length))
        
        // Update headers for partial content
        var rangeHeaders = headers
        rangeHeaders["Content-Length"] = "\(length)"
        rangeHeaders["Content-Range"] = "bytes \(startPos)-\(endPos)/\(totalLength)"
        rangeHeaders["Accept-Ranges"] = "bytes"
        rangeHeaders["Status"] = "206 Partial Content"
        
        return (rangeData, rangeHeaders)
    }
    
    /// Process a range request for cached segment
    /// - Parameters:
    ///   - cachedSegment: Cached segment
    ///   - range: HTTP range specification
    ///   - headers: Original headers to modify
    /// - Returns: Tuple with partial data and updated headers
    private func processRangeRequest(cachedSegment: CachedSegment, range: HTTPRange, headers: [String: String]) throws -> (Data, [String: String]) {
        let totalLength = cachedSegment.size
        
        // Calculate start and end positions
        let startPos = range.start ?? 0
        let endPos = range.end ?? (totalLength - 1)
        
        // Validate range
        guard startPos < totalLength && endPos >= startPos && endPos < totalLength else {
            throw HLSError.invalidRange
        }
        
        // Extract range data
        let readableBytes = cachedSegment.data.readableBytesView
        let length = endPos - startPos + 1
        let rangeData = Data(readableBytes.dropFirst(startPos).prefix(length))
        
        // Update headers for partial content
        var rangeHeaders = headers
        rangeHeaders["Content-Length"] = "\(length)"
        rangeHeaders["Content-Range"] = "bytes \(startPos)-\(endPos)/\(totalLength)"
        rangeHeaders["Accept-Ranges"] = "bytes"
        rangeHeaders["Status"] = "206 Partial Content"
        
        return (rangeData, rangeHeaders)
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
                
                // Also remove from cache
                let cacheKey = createCacheKey(quality: quality, filename: segment.path)
                segmentDataCache.removeValue(forKey: cacheKey)
                
                // Remove file asynchronously
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
    
    /// Maximum number of segments to keep in memory cache
    public let maxCachedSegments: Int
    
    /// Directory where segments are stored
    public let segmentDirectory: String
    
    public init(targetSegmentDuration: Double = 2.0,
                maxSegments: Int = 5,
                maxCachedSegments: Int = 20,
                segmentDirectory: String) {
        self.targetSegmentDuration = targetSegmentDuration
        self.maxSegments = maxSegments
        self.maxCachedSegments = maxCachedSegments
        self.segmentDirectory = segmentDirectory
    }
}

/// Structure for caching segment data in memory
@available(macOS 14.0, *)
private struct CachedSegment {
    /// ByteBuffer containing segment data
    let data: ByteBuffer
    
    /// HTTP headers for the segment
    let headers: [String: String]
    
    /// Timestamp when segment was cached
    let timestamp: Date
    
    /// Size of the segment in bytes
    let size: Int
}

/// HTTP range specification for partial content requests
@available(macOS 14.0, *)
public struct HTTPRange {
    /// Start byte position (nil means start from beginning)
    let start: Int?
    
    /// End byte position (nil means end of file)
    let end: Int?
    
    public init(start: Int?, end: Int?) {
        self.start = start
        self.end = end
    }
    
    /// Parse Range header value into HTTPRange
    /// - Parameter rangeHeader: Range header string (e.g. "bytes=0-499")
    /// - Returns: HTTPRange if valid, nil otherwise
    public static func parse(from rangeHeader: String) -> HTTPRange? {
        let pattern = "bytes=(\\d*)-(\\d*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let range = NSRange(rangeHeader.startIndex..<rangeHeader.endIndex, in: rangeHeader)
        guard let match = regex.firstMatch(in: rangeHeader, range: range) else {
            return nil
        }
        
        let startRange = match.range(at: 1)
        let endRange = match.range(at: 2)
        
        var start: Int?
        var end: Int?
        
        if startRange.location != NSNotFound, let startStr = Range(startRange, in: rangeHeader).map({ String(rangeHeader[$0]) }), !startStr.isEmpty {
            start = Int(startStr)
        }
        
        if endRange.location != NSNotFound, let endStr = Range(endRange, in: rangeHeader).map({ String(rangeHeader[$0]) }), !endStr.isEmpty {
            end = Int(endStr)
        }
        
        return HTTPRange(start: start, end: end)
    }
}

/// HLS error extension to include range errors
@available(macOS 14.0, *)
extension HLSError {
    static let invalidRange = HLSError.custom("Invalid byte range specified")
} 