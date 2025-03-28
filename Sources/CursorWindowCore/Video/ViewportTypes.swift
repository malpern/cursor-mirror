import Foundation
import CoreGraphics

/// Represents the dimensions of a viewport
public struct ViewportSize: Sendable {
    public let width: CGFloat
    public let height: CGFloat
    public static let cornerRadius: CGFloat = 55  // iPhone 15 Pro corner radius
    public static let strokeWidth: CGFloat = 5
    
    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    public static func defaultSize() -> ViewportSize {
        ViewportSize(width: 393, height: 852)
    }
} 