//
//  CursorMirrorClientApp.swift
//  CursorMirrorClient
//
//  Created by Micah Alpern on 3/23/25.
//

import SwiftUI

@main
struct CursorMirrorClientApp: App {
    // Add detection for running in test environment
    let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    
    init() {
        // If running in tests, set up for better test behavior
        if isRunningTests {
            // Set shorter timeouts or configure mock services if needed
            setupForTestEnvironment()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Initialize anything that needs to be created only once
                }
                .onDisappear {
                    // Clean up resources when the app disappears (for testing)
                    if isRunningTests {
                        cleanupForTests()
                    }
                }
        }
    }
    
    private func setupForTestEnvironment() {
        // Configure app for testing environment
        // For example, disable animations, use mock services, etc.
        print("Running in test environment - optimizing for tests")
    }
    
    private func cleanupForTests() {
        // Clean up any resources that might keep the app running
        // This helps tests terminate properly
        NotificationCenter.default.removeObserver(self)
        
        // Cancel any tasks, timers, etc.
    }
}
