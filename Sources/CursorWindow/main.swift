import SwiftUI
import AppKit
import Foundation
import Darwin

// Set up logging to a file
let logFilePath = "/tmp/cursor-window-diagnostic.log"
func logToFile(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"
    
    // Print to console
    print(message)
    
    // Also write to file
    if let data = logMessage.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFilePath) {
            if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFilePath)) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: logFilePath))
        }
    }
}

// Start a new log session
logToFile("======================= NEW APP LAUNCH =======================")
logToFile("Process: \(ProcessInfo.processInfo.processName) (PID: \(ProcessInfo.processInfo.processIdentifier))")
logToFile("Parent PID: \(getppid())")
logToFile("Args: \(CommandLine.arguments)")
logToFile("Working directory: \(FileManager.default.currentDirectoryPath)")
logToFile("Physical memory: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) MB")
logToFile("Uptime: \(ProcessInfo.processInfo.systemUptime) seconds")
logToFile("=================================================================")

// Register the bundle ID manually since we're running from debug executable
let bundleID = "com.cursor-window"
UserDefaults.standard.set(bundleID, forKey: "NSBundleIdentifier")
logToFile("Manually registered bundle ID: \(bundleID)")

// Give Xcode time to clean up any parallel launch attempts
logToFile("Waiting for any parallel launches to resolve...")
let startTime = Date()
_ = Task {
    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
    logToFile("Startup delay complete (\(Date().timeIntervalSince(startTime) * 1000) ms)")
}
// Block main thread until delay completes
while Date().timeIntervalSince(startTime) < 0.5 {
    Thread.sleep(forTimeInterval: 0.01)
}

// Show what other matching processes are running
let debugProcess = Process()
debugProcess.launchPath = "/bin/sh"
debugProcess.arguments = ["-c", "echo 'Detailed process list:'; ps -ef | grep -v grep | grep CursorWindow | awk '{print $2, $8, $9, $10, $11}'"]
let debugPipe = Pipe()
debugProcess.standardOutput = debugPipe
try? debugProcess.run()
debugProcess.waitUntilExit()
if let debugOutput = String(data: debugPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
    logToFile(debugOutput)
}

// Create a very early lock file to prevent multiple instances
let lockFilePath = "/tmp/cursor-window-early.lock"
let globalLockPath = "/tmp/cursor-window-global.lock"
let fileManager = FileManager.default

// Add a flag to allow multiple instances for development
let allowMultipleInstances = ProcessInfo.processInfo.environment["CURSOR_WINDOW_DEBUG_ALLOW_MULTIPLE"] != nil

// Global variables for lock file handling
var globalLockFD: Int32 = -1
var earlyLockFile: String?

// Functions for atexit that don't capture context
func releaseGlobalLock() {
    if globalLockFD != -1 {
        flock(globalLockFD, LOCK_UN)
        close(globalLockFD)
        print("Global lock released")
    }
}

func removeEarlyLockFile() {
    if let path = earlyLockFile {
        do {
            try FileManager.default.removeItem(atPath: path)
            print("Early lock file removed: \(path)")
        } catch {
            print("Failed to remove early lock file: \(error)")
        }
    }
}

// Function to check if we're already running by examining running processes
func isAppAlreadyRunning() -> Bool {
    logToFile("\nChecking for other running instances...")
    
    // Method 1: Check for exact executables running, excluding self
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let ourPath = CommandLine.arguments[0]
    let exactPathCmd = "ps -ef | grep -v grep | grep '\(ourPath)' | grep -v '\(currentPID) ' | wc -l"
    
    let checkProcess = Process()
    checkProcess.launchPath = "/bin/sh"
    checkProcess.arguments = ["-c", exactPathCmd]
    
    let checkPipe = Pipe()
    checkProcess.standardOutput = checkPipe
    
    do {
        try checkProcess.run()
        checkProcess.waitUntilExit()
        
        let data = checkPipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let count = Int(output) {
            logToFile("Found \(count) other instances with exact same path excluding self")
            if count > 0 {
                // Get details about those processes
                let detailsCmd = "ps -ef | grep -v grep | grep '\(ourPath)' | grep -v '\(currentPID) '"
                let detailsProcess = Process()
                detailsProcess.launchPath = "/bin/sh"
                detailsProcess.arguments = ["-c", detailsCmd]
                
                let detailsPipe = Pipe()
                detailsProcess.standardOutput = detailsPipe
                try detailsProcess.run()
                detailsProcess.waitUntilExit()
                
                if let details = String(data: detailsPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
                    logToFile("Process details of other instances:\n\(details)")
                }
                
                return true
            }
        }
    } catch {
        logToFile("Error checking for exact path: \(error)")
    }
    
    // Method 2: Try to acquire a system-wide lock file with flock
    let lockFD = open(globalLockPath, O_WRONLY | O_CREAT, 0o666)
    if lockFD != -1 {
        logToFile("Global lock file opened: \(globalLockPath)")
        
        // Write PID to lock file
        let pidData = "\(currentPID)".data(using: .utf8)!
        _ = pidData.withUnsafeBytes { ptr in
            write(lockFD, ptr.baseAddress, ptr.count)
        }
        
        // Try to acquire exclusive lock, non-blocking
        let result = flock(lockFD, LOCK_EX | LOCK_NB)
        if result != 0 {
            logToFile("Failed to acquire global lock: \(errno). Another instance is running.")
            close(lockFD)
            return true
        }
        
        logToFile("Successfully acquired global lock.")
        
        // Store lock file descriptor in global variable and register C-style atexit handler
        globalLockFD = lockFD
        atexit(releaseGlobalLock)
    } else {
        logToFile("Warning: Failed to open global lock file: \(errno)")
    }
    
    logToFile("No duplicate instances detected\n")
    return false
}

// Check if app is already running
if !allowMultipleInstances && isAppAlreadyRunning() {
    logToFile("ERROR: Another instance of Cursor Window is already running. Exiting quietly...")
    
    // Exit without showing alert or any window since it just creates more terminal windows
    exit(0)
} else {
    // Create our lock file to mark that we're running
    fileManager.createFile(atPath: lockFilePath, contents: "\(ProcessInfo.processInfo.processIdentifier)".data(using: .utf8))
    
    // Store the path and register the C-style cleanup function
    earlyLockFile = lockFilePath
    atexit(removeEarlyLockFile)
    
    // Start the app normally
    logToFile("No other instances detected. Starting app normally.")
    CursorWindowApp.main()
} 