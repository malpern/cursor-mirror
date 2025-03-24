import Foundation
import SwiftUI
import AppKit

/// Controller for handling touch events and emulating them as mouse events on macOS
public class TouchEventController {
    /// Singleton instance
    public static let shared = TouchEventController()
    
    /// Whether touch emulation is enabled
    public var isEnabled: Bool = false
    
    /// The viewport bounds to map touch events to
    public var viewportBounds: CGRect = .zero
    
    /// Current mouse position
    private var currentPosition: CGPoint = .zero
    
    /// Last mouse button state (down/up)
    private var isMouseDown: Bool = false
    
    /// Private initializer for singleton
    private init() {}
    
    /// Process a touch event
    /// - Parameter touchEvent: The touch event to process
    public func processTouchEvent(_ touchEvent: [String: Any]) {
        guard isEnabled else { return }
        
        // Extract event data
        guard let eventData = touchEvent["event"] as? [String: Any],
              let typeString = eventData["type"] as? String,
              let percentX = eventData["percentX"] as? Double,
              let percentY = eventData["percentY"] as? Double else {
            print("Invalid touch event data")
            return
        }
        
        // Convert event type
        let eventType: String = typeString
        
        // Calculate absolute position in viewport
        let x = viewportBounds.origin.x + (viewportBounds.width * CGFloat(percentX))
        let y = viewportBounds.origin.y + (viewportBounds.height * CGFloat(percentY))
        let position = CGPoint(x: x, y: y)
        
        // Store current position
        currentPosition = position
        
        // Process based on event type
        switch eventType {
        case "began":
            simulateMouseDown(at: position)
            isMouseDown = true
        case "moved":
            if isMouseDown {
                simulateMouseDragged(to: position)
            } else {
                simulateMouseMoved(to: position)
            }
        case "ended", "cancelled":
            if isMouseDown {
                simulateMouseUp(at: position)
                isMouseDown = false
            }
        default:
            print("Unknown touch event type: \(eventType)")
        }
    }
    
    /// Simulate a mouse down event
    /// - Parameter position: Screen position
    private func simulateMouseDown(at position: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: position, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }
    
    /// Simulate a mouse move event
    /// - Parameter position: Screen position
    private func simulateMouseMoved(to position: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: position, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }
    
    /// Simulate a mouse drag event
    /// - Parameter position: Screen position
    private func simulateMouseDragged(to position: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                           mouseCursorPosition: position, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }
    
    /// Simulate a mouse up event
    /// - Parameter position: Screen position
    private func simulateMouseUp(at position: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                           mouseCursorPosition: position, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }
} 