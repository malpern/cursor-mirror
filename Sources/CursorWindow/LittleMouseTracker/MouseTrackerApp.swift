import SwiftUI
import AppKit

// New BorderedBox view
struct BorderedBoxWindow: View {
    @Binding var isHovering: Bool
    
    // Base dimensions
    private let baseWidth: CGFloat = 290
    private let baseHeight: CGFloat = 595
    private let normalBorderWidth: CGFloat = 5
    private let hoveredBorderWidth: CGFloat = 10
    
    var body: some View {
        // iPhone outline only - no dynamic island
        RoundedRectangle(cornerRadius: 55)
            .strokeBorder(Color.blue, lineWidth: isHovering ? hoveredBorderWidth : normalBorderWidth)
            .frame(width: baseWidth, height: baseHeight)
            .background(Color.clear)
            .animation(.easeInOut(duration: 0.2), value: isHovering) // Animate the border thickness change
    }
}

// Custom window class for handling mouse events with command key
class DraggableWindow: NSWindow {
    private var isDragging = false
    private var initialMouseLocationScreen: NSPoint = .zero
    private var initialWindowLocation: NSPoint = .zero
    private let borderThickness: CGFloat = 5.0
    private let cornerRadius: CGFloat = 55.0
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Set up the window
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating + 1
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = event.locationInWindow
        if isPointOnOutline(point) || event.modifierFlags.contains(.command) {
            isDragging = true
            initialMouseLocationScreen = NSEvent.mouseLocation
            initialWindowLocation = self.frame.origin
        } else {
            // Pass through clicks in the center area
            if let nextWindow = NSApp.windows.first(where: { $0 != self && $0.frame.contains(NSEvent.mouseLocation) }) {
                nextWindow.sendEvent(event)
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        
        // Get current mouse position in screen coordinates
        let currentMouseLocationScreen = NSEvent.mouseLocation
        
        // Calculate delta from initial mouse position in screen coordinates
        let deltaX = currentMouseLocationScreen.x - initialMouseLocationScreen.x
        let deltaY = currentMouseLocationScreen.y - initialMouseLocationScreen.y
        
        // Apply delta to original window position
        let newX = initialWindowLocation.x + deltaX
        let newY = initialWindowLocation.y + deltaY
        
        // Set new position directly
        self.setFrameOrigin(NSPoint(x: newX, y: newY))
    }
    
    override func mouseUp(with event: NSEvent) {
        if !isDragging && !isPointOnOutline(event.locationInWindow) {
            // Pass through clicks in the center area
            if let nextWindow = NSApp.windows.first(where: { $0 != self && $0.frame.contains(NSEvent.mouseLocation) }) {
                nextWindow.sendEvent(event)
            }
        }
        isDragging = false
    }
    
    // Check if a point is on the outline of the rounded rectangle
    private func isPointOnOutline(_ point: NSPoint) -> Bool {
        // Get frame in local coordinates (0,0 to width,height)
        let contentFrame = NSRect(x: 0, y: 0, width: self.frame.size.width, height: self.frame.size.height)
        
        // Create outer and inner rects for the click target zone
        let outerRect = NSRect(
            x: 0,  // Keep within window bounds
            y: 0,
            width: contentFrame.width,
            height: contentFrame.height
        )
        
        let innerRect = NSRect(
            x: borderThickness + 10,  // Add 10px inside the border
            y: borderThickness + 10,
            width: contentFrame.width - (2 * (borderThickness + 10)),
            height: contentFrame.height - (2 * (borderThickness + 10))
        )
        
        // Point is in click target if it's in the outer rect but not in the inner rect
        return outerRect.contains(point) && !innerRect.contains(point)
    }
}

struct MouseTrackerApp: App {
    @State private var mouseLocation = NSPoint.zero
    @State private var isHovering = false
    @State private var boxWindow: NSWindow?
    @State private var coordWindow: NSWindow?
    @State private var borderedBoxWindow: DraggableWindow?
    
    // Box dimensions and position
    @State private var boxOrigin = CGPoint.zero
    private let boxSize = CGSize(width: 290, height: 595)
    
    var body: some Scene {
        WindowGroup {
            EmptyView().hidden()
                .onAppear {
                    setupWindows()
                    startMouseTracking()
                    
                    // Hide the default window
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "LittleMouseTracker" }) {
                        window.close()
                    }
                }
        }
    }
    
    private func setupWindows() {
        // Box window setup
        let boxView = BoxWindow(mouseLocation: $mouseLocation)
        let boxHostingController = NSHostingController(rootView: boxView)
        boxWindow = NSWindow(contentViewController: boxHostingController)
        boxWindow?.styleMask = []
        boxWindow?.backgroundColor = .clear
        boxWindow?.isOpaque = false
        boxWindow?.level = .floating
        boxWindow?.ignoresMouseEvents = true
        boxWindow?.setFrame(NSScreen.main?.frame ?? .zero, display: true)
        boxWindow?.orderFront(nil)
        
        // Coordinate window setup
        let coordView = CoordinateWindow(mouseLocation: $mouseLocation, isHovering: $isHovering)
        let coordHostingController = NSHostingController(rootView: coordView)
        coordWindow = NSWindow(contentViewController: coordHostingController)
        coordWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable, .borderless]
        coordWindow?.backgroundColor = .white
        coordWindow?.level = .floating
        coordWindow?.setContentSize(NSSize(width: 250, height: 120))
        coordWindow?.title = "Mouse Tracker"
        
        // Position the window higher on screen to avoid overlap
        if let screen = NSScreen.main {
            let screenHeight = screen.frame.height
            let windowX = (screen.frame.width - 250) / 2
            let windowY = screenHeight - 200 // Position higher on screen
            coordWindow?.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        } else {
            coordWindow?.center()
        }
        
        coordWindow?.orderFront(nil)
        coordWindow?.isMovableByWindowBackground = true
        
        // Bordered box window setup
        let borderedBoxView = BorderedBoxWindow(isHovering: $isHovering)
        let borderedBoxHostingController = NSHostingController(rootView: borderedBoxView)
        
        // Use custom window class for cmd+drag functionality
        borderedBoxWindow = DraggableWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: boxSize.width, height: boxSize.height)),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        
        borderedBoxWindow?.contentViewController = borderedBoxHostingController
        borderedBoxWindow?.backgroundColor = .clear
        borderedBoxWindow?.isOpaque = false
        borderedBoxWindow?.level = .floating + 1  // Above other floating windows
        borderedBoxWindow?.hasShadow = false
        
        // Center the bordered box in the screen
        if let screen = NSScreen.main {
            let screenSize = screen.frame.size
            boxOrigin = CGPoint(
                x: (screenSize.width - boxSize.width) / 2,
                y: (screenSize.height - boxSize.height) / 2
            )
            borderedBoxWindow?.setFrame(CGRect(origin: boxOrigin, size: boxSize), display: true)
        }
        
        borderedBoxWindow?.orderFront(nil)
    }
    
    private func startMouseTracking() {
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { event in
            let point = NSEvent.mouseLocation
            mouseLocation = point
            
            // Check if the mouse is inside the blue box
            let isInBox = isPointInBox(point)
            if isInBox != isHovering {
                isHovering = isInBox
            }
        }
    }
    
    private func isPointInBox(_ point: NSPoint) -> Bool {
        if let frame = borderedBoxWindow?.frame {
            return frame.contains(point)
        }
        return false
    }
}

// Global state management
class AppState: ObservableObject {
    @Published var mouseLocation: CGPoint = .zero
    @Published var isHovering: Bool = false
} 