import XCTest
import Foundation

class TestHelper {
    static func cleanupAfterTests() {
        // Force notification center to remove all observers
        NotificationCenter.default.removeObserver(self)
        
        // Clear UserDefaults test keys
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "streamQuality")
        defaults.removeObject(forKey: "bufferSize")
        defaults.synchronize()
        
        // Run the run loop to let pending operations finish
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Force memory cleanup
        autoreleasepool {
            // Trigger memory cleanup
        }
    }
}

// Extension to XCTestCase for easier use
extension XCTestCase {
    func terminateTestProcesses() {
        // Cleanup helper
        TestHelper.cleanupAfterTests()
        
        // Cancel any tasks or timers if needed
        // This depends on what's in your app that might keep running
        
        // Wait briefly to allow cleanup
        Thread.sleep(forTimeInterval: 0.1)
    }
} 