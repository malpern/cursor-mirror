import SwiftUI
import AppKit

// Custom window class for handling mouse events with command key
private class DraggableWindow: NSWindow {
    private var isDragging = false
    private var initialMouseLocationScreen: NSPoint = .zero
    private var initialWindowLocation: NSPoint = .zero
    private let borderThickness: CGFloat = 5.0
    private let cornerRadius: CGFloat = 55.0
    weak var viewportManager: ViewportManager?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Set up the window
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating + 1
        
        // Enable mouse moved events
        self.acceptsMouseMovedEvents = true
        
        // Set up mouse monitoring
        setupMouseMonitoring()
    }
    
    deinit {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupMouseMonitoring() {
        // Monitor global mouse movements (when window doesn't have focus)
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            guard let self = self else { return }
            self.handleMouseMovement(NSEvent.mouseLocation)
        }
        
        // Monitor local mouse movements (when window has focus)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [weak self] event in
            guard let self = self else { return event }
            
            // Handle the mouse movement
            self.handleMouseMovement(NSEvent.mouseLocation)
            
            // Return the event for normal processing
            return event
        }
    }
    
    private func handleMouseMovement(_ location: NSPoint) {
        let frame = self.frame
        let isInBox = frame.contains(location)
        
        // Update hover state on main thread
        DispatchQueue.main.async { [weak self] in
            if self?.viewportManager?.isHovering != isInBox {
                self?.viewportManager?.isHovering = isInBox
            }
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        handleMouseMovement(NSEvent.mouseLocation)
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
            x: 0,
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

@available(macOS 14.0, *)
public class ViewportManager: ObservableObject, ViewportManagerProtocol {
    // UserDefaults keys
    private enum UserDefaultsKeys {
        static let viewportPositionX = "com.cursor-window.viewport.position.x"
        static let viewportPositionY = "com.cursor-window.viewport.position.y"
        static let viewportWasVisible = "com.cursor-window.viewport.wasVisible"
    }
    
    @Published public var isVisible = false
    @Published public var position = CGPoint(x: 100, y: 100)
    @Published public var isHovering = false
    
    public static let viewportSize = CGSize(
        width: 393,  // iPhone 15 Pro width
        height: 852  // iPhone 15 Pro height
    )
    
    private var window: DraggableWindow?
    private var viewFactory: (() -> AnyView)?
    
    public init(viewFactory: @escaping () -> AnyView) {
        self.viewFactory = viewFactory
        
        // Restore position from UserDefaults if available
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.viewportPositionX) != nil {
            let positionX = UserDefaults.standard.double(forKey: UserDefaultsKeys.viewportPositionX)
            let positionY = UserDefaults.standard.double(forKey: UserDefaultsKeys.viewportPositionY)
            self.position = CGPoint(x: positionX, y: positionY)
        }
        
        // Always start with viewport hidden
        self.isVisible = false
        // Clear any previous visibility state
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.viewportWasVisible)
    }
    
    public func showViewport() {
        print("DEBUG: showViewport() called")
        // Ensure we're on the main thread for UI operations
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("DEBUG: self was deallocated in showViewport")
                return
            }
            
            self.createWindow()
            
            self.isVisible = true
            print("DEBUG: isVisible set to true")
            
            // Save state - explicitly persist position
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.viewportWasVisible)
            UserDefaults.standard.set(self.position.x, forKey: UserDefaultsKeys.viewportPositionX)
            UserDefaults.standard.set(self.position.y, forKey: UserDefaultsKeys.viewportPositionY)
            print("DEBUG: State saved to UserDefaults")
        }
    }
    
    public func hideViewport() {
        print("DEBUG: hideViewport() called")
        window?.orderOut(nil)
        isVisible = false
        print("DEBUG: Window hidden and isVisible set to false")
        
        // Save state
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.viewportWasVisible)
        print("DEBUG: State saved to UserDefaults")
    }
    
    public func updateWindowPosition(to point: CGPoint, useAnimation: Bool = false) {
        // Get the main screen's visible frame
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        
        // Ensure the point is within screen bounds
        let maxX = screenFrame.maxX - Self.viewportSize.width
        let maxY = screenFrame.maxY - Self.viewportSize.height
        let minX = screenFrame.minX
        let minY = screenFrame.minY
        
        let boundedX = min(max(point.x, minX), maxX)
        let boundedY = min(max(point.y, minY), maxY)
        
        // Make sure the window moves to the exact position
        if let window = self.window {
            if useAnimation {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.0
                    window.setFrameOrigin(NSPoint(x: boundedX, y: boundedY))
                }
            } else {
                // Direct position update without animation
                window.setFrameOrigin(NSPoint(x: boundedX, y: boundedY))
            }
        }
    }
    
    public func updatePosition(to point: CGPoint, persistPosition: Bool = false, useAnimation: Bool = true) {
        // Get the main screen's visible frame
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        
        // Ensure the point is within screen bounds
        let maxX = screenFrame.maxX - Self.viewportSize.width
        let maxY = screenFrame.maxY - Self.viewportSize.height
        let minX = screenFrame.minX
        let minY = screenFrame.minY
        
        let boundedX = min(max(point.x, minX), maxX)
        let boundedY = min(max(point.y, minY), maxY)
        
        // Update the position property
        position = CGPoint(x: boundedX, y: boundedY)
        
        // Update window position
        updateWindowPosition(to: position, useAnimation: useAnimation)
        
        // Save position if requested
        if persistPosition {
            UserDefaults.standard.set(position.x, forKey: UserDefaultsKeys.viewportPositionX)
            UserDefaults.standard.set(position.y, forKey: UserDefaultsKeys.viewportPositionY)
        }
    }
    
    private func createWindow() {
        print("DEBUG: Creating window if needed. Current window: \(String(describing: window))")
        
        if window == nil {
            print("DEBUG: Creating new window")
            
            // Create a new draggable window
            let window = DraggableWindow(
                contentRect: NSRect(
                    x: position.x,
                    y: position.y,
                    width: Self.viewportSize.width,
                    height: Self.viewportSize.height
                ),
                styleMask: [],
                backing: .buffered,
                defer: false
            )
            
            if let factory = viewFactory {
                // Set the content view
                let contentView = NSHostingView(rootView: factory())
                window.contentView = contentView
                
                // Set up window-manager relationship
                window.viewportManager = self
                
                self.window = window
                print("DEBUG: Window created successfully")
            }
        }
        
        // Position the window
        if let window = window {
            print("DEBUG: Setting window position to \(position)")
            window.setFrameOrigin(position)
            window.orderFront(nil)
        }
    }
} 