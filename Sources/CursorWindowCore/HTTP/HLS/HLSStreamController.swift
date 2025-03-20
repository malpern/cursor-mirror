import Foundation
import Vapor
import os.log

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
                throw Abort(.internalServerError)
            }
            
            // Check if streaming is enabled
            guard await self.streamManager.isStreaming else {
                throw Abort(.serviceUnavailable, reason: "Streaming is not currently active")
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
                throw Abort(.internalServerError)
            }
            
            // Check if streaming is enabled
            guard await self.streamManager.isStreaming else {
                throw Abort(.serviceUnavailable, reason: "Streaming is not currently active")
            }
            
            // Get quality from parameters
            guard let qualityName = req.parameters.get("quality") else {
                throw Abort(.badRequest, reason: "Missing quality parameter")
            }
            
            // Find matching quality
            guard let quality = StreamQuality(rawValue: qualityName) else {
                throw Abort(.badRequest, reason: "Invalid quality: \(qualityName)")
            }
            
            // Get segments
            let segments = await self.segmentManager.getSegments(for: quality)
            
            if segments.isEmpty {
                throw Abort(.notFound, reason: "No segments available for quality: \(qualityName)")
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
                throw Abort(.internalServerError)
            }
            
            // Check if streaming is enabled
            guard await self.streamManager.isStreaming else {
                throw Abort(.serviceUnavailable, reason: "Streaming is not currently active")
            }
            
            // Get quality and segment from parameters
            guard let qualityName = req.parameters.get("quality"),
                  let segmentName = req.parameters.get("segment") else {
                throw Abort(.badRequest, reason: "Missing parameters")
            }
            
            // Convert string to quality enum
            guard let quality = StreamQuality(rawValue: qualityName) else {
                throw Abort(.badRequest, reason: "Invalid quality: \(qualityName)")
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
                throw Abort(.notFound, reason: "Segment not found: \(segmentName)")
            }
        }
    }
} 