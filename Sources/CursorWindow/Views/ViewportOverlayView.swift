import SwiftUI
import AppKit
import CursorWindowCore

@available(macOS 14.0, *)
struct ViewportOverlayView: View {
    @ObservedObject var viewportManager: ViewportManager
    @State private var viewUpdateCount: Int = 0
    
    // Constants for visual appearance
    private let cornerRadius: CGFloat = 8
    private let strokeWidth: CGFloat = 2
    private let glowWidth: CGFloat = 4
    private let glowRadius: CGFloat = 8
    private let glowOpacity: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            // Transparent background
            Color.clear
                .onAppear {
                    print("DEBUG: ViewportOverlayView body redraw #\(viewUpdateCount)")
                    viewUpdateCount += 1
                }
            
            // Glow effect
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.blue.opacity(glowOpacity), lineWidth: glowWidth)
                .blur(radius: glowRadius)
                .frame(
                    width: ViewportManager.viewportSize.width,
                    height: ViewportManager.viewportSize.height
                )
            
            // Main viewport border
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.blue, lineWidth: strokeWidth)
                .frame(
                    width: ViewportManager.viewportSize.width,
                    height: ViewportManager.viewportSize.height
                )
                
            // Debug coordinates
            #if DEBUG
            VStack {
                Spacer()
                Text("Position: \(Int(viewportManager.position.x)), \(Int(viewportManager.position.y))")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
            }
            .frame(width: ViewportManager.viewportSize.width, height: ViewportManager.viewportSize.height)
            #endif
        }
        .contentShape(Rectangle())
        .background(WindowDragHandler(viewportManager: viewportManager))
    }
}

// Native window drag handler
struct WindowDragHandler: NSViewRepresentable {
    @ObservedObject var viewportManager: ViewportManager
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
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