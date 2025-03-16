import Foundation
import ScreenCaptureKit

/// Manages screen capture functionality and permissions
@MainActor
class ScreenCaptureManager: ObservableObject {
    /// The current permission status for screen capture
    @Published private(set) var isScreenCapturePermissionGranted = false
    
    /// Error that occurred during screen capture operations
    @Published private(set) var error: Error?
    
    /// Initializes the screen capture manager
    init() {
        // Get initial permission status
        Task {
            await updatePermissionStatus()
        }
    }
    
    /// Updates the current permission status
    private func updatePermissionStatus() async {
        do {
            // Check if we can access screen capture
            _ = try await SCShareableContent.current
            await MainActor.run {
                self.isScreenCapturePermissionGranted = true
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.isScreenCapturePermissionGranted = false
                self.error = error
            }
        }
    }
    
    /// Requests screen capture permission from the user
    func requestPermission() async {
        do {
            // Just trying to access SCShareableContent.current will trigger the permission dialog
            _ = try await SCShareableContent.current
            await updatePermissionStatus()
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
} 