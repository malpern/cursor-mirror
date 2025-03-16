import Foundation
import SwiftUI
import ScreenCaptureKit

/// Represents a region of the screen to be captured
@MainActor
class CaptureRegion: ObservableObject {
    /// The current region to capture
    @Published var region: CGRect
    
    /// The display the region is on
    @Published var display: SCDisplay?
    
    /// The scale factor for the display
    @Published var scaleFactor: CGFloat = 1.0
    
    /// Initialize with a default region
    init(region: CGRect = .zero) {
        self.region = region
    }
    
    /// Update the region
    func updateRegion(newRegion: CGRect) {
        self.region = validateRegion(newRegion)
    }
    
    /// Update the display and scale factor
    func updateDisplay(display: SCDisplay?) {
        self.display = display
        // Note: SCDisplay doesn't have a scaleFactor property in all versions
        // We'll use a default value of 1.0 or get it from the display if available
        self.scaleFactor = 1.0
    }
    
    /// Validate that the region is within the display bounds
    private func validateRegion(_ proposedRegion: CGRect) -> CGRect {
        guard let display = display else {
            return proposedRegion
        }
        
        // Get the display bounds
        let displayBounds = CGRect(x: 0, y: 0, width: display.width, height: display.height)
        
        // Ensure the region is within the display bounds
        return proposedRegion.intersection(displayBounds)
    }
    
    /// Get the region in screen coordinates
    func regionInScreenCoordinates() -> CGRect {
        guard let display = display else {
            return region
        }
        
        // Convert the region to screen coordinates
        return CGRect(
            x: display.frame.origin.x + region.origin.x,
            y: display.frame.origin.y + region.origin.y,
            width: region.width,
            height: region.height
        )
    }
    
    /// Create a filter for screen capture based on the region
    func createFilter() -> SCContentFilter? {
        guard let display = display, !region.isEmpty else {
            return nil
        }
        
        // Create a region-based filter
        // Note: Some versions of ScreenCaptureKit don't support includingRegions
        return SCContentFilter(display: display, excludingWindows: [])
    }
} 