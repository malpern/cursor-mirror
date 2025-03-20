import XCTest
import XCTVapor
@preconcurrency @testable import CursorWindowCore
import NIOHTTP1
import Logging

/* Temporarily disabled due to XCTVapor dependency issues
@available(macOS 14.0, *)
@MainActor
final class HLSIntegrationTests: XCTestCase, @unchecked Sendable {
    private var vaporHelper: VaporTestHelper!
    var serverManager: HTTPServerManager!
    var streamManager: HLSStreamManager!
    var playlistGenerator: HLSPlaylistGenerator!
    var segmentHandler: VideoSegmentHandler!
    var tempDirectory: URL!
    private var accessTokens: Set<UUID>!
    var segmentsDirectory: URL!
    private var logger = Logger(label: "test.hls.integration")
    
    // Define quality options for testing
    let qualities: [HLSQualityOption] = [
        HLSQualityOption(id: "high", width: 1920, height: 1080, bitrate: 5_000_000, codecs: "avc1.640028"),
        HLSQualityOption(id: "medium", width: 1280, height: 720, bitrate: 2_500_000, codecs: "avc1.4d401f"),
        HLSQualityOption(id: "low", width: 854, height: 480, bitrate: 1_000_000, codecs: "avc1.4d401e")
    ]
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary directories
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        segmentsDirectory = tempDirectory.appendingPathComponent("segments")
        try FileManager.default.createDirectory(at: segmentsDirectory, withIntermediateDirectories: true)
        
        // Create a test segment file
        let testSegmentData = Data([0x47, 0x40, 0x00, 0x10]) // Basic MPEG-TS packet header
        try testSegmentData.write(to: segmentsDirectory.appendingPathComponent("segment_0.ts"))
        
        // Initialize the Vapor helper
        vaporHelper = try await VaporTestHelper(
            environment: .testing,
            hostname: "localhost",
            port: 8080,
            logLevel: .debug
        )
        
        // Configure content types
        vaporHelper.configureHLSContentTypes()
        
        // Set up test data
        accessTokens = []
        
        // Initialize components
        serverManager = HTTPServerManager()
        streamManager = HLSStreamManager()
        playlistGenerator = HLSPlaylistGenerator(baseURL: "http://localhost:8080/stream", qualities: qualities)
        segmentHandler = try await VideoSegmentHandler(config: VideoSegmentConfig(
            targetSegmentDuration: 2.0,
            maxSegments: 5,
            segmentDirectory: tempDirectory.path
        ), segmentWriter: TSSegmentWriter(segmentDirectory: tempDirectory.path))
        
        // Configure routes
        try await configureRoutes(vaporHelper.app)
        
        // Start the server
        try await vaporHelper.startServer()
        logger.debug("Test setup completed successfully")
    }
    
    override func tearDown() async throws {
        logger.debug("Beginning tearDown process")
        
        // Shutdown Vapor
        if let helper = vaporHelper {
            try await helper.shutdown()
        }
        
        // Clean up resources
        if let directory = tempDirectory, FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
            logger.debug("Temporary files cleaned up")
        }
        
        // Reset properties
        vaporHelper = nil
        accessTokens = nil
        
        logger.debug("tearDown complete")
        try await super.tearDown()
    }
    
    private func configureRoutes(_ app: Application) async throws {
        app.get("stream", "master.m3u8") { [weak self] req async throws -> Response in
            guard let self = self else { throw Abort(.internalServerError) }
            
            // Generate access token
            let accessToken = UUID()
            _ = await MainActor.run {
                self.accessTokens.insert(accessToken)
            }
            
            // Return master playlist
            let playlist = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
            media.m3u8?token=\(accessToken)
            """
            
            return Response(
                status: .ok,
                headers: ["Content-Type": "application/vnd.apple.mpegurl"],
                body: .init(string: playlist)
            )
        }
        
        app.get("stream", "media.m3u8") { [weak self] req async throws -> Response in
            guard let self = self else { throw Abort(.internalServerError) }
            
            // Validate access token
            guard let tokenString = req.query[String.self, at: "token"],
                  let token = UUID(uuidString: tokenString) else {
                throw Abort(.unauthorized)
            }
            
            let isValid = await MainActor.run {
                self.accessTokens.contains(token)
            }
            
            guard isValid else {
                throw Abort(.unauthorized)
            }
            
            // Return media playlist
            let playlist = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:10
            #EXT-X-MEDIA-SEQUENCE:0
            #EXTINF:10.0,
            segments/segment_0.ts?token=\(token)
            #EXT-X-ENDLIST
            """
            
            return Response(
                status: .ok,
                headers: ["Content-Type": "application/vnd.apple.mpegurl"],
                body: .init(string: playlist)
            )
        }
        
        app.get("stream", "segments", "**") { [weak self] req async throws -> Response in
            guard let self = self else { throw Abort(.internalServerError) }
            
            // Validate access token
            guard let tokenString = req.query[String.self, at: "token"],
                  let token = UUID(uuidString: tokenString) else {
                throw Abort(.unauthorized)
            }
            
            let isValid = await MainActor.run {
                self.accessTokens.contains(token)
            }
            
            guard isValid else {
                throw Abort(.unauthorized)
            }
            
            // Get segment path
            let segmentPath = req.parameters.getCatchall().joined(separator: "/")
            let segmentURL = await MainActor.run {
                self.segmentsDirectory.appendingPathComponent(segmentPath)
            }
            
            // Return segment data
            guard let segmentData = try? Data(contentsOf: segmentURL) else {
                throw Abort(.internalServerError, reason: "Segment not found: \(segmentPath)")
            }
            
            return Response(
                status: .ok,
                headers: ["Content-Type": "video/mp2t"],
                body: .init(data: segmentData)
            )
        }
    }
    
    func testCompleteStreamingFlow() async throws {
        // Get master playlist
        let masterResponse = try await vaporHelper.app.client.get("http://localhost:8080/stream/master.m3u8")
        XCTAssertEqual(masterResponse.status.code, 200)
        
        // Extract token from master playlist
        let masterPlaylist = try masterResponse.content.decode(String.self)
        let tokenRegex = try NSRegularExpression(pattern: "token=([^\\s]+)")
        guard let match = tokenRegex.firstMatch(in: masterPlaylist, range: NSRange(masterPlaylist.startIndex..., in: masterPlaylist)),
              let tokenRange = Range(match.range(at: 1), in: masterPlaylist) else {
            XCTFail("Could not extract token from master playlist")
            return
        }
        let token = String(masterPlaylist[tokenRange])
        
        // Get media playlist
        let mediaResponse = try await vaporHelper.app.client.get("http://localhost:8080/stream/media.m3u8?token=\(token)")
        XCTAssertEqual(mediaResponse.status.code, 200)
        
        // Get segment
        let segmentResponse = try await vaporHelper.app.client.get("http://localhost:8080/stream/segments/segment_0.ts?token=\(token)")
        XCTAssertEqual(segmentResponse.status.code, 200)
    }
    
    func testSimpleHLSSetup() async throws {
        // Create a temporary directory for the test
        let tempDir = try vaporHelper.createTempDirectory()
        
        // Create a test segment file
        let segmentsDir = tempDir.appendingPathComponent("segments")
        try FileManager.default.createDirectory(at: segmentsDir, withIntermediateDirectories: true)
        let testSegment = segmentsDir.appendingPathComponent("segment_0.ts")
        let testData = Data([0x47, 0x40, 0x00, 0x10]) // Basic MPEG-TS packet header
        try testData.write(to: testSegment)
        
        // Create a separate Vapor helper for this test with a different port
        let localHelper = try await VaporTestHelper(
            hostname: "localhost",
            port: 8181, // Use a different port to avoid conflicts
            logLevel: .debug
        )
        
        // Configure HLS content types
        localHelper.configureHLSContentTypes()
        
        // Add a reference token for authentication
        let testToken = UUID()
        
        // Set up segments directory for the localHelper
        localHelper.app.middleware.use(FileMiddleware(publicDirectory: segmentsDir.path))
        
        // Simple endpoint
        localHelper.app.get("stream", "playlist.m3u8") { req -> String in
            return """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:10
            #EXT-X-MEDIA-SEQUENCE:0
            #EXTINF:10.0,
            segments/segment_0.ts?token=\(testToken)
            #EXT-X-ENDLIST
            """
        }
        
        // Segments endpoint with token validation
        localHelper.app.get("segments", "segment_0.ts") { req -> Response in
            // Allow access with the correct token
            guard let tokenParam = req.query[String.self, at: "token"],
                  let reqToken = UUID(uuidString: tokenParam),
                  reqToken == testToken else {
                throw Abort(.unauthorized)
            }
            
            // Read segment file and return as response
            let segmentData = try Data(contentsOf: testSegment)
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "video/mp2t")
            
            return Response(
                status: .ok,
                headers: headers,
                body: .init(data: segmentData)
            )
        }
        
        do {
            // Start the server
            try await localHelper.startServer()
            
            // Test that we can get the playlist
            let playlistResponse = try await localHelper.app.client.get("http://localhost:8181/stream/playlist.m3u8")
            XCTAssertEqual(playlistResponse.status.code, 200)
            
            // Test that we can get the segment with the token
            let segmentResponse = try await localHelper.app.client.get("http://localhost:8181/segments/segment_0.ts?token=\(testToken)")
            XCTAssertEqual(segmentResponse.status.code, 200)
            XCTAssertEqual(segmentResponse.headers.first(name: "Content-Type"), "video/mp2t")
            
            // The segment should contain our test data
            let responseData = Data(buffer: segmentResponse.body!)
            XCTAssertEqual(responseData, testData)
        } catch {
            // If any test fails, still ensure shutdown
            try? await localHelper.shutdown()
            try? vaporHelper.removeDirectory(tempDir)
            throw error
        }
        
        // Always clean up resources, even if tests pass
        try await localHelper.shutdown()
        try vaporHelper.removeDirectory(tempDir)
    }
}

struct AccessResponse: Content {
    let token: String
}

extension ByteBuffer {
    func getString(at offset: Int, length: Int) throws -> String {
        guard let string = getString(at: offset, length: length) else {
            throw Abort(.internalServerError, reason: "Could not read string from buffer")
        }
        return string
    }
    
    func getData(at offset: Int, length: Int) throws -> Data {
        guard let data = getBytes(at: offset, length: length) else {
            throw Abort(.internalServerError, reason: "Could not read data from buffer")
        }
        return Data(data)
    }
}
*/ 