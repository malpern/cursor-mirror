#if os(macOS)
import Foundation
import SwiftUI
import ScreenCaptureKit
import AVFoundation
import CoreGraphics
import OSLog

/// An actor that provides thread-safe access to frame processors.
/// This ensures that frame processor references are managed safely across concurrent operations.
@available(macOS 14.0, *)
actor FrameProcessorActor {
    /// The current frame processor instance
    private var processor: AnyObject?
    
    /// Set a new frame processor
    /// - Parameter processor: The frame processor to set, or nil to clear
    public init() {}
    
    func set(_ processor: AnyObject?) {
        self.processor = processor
    }
    
    /// Get the current frame processor
    /// - Returns: The current frame processor, if one is set
    func get() -> AnyObject? {
        processor
    }
}

/// A class that manages screen capture operations with thread-safe frame processing.
/// This class is designed to run on the main actor and coordinates between the UI
/// and the capture system while ensuring thread safety through actor isolation.
@available(macOS 14.0, *)
@MainActor
public final class ScreenCaptureManager: NSObject, ObservableObject, FrameCaptureManagerProtocol {
    // UserDefaults keys
    private enum UserDefaultsKeys {
        static let permissionChecked = "com.cursor-window.permissionChecked"
        static let lastKnownPermissionStatus = "com.cursor-window.lastKnownPermissionStatus"
    }
    
    /// Indicates whether screen recording permission has been granted
    @Published public var isScreenCapturePermissionGranted: Bool = false
    
    /// Indicates whether we're currently checking for permission
    @Published public var isCheckingPermission: Bool = false
    
    /// The active screen capture stream
    private var stream: SCStream?
    
    /// Configuration for the capture stream
    private var configuration: SCStreamConfiguration?
    
    /// A serial queue for processing captured frames
    /// This ensures frames are processed in order and prevents thread contention
    private let frameProcessingQueue = DispatchQueue(label: "com.cursor-window.frame-processing")
    
    /// An actor that provides thread-safe access to the current frame processor
    private let frameProcessor = FrameProcessorActor()
    
    /// Initialize the screen capture manager and check initial permission status
    public override init() {
        // Load cached permission status from UserDefaults
        isScreenCapturePermissionGranted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.lastKnownPermissionStatus)
        
        super.init()
        
