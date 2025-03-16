import Foundation
import ScreenCaptureKit
import SwiftUI

/// Represents the configuration for screen capture displays
@MainActor
class DisplayConfiguration: ObservableObject {
    /// The available displays for screen capture
    @Published private(set) var displays: [SCDisplay] = []
    
    /// The currently selected display for capture
    @Published var selectedDisplay: SCDisplay?
    
    /// The available windows that can be captured
    @Published private(set) var windows: [SCWindow] = []
    
    /// Error that occurred during display configuration
    @Published var error: Error?
    
    /// Updates the list of available displays and windows
    func updateDisplays() async throws {
        // Get all available screen content using ScreenCaptureKit
        let content = try await SCShareableContent.current
        
        // Update displays
        self.displays = content.displays
        
        // Set selected display to first display (typically the main display) if not already set
        if selectedDisplay == nil && !displays.isEmpty {
            self.selectedDisplay = displays.first
        }
        
        // Update windows (excluding our own app's windows)
        self.windows = content.windows.filter { window in
            // Filter out our own app's windows and system UI elements
            if let bundleID = window.owningApplication?.bundleIdentifier {
                return !bundleID.contains("cursor-window")
            }
            return true
        }
    }
    
    /// Creates a filter for screen capture based on the current configuration
    func createFilter() -> SCContentFilter {
        guard let display = selectedDisplay, !displays.isEmpty else {
            // If no display is selected or available, capture the first display if available
            if let firstDisplay = displays.first {
                return SCContentFilter(display: firstDisplay, excludingWindows: [])
            }
            // Fallback to an empty filter if no displays are available
            return SCContentFilter.init()
        }
        
        // Create a display filter
        return SCContentFilter(display: display, excludingWindows: [])
    }
} 