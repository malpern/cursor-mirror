import Foundation

/// Represents the type of touch event
enum TouchEventType: String, Codable {
    case began
    case moved
    case ended
    case cancelled
}

/// Represents a touch event from iOS to be emulated on macOS
struct TouchEvent: Codable {
    /// Unique identifier for the event
    let id: UUID
    
    /// Type of touch event (began, moved, ended, etc.)
    let type: TouchEventType
    
    /// Position as a percentage of the viewport width (0-1)
    let percentX: Double
    
    /// Position as a percentage of the viewport height (0-1)
    let percentY: Double
    
    /// Force/pressure of the touch (0-1, if available)
    let force: Double?
    
    /// Timestamp of when the event occurred
    let timestamp: Date
    
    /// Create a new touch event
    /// - Parameters:
    ///   - type: Type of touch event
    ///   - percentX: X position as percentage (0-1)
    ///   - percentY: Y position as percentage (0-1)
    ///   - force: Touch force/pressure (optional)
    init(type: TouchEventType, percentX: Double, percentY: Double, force: Double? = nil) {
        self.id = UUID()
        self.type = type
        self.percentX = min(max(percentX, 0), 1) // Clamp to 0-1
        self.percentY = min(max(percentY, 0), 1) // Clamp to 0-1
        self.force = force
        self.timestamp = Date()
    }
    
    /// Convert touch event to JSON data
    /// - Returns: JSON data representation of the touch event
    func toJSONData() -> Data? {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            print("Error encoding touch event: \(error)")
            return nil
        }
    }
    
    /// Create touch event from JSON data
    /// - Parameter data: JSON data
    /// - Returns: TouchEvent instance or nil if parsing failed
    static func from(jsonData data: Data) -> TouchEvent? {
        do {
            return try JSONDecoder().decode(TouchEvent.self, from: data)
        } catch {
            print("Error decoding touch event: \(error)")
            return nil
        }
    }
} 