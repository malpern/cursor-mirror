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
    }
    
    public func showViewport() {
        if window == nil {
            // Create the window only once
            guard let viewFactory = viewFactory else {
                print("No view factory provided")
                return
            }
            
            // Create the viewport view using the factory
            let viewportView = NSHostingView(rootView: viewFactory()
                .environmentObject(self))
            
            let window = NSWindow(
                contentRect: NSRect(x: position.x, y: position.y, width: Self.viewportSize.width, height: Self.viewportSize.height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            window.contentView = viewportView
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .moveToActiveSpace]
            window.ignoresMouseEvents = false
            
            self.window = window
        }
        
        window?.setFrameOrigin(position)
        window?.makeKeyAndOrderFront(nil)
        isVisible = true
    }
    
    public func hideViewport() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    public func updatePosition(to point: CGPoint) {
        position = point
        window?.setFrameOrigin(position)
    }
} 