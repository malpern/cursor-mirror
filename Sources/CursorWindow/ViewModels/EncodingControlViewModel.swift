import Foundation
import CursorWindowCore

@MainActor
protocol EncodingControlViewModel {
    nonisolated var frameProcessor: EncodingFrameProcessorProtocol { get }
    nonisolated var encodingSettings: EncodingSettings { get async }
    
    func startEncoding() async throws
    func stopEncoding() async
} 