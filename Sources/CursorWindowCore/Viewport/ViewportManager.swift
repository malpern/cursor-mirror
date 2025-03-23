import SwiftUI
import AppKit

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
    public static let viewportSize = CGSize(
        width: 393,  // iPhone 15 Pro width
        height: 852  // iPhone 15 Pro height
    )
    
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
            
            // Create a new panel
            let panel = NSPanel(
                contentRect: NSRect(
                    x: position.x,
                    y: position.y,
                    width: Self.viewportSize.width,
                    height: Self.viewportSize.height
                ),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            if let factory = viewFactory {
                // Configure panel properties
                panel.level = .floating
                panel.collectionBehavior = [.canJoinAllSpaces]
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false
                panel.isMovable = true
                panel.isMovableByWindowBackground = true
                panel.acceptsMouseMovedEvents = true
                
                // Configure panel behavior
                panel.becomesKeyOnlyIfNeeded = false
                panel.worksWhenModal = true
                panel.isFloatingPanel = true
                
                // Set the content view
                let contentView = NSHostingView(rootView: factory())
                panel.contentView = contentView
                
                window = panel
                print("DEBUG: Panel created successfully")
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