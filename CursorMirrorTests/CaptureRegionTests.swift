import XCTest
import ScreenCaptureKit
@testable import cursor_window

@MainActor
final class CaptureRegionTests: XCTestCase {
    var captureRegion: CaptureRegion!
    
    override func setUp() async throws {
        try await super.setUp()
        captureRegion = CaptureRegion()
    }
    
    override func tearDown() async throws {
        captureRegion = nil
        try await super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(captureRegion.region, .zero)
        XCTAssertNil(captureRegion.display)
        XCTAssertEqual(captureRegion.scaleFactor, 1.0)
    }
    
    func testUpdateRegion() {
        let newRegion = CGRect(x: 100, y: 100, width: 200, height: 200)
        captureRegion.updateRegion(newRegion: newRegion)
        XCTAssertEqual(captureRegion.region, newRegion)
    }
    
    func testRegionValidation() async throws {
        // Create a mock display
        let displayConfig = DisplayConfiguration()
        try await displayConfig.updateDisplays()
        
        guard let display = displayConfig.displays.first else {
            XCTFail("No display available for testing")
            return
        }
        
        // Set the display
        captureRegion.updateDisplay(display: display)
        
        // Try to set a region larger than the display
        let oversizedRegion = CGRect(x: -100, y: -100, width: display.width + 200, height: display.height + 200)
        captureRegion.updateRegion(newRegion: oversizedRegion)
        
        // The region should be clipped to the display bounds
        let expectedRegion = CGRect(x: 0, y: 0, width: display.width, height: display.height)
        XCTAssertEqual(captureRegion.region, expectedRegion)
    }
    
    func testRegionInScreenCoordinates() {
        // Create a mock display with a non-zero origin
        let mockDisplay = TestMockDisplay(
            width: 1000,
            height: 800,
            frame: CGRect(x: 100, y: 200, width: 1000, height: 800)
        )
        
        // Set the display
        captureRegion.updateDisplay(display: mockDisplay)
        
        // Set a region
        let region = CGRect(x: 50, y: 50, width: 200, height: 200)
        captureRegion.updateRegion(newRegion: region)
        
        // Get the region in screen coordinates
        let screenRegion = captureRegion.regionInScreenCoordinates()
        
        // The screen region should be offset by the display origin
        let expectedRegion = CGRect(x: 150, y: 250, width: 200, height: 200)
        XCTAssertEqual(screenRegion, expectedRegion)
    }
    
    func testCreateFilter() {
        // Create a mock display
        let mockDisplay = TestMockDisplay(
            width: 1000,
            height: 800,
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )
        
        // Set the display
        captureRegion.updateDisplay(display: mockDisplay)
        
        // Set a region
        let region = CGRect(x: 50, y: 50, width: 200, height: 200)
        captureRegion.updateRegion(newRegion: region)
        
        // Create a filter
        let filter = captureRegion.createFilter()
        
        // The filter should not be nil
        XCTAssertNotNil(filter)
    }
}

// Mock SCDisplay for testing
class TestMockDisplay: SCDisplay {
    let mockWidth: Int
    let mockHeight: Int
    let mockFrame: CGRect
    
    init(width: Int, height: Int, frame: CGRect) {
        self.mockWidth = width
        self.mockHeight = height
        self.mockFrame = frame
        super.init()
    }
    
    override var width: Int {
        return mockWidth
    }
    
    override var height: Int {
        return mockHeight
    }
    
    override var frame: CGRect {
        return mockFrame
    }
} 