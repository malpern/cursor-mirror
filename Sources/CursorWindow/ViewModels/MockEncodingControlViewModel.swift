import Foundation
import CursorWindowCore
import CoreMedia

@MainActor
class MockEncodingControlViewModel: EncodingControlViewModel {
    nonisolated let frameProcessor: EncodingFrameProcessorProtocol = MockEncodingProcessor()
    private let _encodingSettings: EncodingSettings
    
    // Add a shared instance for use in previews
    static let shared = MockEncodingControlViewModel()
    
    init() {
        self._encodingSettings = EncodingSettings()
    }
    
    nonisolated var encodingSettings: EncodingSettings {
        get async {
            await _encodingSettings
        }
    }
    
    func startEncoding() async throws {
        try await frameProcessor.startEncoding(to: URL(fileURLWithPath: await _encodingSettings.outputPath),
                                             width: await _encodingSettings.width,
                                             height: await _encodingSettings.height)
    }
    
    func stopEncoding() async {
        await frameProcessor.stopEncoding()
    }
}

class MockEncodingProcessor: EncodingFrameProcessorProtocol {
    nonisolated func startEncoding(to outputURL: URL, width: Int, height: Int) async throws {
        print("Mock encoder started encoding to \(outputURL.path) with resolution \(width)x\(height)")
    }
    
    nonisolated func startEncoding(to outputURL: URL, width: Int, height: Int, completionHandler: @escaping (CMSampleBuffer, Error?, Bool) -> Void) async throws {
        print("Mock encoder started encoding to \(outputURL.path) with resolution \(width)x\(height) and callback")
    }
    
    nonisolated func stopEncoding() async {
        print("Mock encoder stopped encoding")
    }
    
    nonisolated func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) async {
        print("Mock encoder processed frame at time \(timestamp.seconds)")
    }
} 