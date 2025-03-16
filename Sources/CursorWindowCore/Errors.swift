import Foundation

/// Represents errors that can occur in the core functionality
public enum CursorWindowError: LocalizedError {
    // Capture errors
    case capturePermissionDenied
    case captureInitializationFailed(String)
    case captureStreamFailed(String)
    case invalidCaptureRegion
    
    // Frame processing errors
    case frameProcessingFailed(String)
    case invalidFrameFormat
    
    // Encoding errors
    case encoderInitializationFailed(String)
    case encodingFailed(String)
    case fileWriteFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .capturePermissionDenied:
            return "Screen recording permission is required. Please grant permission in System Settings."
        case .captureInitializationFailed(let details):
            return "Failed to initialize screen capture: \(details)"
        case .captureStreamFailed(let details):
            return "Screen capture stream failed: \(details)"
        case .invalidCaptureRegion:
            return "The selected capture region is invalid."
        case .frameProcessingFailed(let details):
            return "Failed to process frame: \(details)"
        case .invalidFrameFormat:
            return "The frame format is not supported."
        case .encoderInitializationFailed(let details):
            return "Failed to initialize video encoder: \(details)"
        case .encodingFailed(let details):
            return "Video encoding failed: \(details)"
        case .fileWriteFailed(let details):
            return "Failed to write video file: \(details)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .capturePermissionDenied:
            return "Open System Settings > Privacy & Security > Screen Recording and enable permission for this app."
        case .captureInitializationFailed:
            return "Try restarting the application. If the problem persists, check system resources."
        case .captureStreamFailed:
            return "Check if another application is using screen recording. Try restarting the capture."
        case .invalidCaptureRegion:
            return "Adjust the capture region to be within screen bounds."
        case .frameProcessingFailed, .invalidFrameFormat:
            return "Try reducing the capture frame rate or region size."
        case .encoderInitializationFailed:
            return "Check available system resources and try again."
        case .encodingFailed:
            return "Try reducing the encoding quality or frame rate."
        case .fileWriteFailed:
            return "Check available disk space and file permissions."
        }
    }
} 