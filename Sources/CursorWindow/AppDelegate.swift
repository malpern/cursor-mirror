import AppKit
import SwiftUI
import CursorWindowCore

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    @MainActor private var screenCaptureManager: ScreenCaptureManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        
        Task { @MainActor in
            // Initialize the screen capture manager on the main actor
            screenCaptureManager = ScreenCaptureManager()
            
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
                    .environmentObject(screenCaptureManager!)
                
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