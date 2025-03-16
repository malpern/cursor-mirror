import Foundation
import ScreenCaptureKit
import SwiftUI

actor FrameProcessor {
    private var processor: AnyObject?
    
    func set(_ processor: AnyObject?) {
        self.processor = processor
    }
    
    func get() -> AnyObject? {
        processor
    }
}

@MainActor
public class ScreenCaptureManager: NSObject, ObservableObject, FrameCaptureManagerProtocol {
    @Published public var isScreenCapturePermissionGranted: Bool = false
    private var stream: SCStream?
    private var configuration: SCStreamConfiguration?
    
    // Create a serial queue for frame processing
    private let frameProcessingQueue = DispatchQueue(label: "com.cursor-window.frame-processing")
    private let frameProcessor = FrameProcessor()
    
    public override init() {
        super.init()
        Task {
            await checkPermission()
        }
    }
    
    public func checkPermission() async {
        do {
            let content = try await SCShareableContent.current
            isScreenCapturePermissionGranted = !content.displays.isEmpty
        } catch {
            isScreenCapturePermissionGranted = false
            print("Error checking screen capture permission: \(error)")
        }
    }
    
    public func startCapture(frameProcessor processor: AnyObject) async throws {
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
}

extension ScreenCaptureManager: SCStreamOutput {
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