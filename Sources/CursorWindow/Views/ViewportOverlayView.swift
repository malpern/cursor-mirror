import SwiftUI
import AppKit
import CursorWindowCore

@available(macOS 14.0, *)
struct ViewportOverlayView: View {
    @ObservedObject var viewportManager: ViewportManager
    @State private var viewUpdateCount: Int = 0
    
    // iPhone 15 Pro dimensions and appearance
    private let cornerRadius: CGFloat = 47 // iPhone 15 Pro corner radius
    private let strokeWidth: CGFloat = 4 // Increased from 2 to 4
    private let glowWidth: CGFloat = 6
    private let glowRadius: CGFloat = 12
    private let glowOpacity: CGFloat = 0.4
    
    var body: some View {
        ZStack {
            // Transparent background
            Color.clear
                .onAppear {
                    print("DEBUG: ViewportOverlayView body redraw #\(viewUpdateCount)")
                    viewUpdateCount += 1
                }
            
            // Outer glow effect
            RoundedRectangle(cornerRadius: cornerRadius + glowWidth/2)
                .stroke(Color.blue.opacity(glowOpacity), lineWidth: glowWidth)
                .blur(radius: glowRadius)
                .frame(
                    width: ViewportManager.viewportSize.width + glowWidth,
                    height: ViewportManager.viewportSize.height + glowWidth
                )
                .allowsHitTesting(false) // Make glow non-interactive
            
            // Main viewport border - only this should be interactive
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.blue, lineWidth: strokeWidth)
                .frame(
                    width: ViewportManager.viewportSize.width,
                    height: ViewportManager.viewportSize.height
                )
        }
        .contentShape(.interaction, RoundedRectangle(cornerRadius: cornerRadius).stroke(lineWidth: strokeWidth))
        .background(ClickThroughHandler(viewportManager: viewportManager))
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