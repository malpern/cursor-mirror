import Foundation
import Combine

@MainActor
public class EncodingSettings: ObservableObject {
    @Published public var outputPath: String
    @Published public var width: Int
    @Published public var height: Int
    @Published public var frameRate: Double
    @Published public var quality: Double
    
    public init(
        outputPath: String = NSHomeDirectory() + "/Desktop/output.mov",
        width: Int = 1920,
        height: Int = 1080,
        frameRate: Double = 30.0,
        quality: Double = 0.8
    ) {
        self.outputPath = outputPath
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.quality = quality
    }
    
    public enum Update {
        case outputPath(String)
        case width(Int)
        case height(Int)
        case frameRate(Double)
        case quality(Double)
    }
    
    public func apply(_ update: Update) {
        switch update {
        case .outputPath(let value):
            outputPath = value
        case .width(let value):
            width = value
        case .height(let value):
            height = value
        case .frameRate(let value):
            frameRate = value
        case .quality(let value):
            quality = value
        }
    }
    
    // Method to update all settings atomically
    public func updateSettings(
        outputPath: String? = nil,
        width: Int? = nil,
        height: Int? = nil,
        frameRate: Double? = nil,
        quality: Double? = nil
    ) {
        if let outputPath = outputPath {
            self.outputPath = outputPath
        }
        
        if let width = width {
            self.width = width
        }
        
        if let height = height {
            self.height = height
        }
        
        if let frameRate = frameRate {
            self.frameRate = frameRate
        }
        
        if let quality = quality {
            self.quality = quality
        }
    }
    
    // Nonisolated getters for accessing settings from any context
    public nonisolated func getSettings() async -> (outputPath: String, width: Int, height: Int, frameRate: Double, quality: Double) {
        await (outputPath, width, height, frameRate, quality)
    }
    
    public nonisolated func getDictionary() async -> [String: Any] {
        let settings = await getSettings()
        return [
            "outputPath": settings.outputPath,
            "width": settings.width,
            "height": settings.height,
            "frameRate": settings.frameRate,
            "quality": settings.quality
        ]
    }
} 