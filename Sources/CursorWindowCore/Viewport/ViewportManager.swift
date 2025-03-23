import SwiftUI
import AppKit

@available(macOS 14.0, *)
public class ViewportManager: ObservableObject {
    @Published public var isVisible = false
    @Published public var position = CGPoint(x: 100, y: 100)
    public static let viewportSize = CGSize(width: 393, height: 852)
    
    private var window: NSWindow?
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
            
            print("DEBUG: Creating window if needed. Current window: \(self.window == nil ? "nil" : "exists")")
            if self.window == nil {
                // Create the window only once
                guard let viewFactory = self.viewFactory else {
                    print("DEBUG: No view factory provided")
                    return
                }
                
                print("DEBUG: Creating new window")
                // Create the viewport view using the factory
                let viewportView = NSHostingView(rootView: viewFactory()
                    .environmentObject(self))
                
                // Get the main screen's visible frame
                let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
                
                // Calculate initial position to center on screen
                let initialX = screenFrame.midX - Self.viewportSize.width / 2
                let initialY = screenFrame.midY - Self.viewportSize.height / 2
                
                // Update position if it's the default position
                if self.position.x == 100 && self.position.y == 100 {
                    self.position = CGPoint(x: initialX, y: initialY)
                }
                
                // Ensure position is within screen bounds
                let maxX = screenFrame.maxX - Self.viewportSize.width
                let maxY = screenFrame.maxY - Self.viewportSize.height
                let minX = screenFrame.minX
                let minY = screenFrame.minY
                
                self.position.x = min(max(self.position.x, minX), maxX)
                self.position.y = min(max(self.position.y, minY), maxY)
                
                print("DEBUG: Creating window at position \(self.position)")
                
                let window = NSWindow(
                    contentRect: NSRect(x: self.position.x, y: self.position.y, width: Self.viewportSize.width, height: Self.viewportSize.height),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                
                window.contentView = viewportView
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = false
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces]
                window.ignoresMouseEvents = false
                window.isMovable = true
                window.isMovableByWindowBackground = true
                window.acceptsMouseMovedEvents = true
                
                self.window = window
                print("DEBUG: Window created successfully")
            }
            
            // Ensure window is positioned correctly
            self.window?.setFrameOrigin(self.position)
            print("DEBUG: Setting window position to \(self.position)")
            
            // Force window to front but don't make it key
            self.window?.orderFrontRegardless()
            print("DEBUG: Window ordered to front")
            
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
        
        // Only update if the position has actually changed
        if position.x != boundedX || position.y != boundedY {
            // Update the position state
            position = CGPoint(x: boundedX, y: boundedY)
            
            // Only save to UserDefaults when explicitly requested
            if persistPosition {
                UserDefaults.standard.set(boundedX, forKey: UserDefaultsKeys.viewportPositionX)
                UserDefaults.standard.set(boundedY, forKey: UserDefaultsKeys.viewportPositionY)
            }
        }
    }
} 