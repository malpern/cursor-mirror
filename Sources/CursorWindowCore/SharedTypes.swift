#if os(macOS)
import Foundation
import SwiftUI
import ScreenCaptureKit
import AVFoundation

// MARK: - Frame Processing Protocols

/// A protocol for basic frame processing operations.
/// Implementations should handle raw frame data without any encoding.
/// This is typically used for preview and analysis purposes.
@available(macOS 14.0, *)
@preconcurrency public protocol BasicFrameProcessorProtocol: AnyObject {
    /// Process a single frame from the screen capture stream
    /// - Parameter frame: A CMSampleBuffer containing the captured frame data
    nonisolated func processFrame(_ frame: CMSampleBuffer)
}

/// A protocol for frame processors that handle video encoding.
/// Implementations should manage both frame processing and encoding operations.
/// This is used for saving or streaming video content.
@available(macOS 14.0, *)
@preconcurrency public protocol EncodingFrameProcessorProtocol: AnyObject {
    /// Process and encode a single frame
    /// - Parameter frame: A CMSampleBuffer containing the captured frame data
    nonisolated func processFrame(_ frame: CMSampleBuffer)
    
    /// Start encoding video to a specified URL
    /// - Parameters:
    ///   - url: The destination URL for the encoded video file
    ///   - width: The width of the video in pixels
    ///   - height: The height of the video in pixels
    /// - Throws: CursorWindowError if encoding initialization fails
    nonisolated func startEncoding(to url: URL, width: Int, height: Int) throws
    
    /// Stop the current encoding session and finalize the video file
    nonisolated func stopEncoding()
}

/// A protocol for managing screen capture operations.
/// Implementations should handle capture setup, permissions, and frame delivery.
@available(macOS 14.0, *)
@preconcurrency public protocol FrameCaptureManagerProtocol: AnyObject {
    /// Start capturing screen content with a specified frame processor
    /// - Parameter frameProcessor: An object conforming to either BasicFrameProcessorProtocol or EncodingFrameProcessorProtocol
    /// - Throws: CursorWindowError if capture initialization fails or permission is denied
    func startCapture(frameProcessor: AnyObject) async throws
    
    /// Stop the current capture session
    /// - Throws: CursorWindowError if stopping the capture fails
    func stopCapture() async throws
}

// MARK: - View Model Protocols

/// A protocol for view models that manage capture preview functionality.
/// Implementations should coordinate between the UI and capture system.
@available(macOS 14.0, *)
@preconcurrency public protocol CapturePreviewViewModel {
    /// The frame processor responsible for handling preview frames
    nonisolated var frameProcessor: BasicFrameProcessorProtocol { get }
    
    /// The capture manager responsible for screen capture operations
    nonisolated var captureManager: FrameCaptureManagerProtocol { get }
}

/// A protocol for view models that manage video encoding controls.
/// Implementations should handle encoding settings and state.
@available(macOS 14.0, *)
@preconcurrency public protocol EncodingControlViewModel {
    /// The frame processor responsible for encoding frames to video
    nonisolated var frameProcessor: EncodingFrameProcessorProtocol { get }
}

// MARK: - Environment Keys

/// Environment key for providing the capture preview view model
@available(macOS 14.0, *)
private struct CapturePreviewViewModelKey: EnvironmentKey {
    static let defaultValue: (any CapturePreviewViewModel)? = nil
}

/// Environment key for providing the encoding control view model
@available(macOS 14.0, *)
private struct EncodingControlViewModelKey: EnvironmentKey {
    static let defaultValue: (any EncodingControlViewModel)? = nil
}

// MARK: - Environment Values Extension

@available(macOS 14.0, *)
public extension EnvironmentValues {
    /// Access the capture preview view model from the environment
    var capturePreviewViewModel: (any CapturePreviewViewModel)? {
        get { self[CapturePreviewViewModelKey.self] }
        set { self[CapturePreviewViewModelKey.self] = newValue }
    }
    
    /// Access the encoding control view model from the environment
    var encodingControlViewModel: (any EncodingControlViewModel)? {
        get { self[EncodingControlViewModelKey.self] }
        set { self[EncodingControlViewModelKey.self] = newValue }
    }
}

@available(macOS 14.0, *)
public enum CaptureError: Error {
    // ... existing code ...
}

@available(macOS 14.0, *)
public protocol FrameProcessor: Actor {
    // ... existing code ...
}

@available(macOS 14.0, *)
public protocol VideoEncoder: Actor {
    // ... existing code ...
}

#else
#error("SharedTypes is only available on macOS 14.0 or later")
#endif 