import Foundation
import Vapor
import os.log

/// Errors that can occur in the HLS streaming controller
public enum HLSStreamError: AbortError, CustomStringConvertible {
    /// Streaming is not active
    case streamingNotActive
    
    /// Invalid quality parameter
    case invalidQuality(String)
    
    /// No segments available for quality
    case noSegmentsAvailable(StreamQuality)
    
    /// Segment not found
    case segmentNotFound(String, StreamQuality)
    
    /// Missing required parameter
    case missingParameter(String)
    
    /// Controller has been deallocated
    case controllerDeallocated
    
    /// The HTTP status code
    public var status: HTTPResponseStatus {
        switch self {
        case .streamingNotActive:
            return .serviceUnavailable
        case .invalidQuality, .missingParameter:
            return .badRequest
        case .noSegmentsAvailable, .segmentNotFound:
            return .notFound
        case .controllerDeallocated:
            return .internalServerError
        }
    }
    
    /// Human-readable description of the error
    public var description: String {
        switch self {
        case .streamingNotActive:
            return "Streaming is not currently active"
        case .invalidQuality(let quality):
            return "Invalid quality parameter: \(quality)"
        case .noSegmentsAvailable(let quality):
            return "No segments available for quality: \(quality.rawValue)"
        case .segmentNotFound(let segment, let quality):
            return "Segment not found: \(segment) for quality \(quality.rawValue)"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .controllerDeallocated:
            return "HLS stream controller has been deallocated"
        }
    }
    
    /// Error reason shown to the client
    public var reason: String {
        return description
    }
}

/// Controller for HLS streaming endpoints
public actor HLSStreamController {
    /// Playlist generator
    private let playlistGenerator: HLSPlaylistGenerator
    
    /// Segment manager
    private let segmentManager: HLSSegmentManager
    
    /// Stream manager
    private let streamManager: HLSStreamManager
    
    /// Logger
    private let logger = Logger(subsystem: "com.cursor-window", category: "HLSStreamController")
    
    /// Initialize with dependencies
    /// - Parameters:
    ///   - playlistGenerator: Playlist generator
    ///   - segmentManager: Segment manager
    ///   - streamManager: Stream manager
    public init(
        playlistGenerator: HLSPlaylistGenerator,
        segmentManager: HLSSegmentManager,
        streamManager: HLSStreamManager
    ) {
        self.playlistGenerator = playlistGenerator
        self.segmentManager = segmentManager
        self.streamManager = streamManager
    }
    
    /// Setup routes
    /// - Parameter routes: Route builder
    public func setupRoutes(_ routes: RoutesBuilder) {
        // Master playlist route
        routes.get("stream", "master.m3u8") { [weak self] req async throws -> Response in
            guard let self = self else {
                throw HLSStreamError.controllerDeallocated
            }
            
            // Check if streaming is enabled
            guard await self.streamManager.isStreaming else {
                throw HLSStreamError.streamingNotActive
            }
            
            // Generate master playlist
            let playlist = await self.playlistGenerator.generateMasterPlaylist()
            
            // Create response
            let response = Response(status: .ok)
            response.headers.contentType = HTTPMediaType(type: "application", subType: "vnd.apple.mpegurl")
            response.body = Response.Body(string: playlist)
            
            return response
        }
        
        // Media playlist route
        routes.get("stream", ":quality", "index.m3u8") { [weak self] req async throws -> Response in
            guard let self = self else {
                throw HLSStreamError.controllerDeallocated
            }
            
            // Check if streaming is enabled
            guard await self.streamManager.isStreaming else {
                throw HLSStreamError.streamingNotActive
            }
            
            // Get quality from parameters
            guard let qualityName = req.parameters.get("quality") else {
                throw HLSStreamError.missingParameter("quality")
            }
            
            // Find matching quality
            guard let quality = StreamQuality(rawValue: qualityName) else {
                throw HLSStreamError.invalidQuality(qualityName)
            }
            
            // Get segments
            let segments = await self.segmentManager.getSegments(for: quality)
            
            if segments.isEmpty {
                throw HLSStreamError.noSegmentsAvailable(quality)
            }
            
            // Generate media playlist
            let playlist = await self.playlistGenerator.generateMediaPlaylist(
                quality: quality,
                segments: segments
            )
            
            // Create response
            let response = Response(status: .ok)
            response.headers.contentType = HTTPMediaType(type: "application", subType: "vnd.apple.mpegurl")
            response.body = Response.Body(string: playlist)
            
            return response
        }
        
        // Segment route
        routes.get("stream", ":quality", ":segment") { [weak self] req async throws -> Response in
            guard let self = self else {
                throw HLSStreamError.controllerDeallocated
            }
            
            // Check if streaming is enabled
            guard await self.streamManager.isStreaming else {
                throw HLSStreamError.streamingNotActive
            }
            
            // Get quality and segment from parameters
            guard let qualityName = req.parameters.get("quality") else {
                throw HLSStreamError.missingParameter("quality")
            }
            
            guard let segmentName = req.parameters.get("segment") else {
                throw HLSStreamError.missingParameter("segment")
            }
            
            // Convert string to quality enum
            guard let quality = StreamQuality(rawValue: qualityName) else {
                throw HLSStreamError.invalidQuality(qualityName)
            }
            
            // Update stream manager to prevent timeout
            await self.streamManager.updateActivity()
            
            // Get segment data
            do {
                let segmentData = try await self.segmentManager.getSegmentData(fileName: segmentName, quality: quality)
                
                // Create response
                let response = Response(status: .ok)
                response.headers.contentType = HTTPMediaType(type: "video", subType: "MP2T")
                response.body = Response.Body(data: segmentData)
                
                return response
            } catch {
                logger.error("Failed to get segment data: \(error.localizedDescription)")
                throw HLSStreamError.segmentNotFound(segmentName, quality)
            }
        }
    }
} 