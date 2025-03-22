import SwiftUI
import AppKit
import CursorWindowCore
import Foundation
#if canImport(Darwin)
import Darwin.POSIX
#endif

@available(macOS 14.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var viewportManager: ViewportManager?
    private var screenCaptureManager: ScreenCaptureManager?
    private var mainWindow: NSWindow?
    private var startupTask: Task<Void, Never>?
    private let lockFile = "/tmp/cursor-window.lock"
    private var lockFileDescriptor: Int32 = -1
    
    deinit {
        cleanupLockFile()
    }
    
    private func cleanupLockFile() {
        if lockFileDescriptor != -1 {
            close(lockFileDescriptor)
            lockFileDescriptor = -1
        }
        try? FileManager.default.removeItem(atPath: lockFile)
    }
    
    private func acquireLockFile() -> Bool {
        let fileManager = FileManager.default
        
        // Remove stale lock file if it exists
        if fileManager.fileExists(atPath: lockFile) {
            if let attributes = try? fileManager.attributesOfItem(atPath: lockFile),
               let modificationDate = attributes[.modificationDate] as? Date,
               Date().timeIntervalSince(modificationDate) > 5 {
                try? fileManager.removeItem(atPath: lockFile)
            }
        }
        
        // Try to create and lock the file
        guard fileManager.createFile(atPath: lockFile, contents: Data("\(ProcessInfo.processInfo.processIdentifier)".utf8)) else {
            return false
        }
        
        // Open the file and try to acquire an exclusive lock
        lockFileDescriptor = open(lockFile, O_WRONLY | O_NONBLOCK)
        
        guard lockFileDescriptor != -1 else {
            try? fileManager.removeItem(atPath: lockFile)
            return false
        }
        
        let result = flock(lockFileDescriptor, LOCK_EX | LOCK_NB)
        if result != 0 {
            close(lockFileDescriptor)
            lockFileDescriptor = -1
            try? fileManager.removeItem(atPath: lockFile)
            return false
        }
        
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Debug print bundle identifier and PID
        print("App starting with PID: \(ProcessInfo.processInfo.processIdentifier)")
        
        // Try to acquire the lock file
        if !acquireLockFile() {
            print("Lock file exists and is locked. Another instance may be running.")
            
            // Show alert to user about potential other instance
            let alert = NSAlert()
            alert.messageText = "Cursor Window May Already Be Running"
            alert.informativeText = "Another instance appears to be running. Look for 'CW' in your menu bar. Would you like to force start a new instance?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Force Start")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertSecondButtonReturn {
                print("User chose to cancel startup.")
                NSApp.terminate(nil)
                return
            }
            
            print("User chose to force start. Continuing with startup...")
        }
        
        // Make app appear in dock and force activation to ensure it's visible
        NSApp.setActivationPolicy(.regular)
        
        // Show the dock icon with bouncing to attract attention
        NSApp.requestUserAttention(.criticalRequest)
        
        // Initialize managers with a timeout safeguard
        startupTask = Task { @MainActor in
            // Set up watchdog timer to prevent hanging
            let watchdogTask = Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 second timeout
                if !Task.isCancelled {
                    print("Startup watchdog triggered - app may be hanging. Forcing termination.")
                    exit(1) // Force quit if startup takes too long
                }
            }
            
            do {
                // Initialize the screen capture manager
                self.screenCaptureManager = ScreenCaptureManager()
                
                // Check permission status first with timeout
                try await withTimeout(seconds: 5) {
                    await self.screenCaptureManager?.forceRefreshPermissionStatus()
                }
                
                // Initialize the viewport manager with a factory for our overlay view
                viewportManager = ViewportManager(viewFactory: { 
                    AnyView(ViewportOverlayView())
                })
                
                // Create a popover for the menu bar
                let popover = NSPopover()
                let contentView = MenuBarView()
                    .environmentObject(viewportManager!)
                    .environmentObject(screenCaptureManager!)
                
                popover.contentViewController = NSHostingController(rootView: contentView)
                popover.behavior = .transient
                
                // Create the status bar controller with our popover
                statusBarController = StatusBarController(popover: popover)
                
                // Ensure app is active and visible
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
                
                // Only show welcome window and permission dialog if needed
                let hasPermission = self.screenCaptureManager?.isScreenCapturePermissionGranted ?? false
                if !hasPermission {
                    // Show permission dialog on main thread to avoid blocking
                    DispatchQueue.main.async {
                        self.showPermissionAlert()
                    }
                }
                
                // Create the main window - always show it at startup for better visibility
                try await createMainWindow()
                
                // Add a slight delay before showing a notification about menu bar presence
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                showMenuBarAlert()
                
                // Cancel the watchdog since startup completed successfully
                watchdogTask.cancel()
            } catch {
                print("Error during app startup: \(error)")
                DispatchQueue.main.async {
                    self.showFatalErrorAlert(error: error)
                }
            }
        }
    }
    
    private func showMenuBarAlert() {
        // Show an alert instead of a notification
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Cursor Window is running"
            alert.informativeText = "Look for 📱CW in your menu bar at the top of the screen"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        print("Menu bar alert shown. Look for 'CW' in your menu bar.")
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Cursor Window needs screen recording permission to function. Please grant it in System Settings > Privacy & Security > Screen Recording."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }
    
    private func showFatalErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Fatal Error"
        alert.informativeText = "CursorWindow encountered a critical error: \(error.localizedDescription)\n\nThe application will now quit."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }
    
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                return try await operation()
            }
            
            // Add a timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "com.cursor-window", code: 408, 
                              userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            // Return the first task to complete (operation or timeout)
            let result = try await group.next()!
            // Cancel the remaining task
            group.cancelAll()
            return result
        }
    }
    
    @MainActor
    private func createMainWindow() async throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        let hasPermission = self.screenCaptureManager?.isScreenCapturePermissionGranted ?? false
        
        window.title = "Cursor Window"
        window.contentView = NSHostingView(rootView: 
            VStack {
                Text("Cursor Window")
                    .font(.largeTitle)
                Text("The app is running in your menu bar.")
                    .font(.subheadline)
                Text("Look for 📱CW in your menu bar at the top-right of your screen.")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer().frame(height: 20)
                
                if hasPermission {
                    Text("Screen recording permission granted ✅")
                        .foregroundColor(.green)
                        .padding(.bottom, 8)
                } else {
                    Text("Screen recording permission not granted ⚠️")
                        .foregroundColor(.orange)
                        .padding(.bottom, 8)
                    
                    Button("Request Permission") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                    }
                    .padding(.bottom, 8)
                }
                
                Text("You can close this window - the app will keep running in the menu bar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Quit Application") {
                    NSApp.terminate(nil)
                }
                .padding(.top, 10)
            }
            .padding()
        )
        
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cleanupLockFile()
        
        // Cancel any pending startup tasks
        startupTask?.cancel()
        
        // Clean up resources with a timeout to prevent hanging
        Task {
            do {
                try await withTimeout(seconds: 2) {
                    try? await self.screenCaptureManager?.stopCapture()
                }
            } catch {
                print("Timeout during cleanup: \(error)")
            }
        }
    }
} 