import Foundation
import SwiftUI

@MainActor
class EncodingSettings: ObservableObject {
    @Published var outputPath = NSHomeDirectory() + "/Desktop/output.mov"
    @Published var width = 393
    @Published var height = 852
    @Published var frameRate = 30
    @Published var quality: Double = 0.8
    
    init(
        outputPath: String = NSHomeDirectory() + "/Desktop/output.mov",
        width: Int = 393,
        height: Int = 852,
        frameRate: Int = 30,
        quality: Double = 0.8
    ) {
        self.outputPath = outputPath
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.quality = quality
    }
} 