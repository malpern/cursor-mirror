#if os(macOS)
import Foundation
import AVFoundation

@available(macOS 14.0, *)
actor HLSManager: HLSManagerProtocol {
    private let configuration: HLSConfiguration
    private let segmentWriter: TSSegmentWriter
    private let playlistGenerator: PlaylistGenerator
    
    private var isStreaming = false
    private var currentSegmentStartTime: CMTime?
    private var segments: [HLSSegment] = []
    private var variants: [HLSVariant] = []
    
    init(configuration: HLSConfiguration) async throws {
        self.configuration = configuration
        self.segmentWriter = try await TSSegmentWriter(segmentDirectory: configuration.segmentDirectory)
        self.playlistGenerator = M3U8PlaylistGenerator()
    }
    
    func startStreaming() async throws {
        isStreaming = true
        segments.removeAll()
    }
    
    func stopStreaming() async throws {
        isStreaming = false
        try await segmentWriter.cleanup()
        segments.removeAll()
    }
    
    func processEncodedData(_ data: Data, presentationTime: CMTime) async throws {
        guard isStreaming else {
            throw HLSError.streamingNotStarted
        }
        
        if try await shouldStartNewSegment(at: presentationTime) {
            let segment = try await segmentWriter.startNewSegment(startTime: presentationTime)
            segments.append(segment)
            currentSegmentStartTime = presentationTime
            
            // Remove old segments if we exceed the playlist length
            if segments.count > configuration.playlistLength {
                segments.removeFirst()
            }
        }
        
        try await segmentWriter.writeEncodedData(data)
    }
    
    func getCurrentPlaylist() async throws -> String {
        guard isStreaming else {
            throw HLSError.streamingNotStarted
        }
        
        return playlistGenerator.generateMediaPlaylist(segments: segments, configuration: configuration)
    }
    
    private func shouldStartNewSegment(at time: CMTime) async throws -> Bool {
        guard let currentStartTime = currentSegmentStartTime else {
            return true
        }
        
        if let currentSegment = try? await segmentWriter.finishCurrentSegment() {
            if let index = segments.firstIndex(where: { $0.id == currentSegment.id }) {
                segments[index] = currentSegment
            }
        }
        
        let duration = time.seconds - currentStartTime.seconds
        return duration >= configuration.targetSegmentDuration
    }
    
    func getActiveSegments() async -> [HLSSegment] {
        return segments
    }
    
    func cleanupOldSegments() async throws {
        // Keep only the most recent segments based on playlist length
        if segments.count > configuration.playlistLength {
            segments.removeFirst(segments.count - configuration.playlistLength)
        }
    }
    
    func addVariant(_ variant: HLSVariant) async {
        variants.append(variant)
    }
    
    func removeVariant(_ variant: HLSVariant) async {
        if let index = variants.firstIndex(where: { 
            $0.bandwidth == variant.bandwidth &&
            $0.width == variant.width &&
            $0.height == variant.height &&
            $0.frameRate == variant.frameRate &&
            $0.playlistPath == variant.playlistPath
        }) {
            variants.remove(at: index)
        }
    }
    
    func getMasterPlaylist() async -> String {
        return playlistGenerator.generateMasterPlaylist(variants: variants)
    }
    
    func getEventPlaylist() async -> String {
        return playlistGenerator.generateEventPlaylist(
            segments: segments,
            configuration: configuration
        )
    }
    
    func getVODPlaylist() async -> String {
        return playlistGenerator.generateVODPlaylist(
            segments: segments,
            configuration: configuration
        )
    }
}
#endif 