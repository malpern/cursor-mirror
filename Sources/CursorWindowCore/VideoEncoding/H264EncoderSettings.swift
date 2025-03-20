import Foundation
import AVFoundation

/// Settings for H264 video encoding
public struct H264EncoderSettings {
    /// Video resolution
    public let resolution: CGSize
    
    /// Frames per second
    public let fps: Int
    
    /// Bitrate in bits per second
    public let bitrate: Int
    
    /// Key frame interval
    public let keyframeInterval: Int
    
    /// Maximum frame delay
    public let maxFrameDelay: Int
    
    /// Profile level
    public let profileLevel: String
    
    /// Initialize with default settings for given resolution
    /// - Parameter resolution: Target resolution
    /// - Returns: Encoder settings
    public static func defaultSettings(for resolution: CGSize) -> H264EncoderSettings {
        if resolution.width >= 1920 || resolution.height >= 1080 {
            return H264EncoderSettings.hd
        } else if resolution.width >= 1280 || resolution.height >= 720 {
            return H264EncoderSettings.hd
        } else {
            return H264EncoderSettings.sd
        }
    }
    
    /// Standard definition preset (480p)
    public static let sd = H264EncoderSettings(
        resolution: CGSize(width: 854, height: 480),
        fps: 30,
        bitrate: 1_000_000,
        keyframeInterval: 30,
        maxFrameDelay: 3,
        profileLevel: kVTProfileLevel_H264_Main_AutoLevel as String
    )
    
    /// High definition preset (720p)
    public static let hd = H264EncoderSettings(
        resolution: CGSize(width: 1280, height: 720),
        fps: 30,
        bitrate: 2_500_000,
        keyframeInterval: 30,
        maxFrameDelay: 3,
        profileLevel: kVTProfileLevel_H264_Main_AutoLevel as String
    )
    
    /// Ultra high definition preset (1080p)
    public static let fullHD = H264EncoderSettings(
        resolution: CGSize(width: 1920, height: 1080),
        fps: 30,
        bitrate: 5_000_000,
        keyframeInterval: 30,
        maxFrameDelay: 3,
        profileLevel: kVTProfileLevel_H264_Main_AutoLevel as String
    )
} 