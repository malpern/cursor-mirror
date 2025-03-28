import SwiftUI
import CursorWindowCore

// MARK: - Encoding Control View Model

private struct EncodingControlViewModelKey: EnvironmentKey {
    static let defaultValue: EncodingControlViewModel? = nil
}

extension EnvironmentValues {
    var encodingControlViewModel: EncodingControlViewModel? {
        get { self[EncodingControlViewModelKey.self] }
        set { self[EncodingControlViewModelKey.self] = newValue }
    }
} 