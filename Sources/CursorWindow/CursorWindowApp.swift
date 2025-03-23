#if os(macOS)
import SwiftUI
import AppKit
import CursorWindowCore

/// A menu bar application that displays a floating viewport window
/// The viewport can be positioned and resized by the user
@available(macOS 14.0, *)
struct CursorWindowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Enable debug mode to make the app extra visible (useful when troubleshooting visibility issues)
    private let debugMode = true
    
    var body: some Scene {
        Settings {
            // Enable force-visible debug window in debug mode
            if debugMode {
                DebugView()
            } else {
                EmptyView()
            }
        }
    }
}

// A very visible debug window to help find the app
@available(macOS 14.0, *)
struct DebugView: View {
    @State private var isVisible = true
    
    var body: some View {
        VStack(spacing: 10) {
            Text("CURSOR WINDOW DEBUG MODE")
                .font(.title)
                .fontWeight(.bold)
            
            Text("The app is running!")
                .font(.headline)
            
            Text("Look for 📱CW in your menu bar")
                .font(.title2)
                .foregroundColor(.blue)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                )
            
            Image(systemName: "arrow.up")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .padding()
            
            Button("Hide This Window") {
                isVisible = false
            }
            .padding()
            
            Button("Quit Application") {
                NSApplication.shared.terminate(nil)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if !isVisible {
                // Make this window visible again when app starts
                isVisible = true
            }
        }
    }
}

#else
#error("CursorWindowApp is only available on macOS 14.0 or later")
#endif 