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

/// Error types for ScreenCaptureManager
public enum ScreenCaptureError: Error, Equatable {
    case permissionDenied
    case noDisplayFound
    case streamInitializationFailed
    case invalidConfiguration
    case captureError(String)
    
    public static func == (lhs: ScreenCaptureError, rhs: ScreenCaptureError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied):
            return true
        case (.streamInitializationFailed, .streamInitializationFailed):
            return true
        case (.invalidConfiguration, .invalidConfiguration):
            return true
        case (.captureError(let lhsMsg), .captureError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
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
    private(set) var stream: SCStream?
    
    /// Configuration for the capture stream
    private var configuration: SCStreamConfiguration?
    
    /// Frame rate limiter
    private var lastFrameTime: Date?
    private let targetFrameInterval: TimeInterval = 1.0 / 60.0 // 60 FPS
    
    /// Actor for thread-safe state updates
    private let frameProcessorActor = FrameProcessorActor()
    
    /// Queue for frame processing
    private let frameProcessingQueue = DispatchQueue(
        label: "com.cursorwindow.screencapturemanager",
        qos: .userInitiated
    )
    
    /// Serial queue for processing captured frames
    private let processingQueue = DispatchQueue(
        label: "com.cursorwindow.screencapturemanager.processing",
        qos: .userInitiated
    )
    
    /// Indicates whether the screen capture is currently active
    @Published public private(set) var isCapturing = false
    
    /// The frame processor for the current capture session
    private var frameProcessor: FrameProcessor?
    
    /// The viewport manager for the current capture session
    private var viewportManager: ViewportManager?
    
    /// Initialize the screen capture manager and check initial permission status
    public override init() {
        // Load cached permission status from UserDefaults
        isScreenCapturePermissionGranted = UserDefaults.standard.bool(forKey: UserDefaultsKeys.lastKnownPermissionStatus)
        
        super.init()
        
        // Check permission on startup using a strong reference
        // This is safe because we're in init and the object can't be deallocated yet
        Task {
            await self.checkPermission()
        }
        
        Task {
            await frameProcessorActor.set(nil)
        }
    }
    
    /// Check if screen recording permission has been granted
    /// This method updates the `isScreenCapturePermissionGranted` property
    public func checkPermission() async {
        isCheckingPermission = true
        defer { isCheckingPermission = false }
        
        do {
            #if DEBUG
            // In test environment, use UserDefaults to control permission state
            let hasPermission = UserDefaults.standard.bool(forKey: UserDefaultsKeys.lastKnownPermissionStatus)
            print("Test environment permission check result: \(hasPermission)")
            #else
            // First check if we can get the shareable content at all
            _ = try await SCShareableContent.current
            let hasPermission = true
            print("Production permission check result: \(hasPermission)")
            #endif
            
            // Only update if the status changed to prevent unnecessary UI updates
            if hasPermission != isScreenCapturePermissionGranted {
                isScreenCapturePermissionGranted = hasPermission
                
                // Save the permission status to UserDefaults
                UserDefaults.standard.set(hasPermission, forKey: UserDefaultsKeys.lastKnownPermissionStatus)
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.permissionChecked)
            }
        } catch {
            print("Error checking screen capture permission: \(error)")
            isScreenCapturePermissionGranted = false
            
            // Save the failure state
            UserDefaults.standard.set(false, forKey: UserDefaultsKeys.lastKnownPermissionStatus)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.permissionChecked)
        }
    }
    
    /// Force refresh the permission status by requesting it directly from the system
    /// This is useful after the user may have granted permission in system preferences
    public func forceRefreshPermissionStatus() async {
        isCheckingPermission = true
        defer { isCheckingPermission = false }
        
        do {
            #if DEBUG
            // In test environment, use UserDefaults to control permission state
            let hasPermission = UserDefaults.standard.bool(forKey: UserDefaultsKeys.lastKnownPermissionStatus)
            print("Test environment permission refresh result: \(hasPermission)")
            #else
            // If we can get SCShareableContent without an error, we have permission
            _ = try await SCShareableContent.current
            let hasPermission = true
            print("Production permission refresh result: \(hasPermission)")
            #endif
            
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
            
            // Save the failure state
            UserDefaults.standard.set(false, forKey: UserDefaultsKeys.lastKnownPermissionStatus)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.permissionChecked)
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
                throw ScreenCaptureError.permissionDenied
            }
        }
        
        // Clean up any existing capture session
        try? await stopCapture()
        
        await frameProcessorActor.set(processor)
        do {
            #if DEBUG
            // In test environment, use the injected mock stream
            guard let stream = self.stream else {
                print("No mock stream available in test environment")
                throw ScreenCaptureError.streamInitializationFailed
            }
            #else
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else {
                throw ScreenCaptureError.streamInitializationFailed
            }
            
            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.queueDepth = 5
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            self.stream = SCStream(filter: filter, configuration: config, delegate: nil)
            configuration = config
            
            guard let stream = self.stream else {
                throw ScreenCaptureError.streamInitializationFailed
            }
            #endif
            
            // Add stream output before starting capture
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: frameProcessingQueue)
            
            // Start capture
            try await stream.startCapture()
            
            await checkPermission()
        } catch let error as ScreenCaptureError {
            print("Error starting capture: \(error)")
            try? await stopCapture()
            throw error
        } catch {
            print("Error starting capture: \(error)")
            try? await stopCapture()
            throw ScreenCaptureError.captureError("Failed to start capture: \(error.localizedDescription)")
        }
    }
    
    /// Start capturing the screen for a specific viewport
    /// - Parameters:
    ///   - frameProcessor: The processor that will handle captured frames
    ///   - viewportManager: The viewport manager that defines the capture region
    /// - Throws: ScreenCaptureError if capture cannot be started
    public func startCaptureForViewport(frameProcessor: FrameProcessor, viewportManager: ViewportManager) async throws {
        guard isScreenCapturePermissionGranted else {
            throw ScreenCaptureError.permissionDenied
        }
        
        self.frameProcessor = frameProcessor
        self.viewportManager = viewportManager
        
        #if DEBUG
        print("Running in DEBUG mode...")
        print("Creating mock stream...")
        stream = try await MockSCStream()
        print("Mock stream created")
        #else
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        #endif
        
        print("Adding stream output...")
        try await stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        print("Starting stream capture...")
        try await stream?.startCapture()
        print("Stream capture started successfully")
        isCapturing = true
    }
    
    public func stopCapture() async throws {
        try await stream?.stopCapture()
        stream = nil
        frameProcessor = nil
        viewportManager = nil
        isCapturing = false
    }
    
    deinit {
        // We can't use async/await in deinit, so we'll stop the stream synchronously
        if let stream = self.stream {
            try? stream.stopCapture() // Use try? since we can't throw in deinit
            self.stream = nil
        }
    }
    
    #if DEBUG
    /// Helper method for testing to get the current frame processor state
    internal func getFrameProcessorForTesting() async -> AnyObject? {
        return await frameProcessorActor.get()
    }
    
    /// Helper method for testing to get the current stream
    internal func getStreamForTesting() async -> SCStream? {
        return stream
    }
    
    /// Inject a mock stream for testing
    internal func injectMockStream(_ mockStream: SCStream?) {
        self.stream = mockStream
    }
    
    /// Helper method for testing to set the permission status
    public func setPermissionStatusForTesting(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: UserDefaultsKeys.lastKnownPermissionStatus)
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.permissionChecked)
        isScreenCapturePermissionGranted = granted
    }
    #endif
}

// MARK: - SCStreamOutput Implementation
@available(macOS 14.0, *)
extension ScreenCaptureManager: SCStreamOutput {
    /// Handle incoming frames from the capture stream
    /// This method is called on the frameProcessingQueue and safely processes frames
    /// through the actor-isolated frame processor
    @preconcurrency
    nonisolated public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Only process frames if we have a processor
        Task {
            if let processor = await frameProcessorActor.get() {
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