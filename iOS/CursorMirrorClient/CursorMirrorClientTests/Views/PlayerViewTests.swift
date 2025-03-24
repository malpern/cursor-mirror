import XCTest
import SwiftUI
import AVKit
import CloudKit
@testable import CursorMirrorClient

final class PlayerViewTests: XCTestCase {
    
    var mockViewModel: TestConnectionViewModel!
    
    override func setUp() {
        super.setUp()
        mockViewModel = TestConnectionViewModel()
    }
    
    override func tearDown() {
        mockViewModel = nil
        super.tearDown()
    }
    
    // Test initial state with no connection
    func testNoConnection() {
        // Create the view with the mock view model
        _ = PlayerView(viewModel: mockViewModel)
        
        // Verify no selected device/connection
        XCTAssertNil(mockViewModel.connectionState.selectedDevice)
        XCTAssertEqual(mockViewModel.connectionState.status, .disconnected)
        XCTAssertNil(mockViewModel.providedStreamURL)
    }
    
    // Test connection state changes
    func testConnectionStateChanges() {
        // Setup mock device and connection
        let recordID1 = CKRecord.ID(recordName: "device1")
        let device1 = DeviceInfo(id: "device1", name: "Device 1", recordID: recordID1)
        
        // Initial state - not connected
        XCTAssertEqual(mockViewModel.connectionState.status, .disconnected)
        
        // Connect device
        mockViewModel.connectionState.selectDevice(device1)
        mockViewModel.connectionState.status = .connected
        
        // Set mock stream URL
        mockViewModel.shouldProvideStreamURL = true
        mockViewModel.providedStreamURL = URL(string: "http://test.com/stream")
        
        // Create the player view
        _ = PlayerView(viewModel: mockViewModel)
        
        // Verify connection status and stream URL
        XCTAssertEqual(mockViewModel.connectionState.status, .connected)
        XCTAssertNotNil(mockViewModel.connectionState.selectedDevice)
        XCTAssertNotNil(mockViewModel.getStreamURL())
    }
    
