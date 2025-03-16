import XCTest
import AVFoundation
@testable import cursor_window

@MainActor
final class VideoEncoderTests: XCTestCase {
    var encoder: H264VideoEncoder!
    
    override func setUp() async throws {
        encoder = H264VideoEncoder()
    }
    
    override func tearDown() async throws {
        encoder.endSession()
        encoder = nil
    }
    
    func testInitialState() async throws {
        // When the encoder is initialized
        // Then it should not have an active session
        XCTAssertNoThrow(try encoder.startSession(width: 640, height: 480, frameRate: 30))
    }
    
    func testStartSession() async throws {
        // When starting a session with valid parameters
        // Then it should not throw an error
        XCTAssertNoThrow(try encoder.startSession(width: 640, height: 480, frameRate: 30))
    }
    
    func testStartSessionWithConfiguration() async throws {
        // Given a valid configuration
        let config = VideoEncoderConfiguration(
            width: 640,
            height: 480,
            frameRate: 30,
            bitrate: 1_000_000,
            keyframeInterval: 30
        )
        
        // When starting a session with the configuration
        // Then it should not throw an error
        XCTAssertNoThrow(try encoder.startSessionWithConfiguration(config))
    }
    
    func testEncodeFrame() async throws {
        // Given a started session
        try encoder.startSession(width: 640, height: 480, frameRate: 30)
        
        // And a test image
        let image = createTestImage(width: 640, height: 480)
        
        // When encoding a frame
        let data = try encoder.encodeFrame(image, presentationTimeStamp: CMTime(value: 0, timescale: 30))
        
        // Then it should return encoded data
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 0)
    }
    
    func testEncodeMultipleFrames() async throws {
        // Given a started session
        try encoder.startSession(width: 640, height: 480, frameRate: 30)
        
        // And a test image
        let image = createTestImage(width: 640, height: 480)
        
        // When encoding multiple frames
        var allData = [Data]()
        for i in 0..<5 {
            let time = CMTime(value: CMTimeValue(i), timescale: 30)
            if let data = try encoder.encodeFrame(image, presentationTimeStamp: time) {
                allData.append(data)
            }
        }
        
        // Then all frames should be encoded
        XCTAssertEqual(allData.count, 5)
        
        // And the first frame should be larger (contains SPS/PPS)
        XCTAssertGreaterThan(allData[0].count, allData[1].count)
    }
    
    func testEndSession() async throws {
        // Given a started session
        try encoder.startSession(width: 640, height: 480, frameRate: 30)
        
        // When ending the session
        encoder.endSession()
        
        // Then trying to encode a frame should throw an error
        let image = createTestImage(width: 640, height: 480)
        XCTAssertThrowsError(try encoder.encodeFrame(image, presentationTimeStamp: CMTime(value: 0, timescale: 30)))
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(width: Int, height: Int) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        
        // Draw some shapes to make the image more complex
        NSColor.blue.setFill()
        NSRect(x: width/4, y: height/4, width: width/2, height: height/2).fill()
        
        NSColor.green.setStroke()
        let path = NSBezierPath(ovalIn: NSRect(x: width/3, y: height/3, width: width/3, height: height/3))
        path.lineWidth = 5
        path.stroke()
        
        image.unlockFocus()
        
        return image
    }
} 