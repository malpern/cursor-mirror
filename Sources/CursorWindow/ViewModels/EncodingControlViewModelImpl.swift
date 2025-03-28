import Foundation
import CursorWindowCore

@MainActor
class EncodingControlViewModelImpl: EncodingControlViewModel {
    nonisolated let frameProcessor: EncodingFrameProcessorProtocol
    private let _encodingSettings: EncodingSettings
    
    init(frameProcessor: EncodingFrameProcessorProtocol) async {
        self.frameProcessor = frameProcessor
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