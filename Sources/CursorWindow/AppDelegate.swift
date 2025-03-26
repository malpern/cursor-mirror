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
        releaseLockFile()
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
                    
                    // Restore viewport if it was visible previously
                    if UserDefaults.standard.bool(forKey: "com.cursor-window.viewport.wasVisible") {
                        print("DEBUG: Restoring viewport from previous session")
                        // Delay the restoration slightly to ensure everything is initialized
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.viewportManager?.showViewport()
                        }
                    } else {
                        print("DEBUG: Viewport was not visible in previous session")
                    }
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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
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
        print("Starting emergency cleanup before app termination")
        
        // Stop screen capture if running
        try? await screenCaptureManager?.stopCapture()
        
        // Stop HTTP server if running
        let serverManager = HTTPServerManager.shared
        if serverManager.isRunning {
            do {
                // First stop streaming if active
                try await serverManager.stopStreaming()
                
                // Perform direct server shutdown without CloudKit
                if let app = serverManager.directAccessApp {
                    // First shutdown the EventLoopGroup safely
                    app.eventLoopGroup.shutdownGracefully { _ in
                        print("Event loop group shutdown completed")
                    }
                    
                    // Use synchronous shutdown for reliability during app termination
                    DispatchQueue.global(qos: .userInitiated).async {
                        app.shutdown()
                        print("Server application shutdown completed")
                    }
                }
                
                print("HTTP server cleanup performed")
            } catch {
                print("Error during server shutdown: \(error)")
            }
        }
        
        print("Cleanup completed")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("Application will terminate")
        
        // Save viewport state explicitly
        viewportManager?.saveViewportState()
        
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
        
        // Release the lock file synchronously first to prevent multiple instances issues
        releaseLockFile()
        
        // Set a timeout that will force kill the app if termination takes too long
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.0) {
            print("Termination is taking too long, force exiting in 3 seconds")
            // Give visible feedback to the user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Application Is Taking Too Long To Quit"
                alert.informativeText = "The application will force exit in 3 seconds."
                alert.addButton(withTitle: "Force Quit Now")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    print("User selected immediate force quit")
                    exit(0)
                }
            }
            
            // Final fallback
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3.0) {
                print("Final fallback force exit")
                exit(0)
            }
        }
        
        // Perform async cleanup in the background before terminating
        Task {
            print("Starting cleanup before termination")
            HTTPServerManager.shared.emergencyShutdown()
            await cleanup()
            
            print("Cleanup complete, proceeding with termination")
            // Allow a small delay for tasks to complete
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Actually terminate the app after cleanup
            DispatchQueue.main.async {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        
        // Return .terminateLater to allow our async cleanup to complete
        return .terminateLater
    }
    
    /// Force exit the application safely after emergency cleanup
    @objc public func forceExit() {
        print("Force exit requested")
        AppDelegate.immediateForceQuit()
    }
    
    /// Force exit the application immediately, bypassing all cleanup
    @objc public static func immediateForceQuit() {
        print("EMERGENCY QUIT: Forcing immediate application exit")
        // Release any global resources to avoid corrupting files
        let appDelegate = NSApp.delegate as? AppDelegate
        appDelegate?.releaseLockFile()
        
        // Force exit with clean code
        exit(0)
    }
}

// Move the window content to a separate SwiftUI view for better state management
@available(macOS 14.0, *)
private struct MainWindowView: View {
    @ObservedObject var viewportManager: ViewportManager
    let screenCaptureManager: ScreenCaptureManager
    @State private var showEncodingSettings = false
    @State private var encodingSettings = EncodingSettings()
    @StateObject private var encoder = H264VideoEncoder()
    @State private var serverManager = HTTPServerManager.shared
    @State private var isServerRunning = false
    @State private var isEncoding = false
    @State private var encodingError: Error?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Phone Mirror")
                .font(.largeTitle)
            
