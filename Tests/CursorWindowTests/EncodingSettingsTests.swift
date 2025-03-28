import XCTest
@testable import CursorWindowCore
@testable import CursorWindow

@MainActor
final class EncodingSettingsTests: XCTestCase {
    var settings: EncodingSettings!
    
    override func setUp() async throws {
        settings = EncodingSettings()
    }
    
    override func tearDown() async throws {
        settings = nil
    }
    
    func testDefaultValues() throws {
        // The actual implementation uses NSHomeDirectory() + "/Desktop/output.mov"
        // so we can't test for exact equality with a hardcoded value
        XCTAssertTrue(settings.outputPath.hasSuffix("/Desktop/output.mov"), "Output path should end with /Desktop/output.mov")
        XCTAssertEqual(settings.width, 1920)
        XCTAssertEqual(settings.height, 1080)
        XCTAssertEqual(settings.frameRate, 30.0)
        XCTAssertEqual(settings.quality, 0.8)
    }
    
    func testCustomInitialization() throws {
        let customSettings = EncodingSettings(
            outputPath: "/custom/path.mov",
            width: 1920,
            height: 1080,
            frameRate: 60.0,
            quality: 0.9
        )
        
        XCTAssertEqual(customSettings.outputPath, "/custom/path.mov")
        XCTAssertEqual(customSettings.width, 1920)
        XCTAssertEqual(customSettings.height, 1080)
        XCTAssertEqual(customSettings.frameRate, 60.0)
        XCTAssertEqual(customSettings.quality, 0.9)
    }
    
    func testAtomicUpdates() async throws {
        await settings.apply(.outputPath("/new/path.mov"))
        await settings.apply(.width(1280))
        await settings.apply(.height(720))
        await settings.apply(.frameRate(24.0))
        await settings.apply(.quality(0.7))
        
        XCTAssertEqual(settings.outputPath, "/new/path.mov")
        XCTAssertEqual(settings.width, 1280)
        XCTAssertEqual(settings.height, 720)
        XCTAssertEqual(settings.frameRate, 24.0)
        XCTAssertEqual(settings.quality, 0.7)
    }
    
    func testPartialUpdates() async throws {
        let originalWidth = settings.width
        let originalHeight = settings.height
        
        await settings.apply(.outputPath("/partial/update.mov"))
        await settings.apply(.frameRate(50.0))
        
        XCTAssertEqual(settings.outputPath, "/partial/update.mov")
        XCTAssertEqual(settings.width, originalWidth)
        XCTAssertEqual(settings.height, originalHeight)
        XCTAssertEqual(settings.frameRate, 50.0)
        XCTAssertEqual(settings.quality, 0.8)
    }
}

@MainActor
final class EncodingSettingsIntegrationTests: XCTestCase {
    var settings: EncodingSettings!
    var encoder: H264VideoEncoder!
    
    override func setUp() async throws {
        settings = EncodingSettings()
        encoder = try await H264VideoEncoder(viewportSize: ViewportSize(width: 1920, height: 1080))
    }
    
    override func tearDown() async throws {
        settings = nil
        try? await encoder.stopEncoding()
        encoder = nil
    }
    
    func testEncoderConfigurationWithSettings() async throws {
        // Configure custom settings
        await settings.apply(.width(1280))
        await settings.apply(.height(720))
        await settings.apply(.frameRate(30.0))
        
        // Start encoding with these settings
        try await encoder.startEncoding(to: URL(fileURLWithPath: settings.outputPath),
                                      width: settings.width,
                                      height: settings.height)
        
        // Verify encoder state
        let isEncoding = await encoder.isEncoding
        XCTAssertTrue(isEncoding)
        
        // Stop encoding
        await encoder.stopEncoding()
        let stoppedEncoding = await encoder.isEncoding
        XCTAssertFalse(stoppedEncoding)
    }
} 