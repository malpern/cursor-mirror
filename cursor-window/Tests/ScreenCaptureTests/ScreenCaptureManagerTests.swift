import XCTest
import ScreenCaptureKit
@testable import CursorMirror

@MainActor
final class ScreenCaptureManagerTests: XCTestCase {
    var manager: ScreenCaptureManager!
    
    override func setUp() async throws {
        manager = ScreenCaptureManager()
    }
    
    override func tearDown() async throws {
        manager = nil
    }
    
    func testInitialPermissionStatus() async throws {
        // When the manager is initialized
        let manager = ScreenCaptureManager()
        
        // Then the initial permission status should be not determined
        XCTAssertEqual(manager.permissionStatus, .notDetermined)
        XCTAssertNil(manager.error)
    }
    
    func testPermissionRequest() async throws {
        // Given the manager is in initial state
        XCTAssertEqual(manager.permissionStatus, .notDetermined)
        
        // When requesting permission
        await manager.requestPermission()
        
        // Then the permission status should be updated
        // Note: In actual testing, this will show a system dialog
        // and we can't programmatically accept/deny it
        XCTAssertNotEqual(manager.permissionStatus, .notDetermined)
    }
    
    func testErrorHandling() async throws {
        // TODO: Add error handling tests when we implement error simulation
        // This will require creating a mock/stub for SCShareableContent
    }
} 