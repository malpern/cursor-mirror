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