#if os(macOS)
import Foundation
import AVFoundation

@available(macOS 14.0, *)
public actor HLSManager: HLSManagerProtocol {
    private let configuration: HLSConfiguration
    private let segmentWriter: TSSegmentWriterProtocol
    private let playlistGenerator: PlaylistGeneratorProtocol
    private var isStreaming = false
    private var variants: [HLSVariant] = []
    
    public init(configuration: HLSConfiguration) async throws {
        self.configuration = configuration
        self.segmentWriter = try await TSSegmentWriter(segmentDirectory: configuration.segmentDirectory)
        self.playlistGenerator = M3U8PlaylistGenerator()
    }
    
    public func startStreaming() async throws {
        guard !isStreaming else { return }
        isStreaming = true
    }
    
    public func stopStreaming() async throws {
        guard isStreaming else { return }
        isStreaming = false
        try await segmentWriter.cleanup()
    }
    
    public func processEncodedData(_ data: Data, presentationTime: Double) async throws {
        guard isStreaming else { throw HLSError.streamingNotStarted }
        
        let currentSegment = try await segmentWriter.getCurrentSegment()
        let shouldStart = currentSegment == nil || 
            (presentationTime - (currentSegment?.startTime ?? 0)) >= configuration.targetSegmentDuration
        
        if shouldStart {
            try await segmentWriter.startNewSegment()
            try await cleanupSegments()
        }
        
        try await segmentWriter.writeEncodedData(data, presentationTime: presentationTime)
    }
    
    private func shouldStartNewSegment() async throws -> Bool {
        if let currentSegment = try await segmentWriter.getCurrentSegment() {
            return currentSegment.duration >= configuration.targetSegmentDuration
        }
        return true
    }
    
    public func getCurrentPlaylist() async throws -> String {
        let segments = try await getActiveSegments()
        return try playlistGenerator.generateMediaPlaylist(
            segments: segments,
            targetDuration: Int(configuration.targetSegmentDuration),
            baseURL: configuration.baseURL
        )
    }
    
    private func cleanupSegments() async throws {
        let segments = try await segmentWriter.getSegments()
        let maxSegments = configuration.playlistLength
        
        if segments.count > maxSegments {
            let segmentsToKeep = segments.suffix(maxSegments)
            let segmentsToRemove = segments.prefix(segments.count - maxSegments)
            
            for segment in segmentsToRemove {
                try await segmentWriter.removeSegment(segment)
            }
            
            // Start a new segment if the current one was removed
            if let currentSegment = try await segmentWriter.getCurrentSegment(),
               !segmentsToKeep.contains(where: { $0.id == currentSegment.id }) {
                try await segmentWriter.startNewSegment()
            }
        }
    }
    
    public func getActiveSegments() async throws -> [TSSegment] {
        // Simply return all segments - we manage segment creation in processEncodedData
        return try await segmentWriter.getSegments()
    }
    
    public func cleanupOldSegments() async throws {
        try await cleanupSegments()
    }
    
    public func addVariant(_ variant: HLSVariant) {
        variants.append(variant)
    }
    
    public func removeVariant(_ variant: HLSVariant) {
        variants.removeAll { $0 == variant }
    }
    
    private func generateMasterPlaylist() throws -> String {
        try playlistGenerator.generateMasterPlaylist(
            variants: variants,
            baseURL: configuration.baseURL
        )
    }
    
    public func getMasterPlaylist() throws -> String {
        try generateMasterPlaylist()
    }
    
    public func getEventPlaylist() async throws -> String {
        let segments = try await getActiveSegments()
        return try playlistGenerator.generateEventPlaylist(
            segments: segments,
            targetDuration: Int(configuration.targetSegmentDuration),
            baseURL: configuration.baseURL
        )
    }
    
    public func getVODPlaylist() async throws -> String {
        let segments = try await getActiveSegments()
        return try playlistGenerator.generateVODPlaylist(
            segments: segments,
            targetDuration: Int(configuration.targetSegmentDuration),
            baseURL: configuration.baseURL
        )
    }
}
#endif 