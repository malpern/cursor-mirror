import Foundation

/// Settings for HLS encoding
public struct HLSEncodingSettings {
    /// The resolution of the encoded video
    public let resolution: CGSize
    
    /// Initialize HLS encoding settings
    /// - Parameter resolution: The resolution of the encoded video
    public init(resolution: CGSize) {
        self.resolution = resolution
    }
} 