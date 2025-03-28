import SwiftUI
import AppKit
import Cocoa
import Combine
import CursorWindowCore
import Foundation
import Logging
#if canImport(Darwin)
import Darwin.POSIX
#endif

@available(macOS 14.0, *)
class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var viewportManager: ViewportManager? = nil
    private var screenCaptureManager: ScreenCaptureManager? = nil
    private var mainWindow: NSWindow?
    private var startupTask: Task<Void, Never>? = nil
    private let lockFile = "/tmp/cursor-window.lock"
    private var lockFileDescriptor: Int32 = -1
    private var isForceStarted = false
    
    deinit {
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
    
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the application
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
                
                // Ensure isCapturing is set to false initially
                if let manager = self.screenCaptureManager, manager.isCapturing {
                    print("Resetting isCapturing to false during initialization")
                    manager.isCapturing = false
                }
                
                // Check permission status first with timeout
                try await withTimeout(seconds: 5) {
                    await self.screenCaptureManager?.forceRefreshPermissionStatus()
                }
                
                // Execute UI updates on the main actor
                await MainActor.run {
                    // Create the viewport manager
                    self.viewportManager = ViewportManager(viewFactory: { [weak self] in
                        guard let self = self else { return AnyView(EmptyView()) }
                        return AnyView(ViewportOverlayView(viewportManager: self.viewportManager!))
                    })
                    
                    // Create the main window
                    let window = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                        styleMask: [.titled, .closable, .miniaturizable, .resizable],
                        backing: .buffered,
                        defer: false
                    )
                    window.center()
                    window.setFrameAutosaveName("Main Window")
                    window.contentView = NSHostingView(
                        rootView: MainWindowView(
                            viewportManager: self.viewportManager!,
                            screenCaptureManager: self.screenCaptureManager!
                        )
                    )
                    window.makeKeyAndOrderFront(nil)
                    self.mainWindow = window
                    
                    // Ensure app is active and visible
                    NSApp.activate(ignoringOtherApps: true)
                    
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
                
                // Cancel the watchdog since we completed initialization
                watchdogTask.cancel()
                
            } catch {
                print("Error during setup: \(error)")
                NSApp.terminate(nil)
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
            let contentView = MainWindowView(viewportManager: viewportManager, screenCaptureManager: screenCaptureManager)
            window.contentView = NSHostingView(rootView: contentView)
        }
        
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window
    }
    
    private func releaseLockFile() {
        if lockFileDescriptor != -1 {
            flock(lockFileDescriptor, LOCK_UN)
            close(lockFileDescriptor)
            lockFileDescriptor = -1
            try? FileManager.default.removeItem(atPath: lockFile)
        }
    }
    
    @MainActor
    private func cleanup() async throws {
        print("Starting emergency cleanup before app termination")
        
        // Create a task group for parallel cleanup
        await withTaskGroup(of: Void.self) { group in
            // Stop screen capture if running
            group.addTask {
                if let screenCaptureManager = self.screenCaptureManager {
                    try? await screenCaptureManager.stopCapture()
                }
            }
            
            // Stop HTTP server if running
            group.addTask {
                let serverManager = await HTTPServerManager.shared
                if await serverManager.isRunning {
                    do {
                        try await serverManager.stop()
                        print("HTTP server cleanup completed")
                    } catch {
                        print("Error during server shutdown: \(error)")
                    }
                }
            }
        }
        
        print("Cleanup completed")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("Application will terminate")
        
        // Save viewport state explicitly
        viewportManager?.saveViewportState()
        
        // Create a semaphore to ensure cleanup completes
        let semaphore = DispatchSemaphore(value: 0)
        
        // Run cleanup with timeout
        Task {
            do {
                try await withTimeout(seconds: 5.0) {
                    try await self.cleanup()
                }
            } catch {
                print("Error during cleanup: \(error)")
            }
            semaphore.signal()
        }
        
        // Wait for cleanup with timeout
        _ = semaphore.wait(timeout: .now() + 5.0)
        
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
            do {
                try await self.cleanup()
                
                print("Cleanup complete, proceeding with termination")
                // Allow a small delay for tasks to complete
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Actually terminate the app after cleanup
                DispatchQueue.main.async {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
            } catch {
                print("Error during cleanup: \(error)")
                // Still proceed with termination
                DispatchQueue.main.async {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
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

// MARK: - View Components

private struct PermissionView: View {
    @ObservedObject var screenCaptureManager: ScreenCaptureManager
    
    var body: some View {
        VStack(spacing: 16) {
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
    }
}

private struct CaptureControlsView: View {
    @ObservedObject var viewportManager: ViewportManager
    @ObservedObject var screenCaptureManager: ScreenCaptureManager
    @Binding var captureButtonPressed: Bool
    @Binding var encodingError: Error?
    @Binding var showError: Bool
    
    var body: some View {
        VStack(spacing: 16) {
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
            
            Button {
                captureButtonPressed.toggle()
                let shouldStartCapture = !screenCaptureManager.isCapturing
                
                Task {
                    do {
                        if shouldStartCapture {
                            print("Starting capture...")
                            try await screenCaptureManager.startCaptureForViewport(
                                frameProcessor: BasicFrameProcessor(),
                                viewportManager: viewportManager
                            )
                            print("Capture started successfully")
                        } else {
                            print("Stopping capture...")
                            try await screenCaptureManager.stopCapture()
                            print("Capture stopped successfully")
                        }
                    } catch {
                        await MainActor.run {
                            captureButtonPressed.toggle()
                        }
                        print("Capture error: \(error)")
                        encodingError = error
                        showError = true
                    }
                }
            } label: {
                let visuallyCapturing = screenCaptureManager.isCapturing != captureButtonPressed
                Text(visuallyCapturing ? "Stop Capture" : "Start Capture")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(screenCaptureManager.isCapturing != captureButtonPressed ? .red : .blue)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ServerControlView: View {
    @ObservedObject var screenCaptureManager: ScreenCaptureManager
    @ObservedObject var serverManager: HTTPServerManager
    @Binding var isServerRunning: Bool
    @Binding var encodingError: Error?
    @Binding var showError: Bool
    
    var body: some View {
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
        .frame(maxWidth: .infinity)
    }
}

@MainActor
struct MainWindowView: View {
    @State private var encoder: H264VideoEncoder?
    @StateObject private var serverManager = HTTPServerManager.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showEncodingSettings = false
    @State private var encodingControlViewModel: EncodingControlViewModel?
    @State private var encoderError: Error? = nil
    @State private var isEncoderInitialized = false
    
    let viewportManager: ViewportManager
    @ObservedObject var screenCaptureManager: ScreenCaptureManager
    
    init(viewportManager: ViewportManager, screenCaptureManager: ScreenCaptureManager) {
        self.viewportManager = viewportManager
        self.screenCaptureManager = screenCaptureManager
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Phone Mirror")
                .font(.largeTitle)
                .padding(.bottom)
            
            if screenCaptureManager.isScreenCapturePermissionGranted {
                // Viewport Toggle
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
                
                // Capture Button
                Button {
                    let shouldStartCapture = !screenCaptureManager.isCapturing
                    
                    Task {
                        do {
                            if shouldStartCapture {
                                print("Starting capture...")
                                if let encoder = encoder {
                                    try await screenCaptureManager.startCaptureForViewport(
                                        frameProcessor: encoder,
                                        viewportManager: viewportManager
                                    )
                                    print("Capture started successfully")
                                } else {
                                    throw NSError(domain: "com.cursor-window", code: -1, userInfo: [NSLocalizedDescriptionKey: "Encoder not initialized"])
                                }
                            } else {
                                print("Stopping capture...")
                                try await screenCaptureManager.stopCapture()
                                print("Capture stopped successfully")
                            }
                        } catch {
                            await MainActor.run {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                            print("Capture error: \(error)")
                        }
                    }
                } label: {
                    Text(screenCaptureManager.isCapturing ? "Stop Capture" : "Start Capture")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(screenCaptureManager.isCapturing ? .red : .blue)
                .frame(maxWidth: .infinity)
                
                // Server Button
                Button(action: {
                    Task {
                        do {
                            if serverManager.isRunning {
                                try await serverManager.stop()
                            } else {
                                try await serverManager.start()
                            }
                        } catch {
                            print("Error toggling server: \(error)")
                            await MainActor.run {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                }) {
                    Text(serverManager.isRunning ? "Stop Server" : "Start Server")
                }
                .buttonStyle(.borderedProminent)
                .tint(serverManager.isRunning ? .red : .blue)
                .frame(maxWidth: .infinity)
                
                // Encoding Settings - Changed to use a gear icon
                Button(action: {
                    showEncodingSettings.toggle()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .sheet(isPresented: $showEncodingSettings) {
                    if let viewModel = encodingControlViewModel {
                        EncodingControlView(viewModel: viewModel)
                    }
                }
                
                // Status Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status:")
                        .font(.headline)
                    Text("Capture: \(screenCaptureManager.isCapturing ? "Active" : "Inactive")")
                    Text("Server: \(serverManager.isRunning ? "Running" : "Stopped")")
                    if let error = encoderError {
                        Text("Encoding Error: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor)))
                
            } else {
                Text("Screen recording permission is required.")
                    .foregroundColor(.red)
                Button("Open System Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 500)
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: isEncoderInitialized) { _, initialized in
            if initialized {
                // Set up a task to check for errors periodically
                Task {
                    if let currentEncoder = encoder {
                        encoderError = await currentEncoder.error
                    }
                }
            }
        }
        .onAppear {
            // Initialize encoder if needed
            if encoder == nil {
                Task {
                    do {
                        let newEncoder = try await H264VideoEncoder(viewportSize: ViewportSize.defaultSize())
                        encoder = newEncoder
                        isEncoderInitialized = true
                        encodingControlViewModel = await EncodingControlViewModelImpl(frameProcessor: newEncoder)
                    } catch {
                        print("Failed to initialize encoder: \(error)")
                        errorMessage = "Failed to initialize encoder: \(error.localizedDescription)"
                        showError = true
                    }
                }
            }
            
            // Check for encoder error when view appears
            if let currentEncoder = encoder {
                Task {
                    encoderError = await currentEncoder.error
                }
            }
        }
    }
} 