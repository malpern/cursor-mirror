import Foundation
import SwiftUI
import ScreenCaptureKit
import AVFoundation

// MARK: - Frame Processing Protocols
@preconcurrency public protocol BasicFrameProcessorProtocol: AnyObject {
    func processFrame(_ frame: CMSampleBuffer)
}

@preconcurrency public protocol EncodingFrameProcessorProtocol: AnyObject {
    func processFrame(_ frame: CMSampleBuffer)
    func startEncoding(to url: URL, width: Int, height: Int) throws
    func stopEncoding()
}

@preconcurrency public protocol FrameCaptureManagerProtocol: AnyObject {
    func startCapture(frameProcessor: AnyObject) async throws
    func stopCapture() async throws
}

// MARK: - View Model Protocols
@preconcurrency public protocol CapturePreviewViewModel {
    var frameProcessor: BasicFrameProcessorProtocol { get }
    var captureManager: FrameCaptureManagerProtocol { get }
}

@preconcurrency public protocol EncodingControlViewModel {
    var frameProcessor: EncodingFrameProcessorProtocol { get }
}

// MARK: - Environment Keys
private struct CapturePreviewViewModelKey: EnvironmentKey {
    static let defaultValue: CapturePreviewViewModel? = nil
}

private struct EncodingControlViewModelKey: EnvironmentKey {
    static let defaultValue: EncodingControlViewModel? = nil
}

// MARK: - Environment Values Extension
public extension EnvironmentValues {
    var capturePreviewViewModel: CapturePreviewViewModel? {
        get { self[CapturePreviewViewModelKey.self] }
        set { self[CapturePreviewViewModelKey.self] = newValue }
    }
    
    var encodingControlViewModel: EncodingControlViewModel? {
        get { self[EncodingControlViewModelKey.self] }
        set { self[EncodingControlViewModelKey.self] = newValue }
    }
} 