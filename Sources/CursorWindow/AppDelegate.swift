import SwiftUI
import AppKit
import Cocoa
import Combine
import CursorWindowCore
import Foundation
#if canImport(Darwin)
import Darwin.POSIX
#endif

@available(macOS 14.0, *)
class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var statusBarController: StatusBarController?
    private var viewportManager: ViewportManager? = nil
    private var screenCaptureManager: ScreenCaptureManager? = nil
    private var mainWindow: NSWindow?
    private var startupTask: Task<Void, Never>? = nil
    private let lockFile = "/tmp/cursor-window.lock"
    private var lockFileDescriptor: Int32 = -1
    private var isForceStarted = false
    
    deinit {
        // Release the lock file directly
        releaseLockFile()
    }
    
    private func acquireLockFile() -> Bool {
        let fileManager = FileManager.default
        let lockFile = "/tmp/cursor-window.lock"
        let currentPid = ProcessInfo.processInfo.processIdentifier
        
        print("Acquiring app lock for PID \(currentPid)")
        
        // Check if the lock file exists
        if fileManager.fileExists(atPath: lockFile) {
            do {
                // Try to read the PID from the file
                if let existingData = fileManager.contents(atPath: lockFile),
                   let existingPid = String(data: existingData, encoding: .utf8).flatMap({ Int32($0) }) {
                    
                    // Check if the process with that PID is still running
                    if kill(existingPid, 0) == 0 {
                        // Process exists, check if it's actually our app
                        let runningPidCmd = "ps -p \(existingPid) | grep -c CursorWindow"
                        let process = Process()
                        process.launchPath = "/bin/sh"
                        process.arguments = ["-c", runningPidCmd]
                        
                        let pipe = Pipe()
                        process.standardOutput = pipe
                        try process.run()
                        process.waitUntilExit()
                        
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
                        
                        if output != "0" {
                            // It's a real running instance of our app
                            print("Found genuine running instance with PID \(existingPid)")
                            return false
                        } else {
                            // Process exists but it's not our app - stale lock
                            print("Found process \(existingPid) but it's not CursorWindow")
                            try fileManager.removeItem(atPath: lockFile)
                        }
                    } else {
                        // Process doesn't exist, stale lock file
                        print("Process \(existingPid) no longer exists, removing stale lock")
                        try fileManager.removeItem(atPath: lockFile)
                    }
                } else {
                    // Invalid lock file content
                    print("Invalid lock file content, removing")
                    try fileManager.removeItem(atPath: lockFile)
                }
            } catch {
                print("Error checking lock file: \(error)")
                try? fileManager.removeItem(atPath: lockFile)
            }
        }
        
        // Now try to create our lock file
        if !fileManager.createFile(atPath: lockFile, contents: Data("\(currentPid)".utf8)) {
            print("Failed to create lock file")
            return false
        }
        
        // Open and lock the file
        lockFileDescriptor = open(lockFile, O_WRONLY)
        if lockFileDescriptor == -1 {
            print("Failed to open lock file: \(errno)")
            try? fileManager.removeItem(atPath: lockFile)
            return false
        }
        
        // Attempt to get an exclusive lock
        let lockResult = flock(lockFileDescriptor, LOCK_EX | LOCK_NB)
        if lockResult != 0 {
            print("Failed to lock file: \(errno)")
            close(lockFileDescriptor)
            lockFileDescriptor = -1
            return false
        }
        
        print("Successfully acquired lock file for PID \(currentPid)")
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Debug print bundle identifier and PID
        print("App starting with PID: \(ProcessInfo.processInfo.processIdentifier)")
        
        // Try to acquire the lock file
        if !acquireLockFile() {
            print("Lock file exists and is locked. Another instance is running.")
            
            // Show alert to user about potential other instance
            let alert = NSAlert()
            alert.messageText = "Cursor Window Is Already Running"
            alert.informativeText = "Another instance of Cursor Window is already running. Look for 'CW' in your menu bar. Attempting to activate the existing instance."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            
            alert.runModal()
            
            // Try to activate the existing instance
            let runningInstances = NSRunningApplication.runningApplications(
                withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.cursor-window"
            )
            runningInstances.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })?
                .activate(options: [.activateAllWindows])
            
            // Quit immediately without further cleanup (already handled by atexit handler)
            print("Terminating duplicate instance.")
            exit(0)
        }
        
        // Continue with normal app startup
        initializeApplication()
    }
    
    private func terminateImmediately() {
        // Clean exit without using NSApp.terminate which might trigger multiple termination events
        exit(0)
    }
    
    private func initializeApplication() {
        // Make app appear in dock and force activation to ensure it's visible
        NSApp.setActivationPolicy(.regular)
        
        // Show the dock icon with bouncing to attract attention
        NSApp.requestUserAttention(.criticalRequest)
        
        // Initialize managers with a timeout safeguard
        startupTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Execute on MainActor since we're handling UI
            await MainActor.run {
                // Set up UI components synchronously
                self.setupApplication()
            }
        }
    }
    
    @MainActor
    private func setupApplication() {
        // Set up watchdog timer to prevent hanging
        let watchdogTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 second timeout
            if !Task.isCancelled {
                print("Startup watchdog triggered - app may be hanging. Forcing termination.")
                exit(1) // Force quit if startup takes too long
            }
        }
        
        // Start the async initialization in a new task
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Initialize the screen capture manager
                self.screenCaptureManager = ScreenCaptureManager()
                
                // Check permission status first with timeout
                // This is the single source of truth for permission status
                try await withTimeout(seconds: 5) {
                    await self.screenCaptureManager?.forceRefreshPermissionStatus()
                }
                
                // Execute UI updates on the main actor
                await MainActor.run {
                    // Create the viewport manager first
                    let viewportManager = ViewportManager(viewFactory: { [weak self] in
                        guard let self = self else { return AnyView(EmptyView()) }
                        return AnyView(ViewportOverlayView(viewportManager: self.viewportManager!))
                    })
                    
                    // Assign it to self after creation
                    self.viewportManager = viewportManager
                    
                    // Create a popover for the menu bar
                    let popover = NSPopover()
                    let contentView = MenuBarView()
                        .environmentObject(self.viewportManager!)
                        .environmentObject(self.screenCaptureManager!)
                    
                    popover.contentViewController = NSHostingController(rootView: contentView)
                    popover.behavior = .transient
                    
                    // Create the status bar controller with our popover
                    self.statusBarController = StatusBarController(popover: popover)
                    
                    // Ensure app is active and visible
                    NSApp.activate()
                    
                    // Remove the automatic viewport restoration
                    // The viewport will now only show when the user explicitly enables it
                }
                
                // Create the main window - always show it at startup for better visibility
                try await createMainWindow()
                
                // Add a slight delay before showing a notification about menu bar presence
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    self.showMenuBarAlert()
                }
                
                // Cancel the watchdog since startup completed successfully
                watchdogTask.cancel()
            } catch {
                print("Error during app startup: \(error)")
                await MainActor.run {
                    self.showFatalErrorAlert(error: error)
                }
            }
        }
    }
    
    private func showMenuBarAlert() {
        // Just log to console without showing a dialog
        print("Cursor Window is now running in your menu bar. Look for 'CW' in your menu bar at the top of the screen.")
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
        
        _ = self.screenCaptureManager?.isScreenCapturePermissionGranted ?? false
        
        window.title = "Phone Mirror"
        
        // Create a SwiftUI view that observes the ViewportManager
        if let viewportManager = self.viewportManager,
           let screenCaptureManager = self.screenCaptureManager {
            let contentView = MainWindowView(
                viewportManager: viewportManager,
                screenCaptureManager: screenCaptureManager
            )
            window.contentView = NSHostingView(rootView: contentView)
        }
        
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window
    }
    
    private func releaseLockFile() {
        // The lock file path should match what we used in acquireLockFile
        let lockFile = "/tmp/cursor-window.lock"
        let pid = ProcessInfo.processInfo.processIdentifier
        
        print("Releasing lock file for PID \(pid)")
        
        if lockFileDescriptor != -1 {
            // First, unlock the file
            let unlockResult = flock(lockFileDescriptor, LOCK_UN)
            if unlockResult != 0 {
                print("Warning: Failed to unlock file: \(errno)")
            } else {
                print("Successfully unlocked file")
            }
            
            // Then close the file descriptor
            close(lockFileDescriptor)
            lockFileDescriptor = -1
            
            // Finally try to remove the file, but only if it belongs to us
            do {
                if let fileData = FileManager.default.contents(atPath: lockFile),
                   let filePidString = String(data: fileData, encoding: .utf8),
                   let filePid = Int(filePidString) {
                    
                    // Only remove if this is our lock file
                    if filePid == pid {
                        try FileManager.default.removeItem(atPath: lockFile)
                        print("Successfully removed lock file")
                    } else {
                        print("Lock file now belongs to PID \(filePid), not removing")
                    }
                } else {
                    print("Lock file contains invalid data, removing anyway")
                    try FileManager.default.removeItem(atPath: lockFile)
                }
            } catch {
                print("Error removing lock file: \(error)")
            }
        } else {
            print("No lock file descriptor to release")
        }
    }
    
    @MainActor
    private func cleanup() async {
        // Stop screen capture if running
        try? await screenCaptureManager?.stopCapture()
        
        // Stop HTTP server if running
        if let contentView = statusBarController?.popover.contentViewController as? NSHostingController<MenuBarView>,
           let serverManager = contentView.rootView.serverManager {
            // First stop streaming if active
            try? await serverManager.stopStreaming()
            
            // Then stop the server completely
            try? await serverManager.stop()
            print("HTTP server stopped during cleanup")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
        print("Application will terminate")
        
        // Run cleanup synchronously to ensure it completes before app exits
        Task {
            await cleanup()
            
            // Add a small delay to ensure cleanup tasks complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Release the lock file
        releaseLockFile()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Start pre-emptive cleanup of resources
        print("User initiated app termination")
        
        // Perform async cleanup in the background before terminating
        Task {
            print("Starting cleanup before termination")
            await cleanup()
            
            print("Cleanup complete, proceeding with termination")
            // Allow a small delay for tasks to complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Actually terminate the app after cleanup
            DispatchQueue.main.async {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        
        // Release the lock file
        releaseLockFile()
        
        // Return .terminateLater to allow our async cleanup to complete
        return .terminateLater
    }
}

// Move the window content to a separate SwiftUI view for better state management
@available(macOS 14.0, *)
private struct MainWindowView: View {
    @ObservedObject var viewportManager: ViewportManager
    let screenCaptureManager: ScreenCaptureManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Phone Mirror")
                .font(.largeTitle)
            
            Toggle("Show iPhone Frame", isOn: Binding(
                get: { viewportManager.isVisible },
                set: { newValue in
                    if newValue {
                        viewportManager.showViewport()
                    } else {
                        viewportManager.hideViewport()
                    }
                }
            ))
            .toggleStyle(.switch)
            
            if screenCaptureManager.isScreenCapturePermissionGranted {
                Text("Screen recording permission granted ✅")
                    .foregroundColor(.green)
                    .padding(.bottom, 8)
            } else {
                Text("Screen recording permission not granted ⚠️")
                    .foregroundColor(.orange)
                    .padding(.bottom, 8)
            }
            
            Text("Look for 📱CW in your menu bar")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text("You can close this window - the app will keep running in the menu bar.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Quit Application") {
                NSApp.terminate(nil)
            }
            .padding(.top, 10)
        }
        .padding()
    }
} 