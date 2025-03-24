//
//  ContentView.swift
//  CursorMirrorClient
//
//  Created by Micah Alpern on 3/23/25.
//

import SwiftUI

struct ContentView: View {
    @State private var connectionViewModel = ConnectionViewModel()
    
    var body: some View {
        TabView {
            DeviceDiscoveryView(viewModel: connectionViewModel)
                .tabItem {
                    Label("Devices", systemImage: "wifi")
                }
            
            PlayerView(viewModel: connectionViewModel)
                .tabItem {
                    Label("Player", systemImage: "play.rectangle.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            // Register this device in CloudKit when the app starts
            Task {
                await connectionViewModel.registerThisDevice()
            }
        }
    }
}

#Preview {
    ContentView()
}
