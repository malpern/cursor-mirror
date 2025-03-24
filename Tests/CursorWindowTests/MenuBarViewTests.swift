import XCTest
import SwiftUI
import ScreenCaptureKit
@testable import CursorWindow
@testable import CursorWindowCore

@MainActor
final class MenuBarViewTests: XCTestCase {
    var screenCaptureManager: ScreenCaptureManager!
    var viewportManager: ViewportManager!
    var view: MenuBarView!
    
    override func setUp() async throws {
        try await super.setUp()
        screenCaptureManager = await ScreenCaptureManager()
        viewportManager = ViewportManager { AnyView(EmptyView()) }
        
        // Create the view
        view = await MenuBarView()
        
        // Set up environment objects
        let viewWithEnvironment = view
            .environmentObject(screenCaptureManager)
            .environmentObject(viewportManager)
        
        // Extract the MenuBarView back from the environment
        if let menuBarView = viewWithEnvironment as? MenuBarView {
            view = menuBarView
        }
        
        // Set permission to true for testing
        await screenCaptureManager.setPermissionStatusForTesting(true)
    }
    
    override func tearDown() async throws {
        screenCaptureManager = nil
        viewportManager = nil
        view = nil
        try await super.tearDown()
    }
    
    func testCaptureButtonStateChanges() async throws {
        // Initial state should be not capturing
        XCTAssertFalse(screenCaptureManager.isCapturing)
        
        // Simulate starting capture
        try await screenCaptureManager.startCaptureForViewport(
            frameProcessor: BasicFrameProcessor(),
            viewportManager: viewportManager
        )
        
        // Wait for state to update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify capture is active
        XCTAssertTrue(screenCaptureManager.isCapturing)
        
        // Simulate stopping capture
        try await screenCaptureManager.stopCapture()
        
        // Wait for state to update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify capture is stopped
        XCTAssertFalse(screenCaptureManager.isCapturing)
    }
    
    func testCaptureButtonHandlesErrors() async throws {
        // Initial state should be not capturing
        XCTAssertFalse(screenCaptureManager.isCapturing)
        
        // Simulate error by setting permission to false
        await screenCaptureManager.setPermissionStatusForTesting(false)
        
        // Try to start capture (should fail)
        do {
            try await screenCaptureManager.startCaptureForViewport(
                frameProcessor: BasicFrameProcessor(),
                viewportManager: viewportManager
            )
            XCTFail("Expected an error to be thrown")
        } catch {
            // Verify capture state remains false
            XCTAssertFalse(screenCaptureManager.isCapturing)
        }
    }
}

extension View {
    func findViewWithTag(_ tag: String) -> Any? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let view = child.value as? (any View),
               let tagged = view as? any TaggedView,
               tagged.tag as? String == tag {
                return view
            }
            if let found = (child.value as? any View)?.findViewWithTag(tag) {
                return found
            }
        }
        return nil
    }
}