import SwiftUI
import AppKit

@available(macOS 14.0, *)
class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: EventMonitor?
    
    init(popover: NSPopover) {
        self.popover = popover
        
        // Use a fixed length instead of square length for better visibility
        self.statusItem = NSStatusBar.system.statusItem(withLength: 40)
        
        setupStatusBarItem()
        setupEventMonitor()
        
        // Log status bar creation
        print("StatusBarController initialized")
    }
    
    deinit {
        // Remove event monitor when controller is deallocated
        eventMonitor?.stop()
    }
    
    private func setupStatusBarItem() {
        if let button = statusItem.button {
            // Use a very simple, guaranteed-to-work approach first
            button.title = "📱CW"
            button.action = #selector(togglePopover(_:))
            button.target = self
            
            // Add a tooltip to help identify the app
            button.toolTip = "Cursor Window - Click to toggle viewport"
            
            print("Status bar item created with simple text: 📱CW")
            
            // Try to add an icon if available, but keep the text as backup
            if let image = NSImage(systemSymbolName: "iphone.gen3.circle.fill", accessibilityDescription: "Cursor Mirror") {
                let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold)
                    .applying(.init(paletteColors: [.systemBlue]))
                
                button.image = image.withSymbolConfiguration(config)
                button.imagePosition = .imageLeading
                
                print("Added icon to status bar item")
            }
        } else {
            print("Failed to get status item button")
            
            // Try a fallback approach - create again with a different length
            self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            if let button = statusItem.button {
                button.title = "📱CW"
                button.action = #selector(togglePopover(_:))
                button.target = self
                print("Created fallback status bar item")
            } else {
                print("CRITICAL ERROR: Unable to create status bar item after fallback attempt")
            }
        }
    }
    
    private func setupEventMonitor() {
        // Create event monitor to close popover when clicking outside of it
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            self.closePopover(nil)
        }
        eventMonitor?.start()
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    private func showPopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Use a safer way to display popover with error handling
        DispatchQueue.main.async {
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    private func closePopover(_ sender: AnyObject?) {
        // Use a safer way to close popover with error handling
        DispatchQueue.main.async {
            self.popover.performClose(sender)
        }
    }
}

// Event monitor to handle clicks outside the popover
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
} 