            if screenCaptureManager.isScreenCapturePermissionGranted {
                // 1. VIEWPORT TOGGLE
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
                .padding(.bottom, 8)
                
                // 2. CAPTURE BUTTON
                Button {
                    Task {
                        if !screenCaptureManager.isCapturing {
                            // Set the capturing state immediately for UI feedback
                            screenCaptureManager.setManualCapturingState(true)
                            
                            do {
                                print("Starting capture...")
                                try await screenCaptureManager.startCaptureForViewport(
                                    frameProcessor: BasicFrameProcessor(),
                                    viewportManager: viewportManager
                                )
                                print("Capture started successfully")
                            } catch {
                                // Revert on error
                                screenCaptureManager.setManualCapturingState(false)
                                print("Capture error: \(error)")
                                encodingError = error
                                showError = true
                            }
                        } else {
                            // Set the capturing state immediately for UI feedback
                            screenCaptureManager.setManualCapturingState(false)
                            
                            do {
                                print("Stopping capture...")
                                try await screenCaptureManager.stopCapture()
                                print("Capture stopped successfully")
                            } catch {
                                // Revert on error
                                screenCaptureManager.setManualCapturingState(true)
                                print("Capture error: \(error)")
                                encodingError = error
                                showError = true
                            }
                        }
                    }
                } label: {
                    Text(screenCaptureManager.isCapturing ? "Stop Capture" : "Start Capture")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(screenCaptureManager.isCapturing ? .red : .blue)
                .frame(maxWidth: .infinity)
                
                // 3. SERVER BUTTON
                Button(action: {
                    Task {
                        do {
                            if isServerRunning {
                                try await serverManager.stop()
                                isServerRunning = false
                            } else {
                                try await serverManager.start()
                                isServerRunning = true
                            }
                        } catch {
                            print("Error toggling server: \(error)")
                            await MainActor.run {
                                self.encodingError = error
                                self.showError = true
                            }
                        }
                    }
                }) {
                    Text(isServerRunning ? "Stop Server" : "Start Server")
                }
                .buttonStyle(.borderedProminent)
                .tint(isServerRunning ? .red : .blue)
                .disabled(!screenCaptureManager.isCapturing) // Direct check against the screenCaptureManager.isCapturing property
                .frame(maxWidth: .infinity)
                
                if isServerRunning {
                    Text("Server running at:")
                        .font(.caption)
                    Text("http://localhost:8080")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            NSWorkspace.shared.open(URL(string: "http://localhost:8080")!)
                        }
                }
                
                // 4. ENCODING BUTTON WITH SETTINGS
                HStack(spacing: 8) {
                    Button(encoder.isEncoding ? "Stop Encoding" : "Start Encoding") {
                        Task {
                            do {
                                if !encoder.isEncoding {
                                    print("[MainWindowView] Starting encoding process...")
                                    print("[MainWindowView] Initializing encoder with settings - Path: \(encodingSettings.outputPath), Dimensions: \(encodingSettings.width)x\(encodingSettings.height)")
                                    
                                    // Connect encoder to HTTP server for streaming
                                    try serverManager.connectVideoEncoder(encoder)
                                    
                                    try await encoder.startEncoding(
                                        to: URL(fileURLWithPath: encodingSettings.outputPath),
                                        width: encodingSettings.width,
                                        height: encodingSettings.height
                                    )
                                    print("[MainWindowView] Encoder started successfully")
                                    
                                    // Start streaming through HTTP server
                                    try await serverManager.startStreaming()
                                } else {
                                    print("[MainWindowView] Stopping encoding process...")
                                    try? await serverManager.stopStreaming()
                                    Task {
                                        await encoder.stopEncoding()
                                    }
                                }
                            } catch {
                                print("[MainWindowView] Encoding error: \(error)")
                                encodingError = error
                                showError = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(encoder.isEncoding ? .red : .blue)
                    .disabled(!screenCaptureManager.isCapturing)
                    .frame(maxWidth: .infinity)
                    
                    // Settings gear icon
                    Button(action: {
                        showEncodingSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .help("Encoding Settings")
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Text("You can close this window - the app will keep running in the menu bar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            } else {
                // Show permission UI if permission not granted
                Text("Screen Recording Permission Required")
                    .font(.headline)
                
                Text("Cursor Window needs permission to capture your screen.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
                
                if screenCaptureManager.isCheckingPermission {
                    ProgressView()
                        .padding(.vertical, 8)
                    Text("Checking permission status...")
                        .font(.caption)
                } else {
                    Button("Check Permission Status") {
                        Task {
                            await screenCaptureManager.forceRefreshPermissionStatus()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .frame(maxWidth: .infinity)
                }
                
                Button("Open System Settings") {
                    screenCaptureManager.openSystemPreferencesScreenCapture()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(screenCaptureManager.isCheckingPermission)
                .frame(maxWidth: .infinity)
            }
            
            Button("Quit Application") {
                Task { @MainActor in
                    print("User initiated quit from main window")
                    
                    // First try a normal termination
                    NSApp.terminate(nil)
                    
                    // If terminate gets stuck due to CloudKit, force quit after 1.5 seconds
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) {
                        print("Termination taking too long, forcing exit...")
                        AppDelegate.immediateForceQuit()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
            .frame(maxWidth: .infinity)
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding()
        .frame(minWidth: 300)
        .sheet(isPresented: $showEncodingSettings) {
            EncodingSettingsView(settings: $encodingSettings)
        }
        .alert("Encoding Error", isPresented: $showError, presenting: encodingError) { _ in
            Button("OK") {
                showError = false
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .onAppear {
            // Refresh server status when the view appears
            isServerRunning = serverManager.isRunning
            
            // Refresh permission status when the view appears
            Task {
                await screenCaptureManager.forceRefreshPermissionStatus()
            }
        }
    }
} 