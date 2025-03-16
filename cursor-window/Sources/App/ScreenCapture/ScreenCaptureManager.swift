import Foundation
import ScreenCaptureKit

/// Manages screen capture functionality and permissions
@MainActor
class ScreenCaptureManager: ObservableObject {
    /// The current permission status for screen capture
    @Published private(set) var permissionStatus: SCAuthorizationStatus = .notDetermined
    
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
            let status = await SCShareableContent.current.authorizationStatus
            await MainActor.run {
                self.permissionStatus = status
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    /// Requests screen capture permission from the user
    func requestPermission() async {
        do {
            // Request permission
            try await SCShareableContent.requestScreenCaptureAccess()
            // Update status after request
            await updatePermissionStatus()
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
} 