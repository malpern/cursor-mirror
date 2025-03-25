import SwiftUI
import AppKit
import CursorWindowCore

@available(macOS 14.0, *)
struct ViewportOverlayView: View {
    @ObservedObject var viewportManager: ViewportManager
    @State private var viewUpdateCount: Int = 0
    
    // Border appearance constants
    private let normalBorderWidth: CGFloat = 5
    private let hoveredBorderWidth: CGFloat = 10
    private let cornerRadius: CGFloat = 55
    
    var body: some View {
        // iPhone outline only - no dynamic island
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Color.blue, lineWidth: viewportManager.isHovering ? hoveredBorderWidth : normalBorderWidth)
            .frame(width: ViewportManager.viewportSize.width, height: ViewportManager.viewportSize.height)
            .background(Color.clear)
            .animation(.easeInOut(duration: 0.2), value: viewportManager.isHovering)
            .onAppear {
                print("DEBUG: ViewportOverlayView body redraw #\(viewUpdateCount)")
                viewUpdateCount += 1
            }
    }
}

// Handler for click-through and window dragging
struct ClickThroughHandler: NSViewRepresentable {
    @ObservedObject var viewportManager: ViewportManager
    
    func makeNSView(context: Context) -> NSView {
        let view = ClickThroughView()
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear
        
        // Add mouse tracking area
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: view,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
        
        // Set up window dragging
        view.window?.isMovable = true
        view.window?.isMovableByWindowBackground = true
        view.window?.acceptsMouseMovedEvents = true
        
        // Add observer for window movement
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: view.window,
            queue: .main
        ) { _ in
            if let window = view.window {
                viewportManager.updatePosition(
                    to: window.frame.origin,
                    persistPosition: false,
                    useAnimation: false
                )
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update tracking area if needed
        if let trackingArea = nsView.trackingAreas.first {
            nsView.removeTrackingArea(trackingArea)
        }
        
        let newTrackingArea = NSTrackingArea(
            rect: nsView.bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: nsView,
            userInfo: nil
        )
        nsView.addTrackingArea(newTrackingArea)
    }
}

// Custom NSView that implements click-through behavior
class ClickThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Get the path of the border stroke
        let strokePath = NSBezierPath(roundedRect: bounds, xRadius: 47, yRadius: 47)
        let strokeWidth: CGFloat = 4
        let innerPath = NSBezierPath(roundedRect: bounds.insetBy(dx: strokeWidth, dy: strokeWidth), xRadius: 47 - strokeWidth, yRadius: 47 - strokeWidth)
        strokePath.append(innerPath)
        strokePath.windingRule = .evenOdd
        
        // Return self only if the click is on the border stroke
        // This allows dragging from the border while clicking through the center
        return strokePath.contains(point) ? self : nil
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override var isOpaque: Bool {
        return false
    }
} 