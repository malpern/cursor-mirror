import Foundation

/// Represents different video stream quality options
public enum StreamQuality: String, CaseIterable, Codable {
    /// Standard definition (480p)
    case sd = "480p"
    
    /// High definition (720p)
    case hd = "720p"
    
    /// Full HD (1080p)
    case fullHD = "1080p"
    
    /// Directory name for this quality's segments
    public var directoryName: String {
        return rawValue
    }
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .sd:
            return "Standard Definition (480p)"
        case .hd:
            return "High Definition (720p)"
        case .fullHD:
            return "Full HD (1080p)"
        }
    }
    
    /// Get the corresponding encoder settings for this quality
    public var encoderSettings: H264EncoderSettings {
        switch self {
        case .sd:
            return .sd
        case .hd:
            return .hd
        case .fullHD:
            return .fullHD
        }
    }
    
    /// Bandwidth in bits per second for this quality
    public var bandwidth: Int {
        switch self {
        case .sd:
            return 1_000_000 // 1 Mbps
        case .hd:
            return 2_500_000 // 2.5 Mbps
        case .fullHD:
            return 5_000_000 // 5 Mbps
        }
    }
} 