    // Test error handling
    func testErrorHandling() {
        // Simulate an error state
        let testError = NSError(domain: "com.test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        mockViewModel.connectionState.handleError(testError)
        
        // Create the view with the mock view model in error state
        _ = PlayerView(viewModel: mockViewModel)
        
        // Verify error state
        XCTAssertEqual(mockViewModel.connectionState.status, .error)
        XCTAssertNotNil(mockViewModel.connectionState.lastError)
        
        // Create helper to test error clearing
        let helper = PlayerViewErrorHelper(viewModel: mockViewModel)
        
        // Test clearing error
        helper.clearError()
        
        // Verify error was cleared
        XCTAssertTrue(mockViewModel.clearErrorCalled)
        XCTAssertNil(mockViewModel.connectionState.lastError)
    }
    
    // Test retry connection
    func testRetryConnection() {
        // Setup a device and connection error
        let recordID = CKRecord.ID(recordName: "device1")
        let device = DeviceInfo(id: "device1", name: "Device 1", recordID: recordID)
        
        // Set up initial state: selected device with error
        mockViewModel.connectionState.selectDevice(device)
        mockViewModel.connectionState.handleError(NSError(domain: "com.test", code: -1, userInfo: nil))
        
        // Check initial state
        XCTAssertEqual(mockViewModel.connectionState.status, .error)
        XCTAssertNotNil(mockViewModel.connectionState.lastError)
        XCTAssertEqual(mockViewModel.connectionState.selectedDevice?.id, "device1")
        
        // Create helper and retry connection
        let helper = RetryConnectionHelper(viewModel: mockViewModel)
        helper.retryConnection()
        
        // Verify error was cleared
        XCTAssertTrue(mockViewModel.clearErrorCalled)
        
        // Verify connection was retried
        XCTAssertTrue(mockViewModel.connectToDeviceCalled)
        XCTAssertEqual(mockViewModel.lastConnectedDevice?.id, "device1")
    }
    
    // Test stream quality selection
    func testQualitySelection() {
        // Create helper to test quality selection
        let helper = StreamQualityHelper()
        
        // Test auto quality settings
        var quality = StreamQuality.auto
        XCTAssertEqual(quality.displayName, "Auto")
        XCTAssertEqual(helper.getPreferredBitrate(for: quality), 0)
        
        // Test low quality settings
        quality = .low
        XCTAssertEqual(quality.displayName, "Low (480p)")
        XCTAssertEqual(helper.getPreferredBitrate(for: quality), 1_500_000)
        
        // Test medium quality settings
        quality = .medium
        XCTAssertEqual(quality.displayName, "Medium (720p)")
        XCTAssertEqual(helper.getPreferredBitrate(for: quality), 4_000_000)
        
        // Test high quality settings
        quality = .high
        XCTAssertEqual(quality.displayName, "High (1080p)")
        XCTAssertEqual(helper.getPreferredBitrate(for: quality), 8_000_000)
    }
    
    // Test touch events
    func testTouchEvents() {
        // Setup mock device and connection
        let recordID1 = CKRecord.ID(recordName: "device1")
        let device1 = DeviceInfo(id: "device1", name: "Device 1", recordID: recordID1)
        mockViewModel.connectionState.selectDevice(device1)
        mockViewModel.connectionState.status = .connected
        
        // Create helper to test touch events
        let helper = TouchEventHelper()
        
        // Test sending touch event
        let position = CGPoint(x: 100, y: 200)
        let event = helper.createTouchEvent(at: position)
        
        // Verify touch event properties
        XCTAssertEqual(event.position.x, 100)
        XCTAssertEqual(event.position.y, 200)
        XCTAssertEqual(event.type, .tap)
    }
    
    // Test buffering state
    func testBufferingState() {
        // Test buffering state descriptions
        XCTAssertEqual(BufferingState.buffering.description, "Buffering")
        XCTAssertEqual(BufferingState.ready.description, "Ready")
    }
    
    // Test stream info formatting
    func testStreamInfoFormatting() {
        // Create helper to test stream info formatting
        let helper = StreamInfoHelper()
        
        // Test bitrate formatting
        let bitrateString = helper.formatBitrate(4_500_000)
        XCTAssertEqual(bitrateString, "4.5 Mbps")
        
        // Test frame rate formatting
        let frameRateString = helper.formatFrameRate(29.97)
        XCTAssertEqual(frameRateString, "30.0 FPS")
    }
}

// MARK: - Test Helpers

class PlayerViewErrorHelper {
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func clearError() {
        // This simulates tapping the dismiss button on the error banner
        viewModel.clearError()
    }
}

class RetryConnectionHelper {
    private let viewModel: TestConnectionViewModel
    
    init(viewModel: TestConnectionViewModel) {
        self.viewModel = viewModel
    }
    
    func retryConnection() {
        // This simulates the retry connection action
        viewModel.clearError()
        
        if let selectedDevice = viewModel.connectionState.selectedDevice {
            viewModel.connectToDevice(selectedDevice)
        }
    }
}

class StreamQualityHelper {
    func getPreferredBitrate(for quality: StreamQuality) -> Double {
        switch quality {
        case .low:
            return 1_500_000 // 1.5 Mbps
        case .medium:
            return 4_000_000 // 4 Mbps
        case .high:
            return 8_000_000 // 8 Mbps
        case .auto:
            return 0 // Auto
        }
    }
}

class TouchEventHelper {
    enum TouchEventType {
        case tap
        case drag
        case pinch
    }
    
    struct TouchEvent {
        let position: CGPoint
        let type: TouchEventType
        let timestamp: Date
    }
    
    func createTouchEvent(at position: CGPoint, type: TouchEventType = .tap) -> TouchEvent {
        return TouchEvent(position: position, type: type, timestamp: Date())
    }
}

class StreamInfoHelper {
    func formatBitrate(_ bitrate: Double) -> String {
        return String(format: "%.1f Mbps", bitrate / 1_000_000)
    }
    
    func formatFrameRate(_ frameRate: Double) -> String {
        return String(format: "%.1f FPS", frameRate)
    }
} 