import SwiftUI
import AppKit

struct ViewportSize {
    static let width: CGFloat = 393
    static let height: CGFloat = 852
    static let strokeWidth: CGFloat = 5
    static let cornerRadius: CGFloat = 55  // iPhone 15 Pro corner radius
}

struct DraggableViewport: View {
    @StateObject var viewportState = ViewportState()
    
    // Constants for the glow effect
    private let glowOpacity: Double = 0.8
    private let glowRadius: CGFloat = 15
    private let glowWidth: CGFloat = 5
    private let hitTestingBuffer: CGFloat = 60  // Buffer zone for dragging
    
    var body: some View {
        ZStack {
            // Invisible hit testing area that extends inside and outside
            RoundedRectangle(cornerRadius: ViewportSize.cornerRadius)
                .fill(Color.clear)
                .frame(
                    width: ViewportSize.width + hitTestingBuffer * 2,
                    height: ViewportSize.height + hitTestingBuffer * 2
                )
                .contentShape(Rectangle())
                .offset(viewportState.offset)
            
            // Center area that allows click-through
            RoundedRectangle(cornerRadius: ViewportSize.cornerRadius)
                .fill(Color.clear)
                .frame(
                    width: ViewportSize.width - hitTestingBuffer * 2,
                    height: ViewportSize.height - hitTestingBuffer * 2
                )
                .contentShape(Rectangle())
                .allowsHitTesting(false)
                .offset(viewportState.offset)
            
            // Glow effect
            RoundedRectangle(cornerRadius: ViewportSize.cornerRadius)
                .strokeBorder(Color.blue.opacity(glowOpacity), lineWidth: glowWidth)
                .blur(radius: glowRadius)
                .frame(
                    width: ViewportSize.width + glowRadius * 2,
                    height: ViewportSize.height + glowRadius * 2
                )
                .offset(viewportState.offset)
                .allowsHitTesting(false)
            
            // Main viewport border
            RoundedRectangle(cornerRadius: ViewportSize.cornerRadius)
                .strokeBorder(Color.blue, lineWidth: ViewportSize.strokeWidth)
                .frame(width: ViewportSize.width, height: ViewportSize.height)
                .offset(viewportState.offset)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(DragGesture()
            .onChanged { gesture in
                viewportState.updateOffset(with: gesture.translation)
            }
            .onEnded { _ in
                viewportState.finalizeDrag()
            }
        )
    }
}

@MainActor
final class ViewportState: ObservableObject {
    @Published var offset: CGSize = .zero
    private var previousOffset: CGSize = .zero
    
    private var screenBounds: CGRect {
        NSScreen.main?.visibleFrame ?? .zero
    }
    
    func updateOffset(with translation: CGSize) {
        let proposedOffset = CGSize(
            width: translation.width + previousOffset.width,
            height: translation.height + previousOffset.height
        )
        
        // Calculate the viewport bounds
        let viewportWidth = ViewportSize.width
        let viewportHeight = ViewportSize.height
        
        // Calculate maximum allowed offsets to keep viewport on screen
        let maxX = (screenBounds.width - viewportWidth) / 2
        let maxY = (screenBounds.height - viewportHeight) / 2
        
        // Constrain the offset within screen bounds
        offset = CGSize(
            width: max(-maxX, min(maxX, proposedOffset.width)),
            height: max(-maxY, min(maxY, proposedOffset.height))
        )
    }
    
    func finalizeDrag() {
        previousOffset = offset
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        
        // Create and configure window
        if let screen = NSScreen.main {
            // Create window that covers the entire screen
            let window = NSWindow(
                contentRect: screen.visibleFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            // Make window transparent and borderless
            window.backgroundColor = NSColor.clear
            window.isOpaque = false
            window.hasShadow = false
            
            // Set window level and behavior for proper app switching
            window.level = NSWindow.Level.floating
            
            // Make window visible in all spaces and allow proper app switching
            window.collectionBehavior = [
                NSWindow.CollectionBehavior.canJoinAllSpaces,
                NSWindow.CollectionBehavior.fullScreenAuxiliary,
                NSWindow.CollectionBehavior.participatesInCycle
            ]
            
            // Create the SwiftUI view
            let contentView = DraggableViewport()
                .background(Color.clear)
            
            // Create the NSHostingView with click-through background
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = screen.visibleFrame
            
            // Enable mouse moved events for better interaction
            window.acceptsMouseMovedEvents = true
            
            // Set the content view
            window.contentView = hostingView
            
            // Store window reference
            self.window = window
            
            // Show the window
            window.makeKeyAndOrderFront(self)
        }
    }
    
    private func buildMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Cursor Window")
        appMenuItem.submenu = appMenu
        
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitMenuItem)
        
        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }
}

struct CursorMirrorApp: App {
    var body: some Scene {
        WindowGroup {
            Color.clear
        }
    }
} 