        // Check permission on startup
        Task {
            await checkPermission()
        }
    }
    
    /// Check if screen recording permission has been granted
    /// This method updates the `isScreenCapturePermissionGranted` property
    public func checkPermission() async {
        isCheckingPermission = true
        defer { isCheckingPermission = false }
        
        do {
            // First check if we can get the shareable content at all
            _ = try await SCShareableContent.current
            
            // On macOS, if we can get SCShareableContent without an error, we have permission
            let hasPermission = true
            
            print("Permission check result: \(hasPermission)")
            
            // Only update if the status changed to prevent unnecessary UI updates
            if hasPermission != isScreenCapturePermissionGranted {
                isScreenCapturePermissionGranted = hasPermission
                
                // Save the permission status to UserDefaults
                UserDefaults.standard.set(hasPermission, forKey: UserDefaultsKeys.lastKnownPermissionStatus)
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.permissionChecked)
            }
        } catch {
            isScreenCapturePermissionGranted = false
            print("Error checking screen capture permission: \(error)")
        }
    }
    
    /// Force refresh the permission status by requesting it directly from the system
    /// This is useful after the user may have granted permission in system preferences
    public func forceRefreshPermissionStatus() async {
        isCheckingPermission = true
        defer { isCheckingPermission = false }
        
        do {
            // If we can get SCShareableContent without an error, we have permission
            _ = try await SCShareableContent.current
            let hasPermission = true
            
            print("Permission refresh check result: \(hasPermission)")
            
            // Update and persist the status
            if hasPermission != isScreenCapturePermissionGranted {
                print("Permission status changed: \(hasPermission)")
                isScreenCapturePermissionGranted = hasPermission
                
                // Save the updated permission status
                UserDefaults.standard.set(hasPermission, forKey: UserDefaultsKeys.lastKnownPermissionStatus)
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.permissionChecked)
            }
        } catch {
            print("Error refreshing permission status: \(error)")
            isScreenCapturePermissionGranted = false
            
            // Save the failure status
            UserDefaults.standard.set(false, forKey: UserDefaultsKeys.lastKnownPermissionStatus)
        }
    }
    
    /// Open system preferences to the screen recording permission settings
    public func openSystemPreferencesScreenCapture() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    
    /// Start capturing screen content with the specified frame processor
    /// - Parameter processor: An object conforming to either BasicFrameProcessorProtocol or EncodingFrameProcessorProtocol
    /// - Throws: An error if capture initialization fails or permission is denied
    public func startCapture(frameProcessor processor: AnyObject) async throws {
        // Ensure we have permission first
        if !isScreenCapturePermissionGranted {
            await forceRefreshPermissionStatus()
            
            if !isScreenCapturePermissionGranted {
                throw NSError(domain: "com.cursor-window", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "Screen recording permission is required to capture the screen."
                ])
            }
        }
        
        await frameProcessor.set(processor)
        do {
            let content = try await SCShareableContent.current
            if let display = content.displays.first {
                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                config.queueDepth = 5
                
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameProcessingQueue)
                try await stream?.startCapture()
                
                await checkPermission()
            }
        } catch {
            print("Error starting capture: \(error)")
            throw error
        }
    }
    
    /// Stop the current capture session
    /// - Throws: An error if stopping the capture fails
    public func stopCapture() async throws {
        do {
            try await stream?.stopCapture()
            stream = nil
            await frameProcessor.set(nil)
        } catch {
            print("Error stopping capture: \(error)")
            throw error
        }
    }
    
    /// Start capturing screen content from the viewport area
    /// - Parameters:
    ///   - processor: The frame processor to use for handling captured frames
    ///   - viewportManager: The viewport manager providing position and size information
    /// - Throws: An error if capture initialization fails or permission is denied
    public func startCaptureForViewport(frameProcessor processor: AnyObject, viewportManager: ViewportManager) async throws {
        // Ensure we have permission first
        if !isScreenCapturePermissionGranted {
            await forceRefreshPermissionStatus()
            
            if !isScreenCapturePermissionGranted {
                throw NSError(domain: "com.cursor-window", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "Screen recording permission is required to capture the viewport."
                ])
            }
        }
        
        await self.frameProcessor.set(processor)
        do {
            let content = try await SCShareableContent.current
            if let display = content.displays.first {
                let screenFrame = CGRect(
                    x: 0, 
                    y: 0, 
                    width: display.width, 
                    height: display.height
                )
                
                // Convert viewport position to screen coordinates
                // Note: macOS coordinate system has (0,0) at bottom-left, but our UI has (0,0) at top-left
                let viewportRect = CGRect(
                    x: viewportManager.position.x,
                    y: screenFrame.height - viewportManager.position.y - ViewportManager.viewportSize.height,
                    width: ViewportManager.viewportSize.width,
                    height: ViewportManager.viewportSize.height
                )
                
                let config = SCStreamConfiguration()
                config.width = Int(ViewportManager.viewportSize.width)
                config.height = Int(ViewportManager.viewportSize.height)
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                config.queueDepth = 5
                config.capturesAudio = true
                
                // Crop to just the viewport area
                config.sourceRect = viewportRect
                
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameProcessingQueue)
                try await stream?.startCapture()
                
                await checkPermission()
            }
        } catch {
            print("Error starting capture for viewport: \(error)")
            throw error
        }
    }
}

// MARK: - SCStreamOutput Implementation
@available(macOS 14.0, *)
extension ScreenCaptureManager: SCStreamOutput {
    /// Handle incoming frames from the capture stream
    /// This method is called on the frameProcessingQueue and safely processes frames
    /// through the actor-isolated frame processor
    nonisolated public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        Task {
            // Get the current frame processor in an actor-safe way
            if let processor = await frameProcessor.get() {
                if let basicProcessor = processor as? BasicFrameProcessorProtocol {
                    basicProcessor.processFrame(sampleBuffer)
                } else if let encodingProcessor = processor as? EncodingFrameProcessorProtocol {
                    encodingProcessor.processFrame(sampleBuffer)
                }
            }
        }
    }
}

#else
#error("ScreenCaptureManager is only available on macOS 14.0 or later")
#endif 