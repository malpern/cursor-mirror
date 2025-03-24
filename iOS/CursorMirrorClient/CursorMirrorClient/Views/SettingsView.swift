import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ConnectionViewModel
    @State private var streamConfig = StreamConfig()
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Stream Quality") {
                    Picker("Quality", selection: $streamConfig.quality) {
                        ForEach(StreamConfig.Quality.allCases, id: \.self) { quality in
                            Text(quality.displayName)
                                .tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if streamConfig.quality == .auto {
                        Text("Auto quality will adjust based on your network conditions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Buffer Settings") {
                    HStack {
                        Text("Buffer Size")
                        Spacer()
                        Text("\(streamConfig.bufferSize, specifier: "%.1f") seconds")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(
                        value: $streamConfig.bufferSize,
                        in: StreamConfig.minimumBufferSize...StreamConfig.maximumBufferSize,
                        step: 0.5
                    ) {
                        Text("Buffer Size")
                    } minimumValueLabel: {
                        Text("\(StreamConfig.minimumBufferSize, specifier: "%.1f")")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("\(StreamConfig.maximumBufferSize, specifier: "%.1f")")
                            .font(.caption)
                    }
                    
                    Text("Larger buffer sizes provide smoother playback but increase latency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Connection") {
                    if let selectedDevice = viewModel.connectionState.selectedDevice {
                        HStack {
                            Text("Connected Device")
                            Spacer()
                            Text(selectedDevice.name)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Status")
                            Spacer()
                            StatusText(status: viewModel.connectionState.status)
                        }
                        
                        if viewModel.connectionState.status == .connected {
                            Button("Disconnect", role: .destructive) {
                                viewModel.disconnect()
                            }
                        }
                    } else {
                        Text("Not connected to any device")
                            .foregroundStyle(.secondary)
                        
                        NavigationLink(destination: DeviceDiscoveryView(viewModel: viewModel)) {
                            Text("Browse Devices")
                        }
                    }
                }
                
                Section {
                    Button("Save Settings") {
                        streamConfig.saveConfiguration()
                    }
                    
                    Button("Reset to Defaults", role: .destructive) {
                        showingResetAlert = true
                    }
                } footer: {
                    Text("Settings are automatically applied when connecting to a device")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Create a new instance to ensure we're loading the latest settings
                streamConfig = StreamConfig()
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    streamConfig.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
        }
    }
}

struct StatusText: View {
    let status: ConnectionStatus
    
    var body: some View {
        switch status {
        case .connected:
            Label("Connected", systemImage: "circle.fill")
                .foregroundStyle(.green)
        case .connecting:
            Label("Connecting", systemImage: "arrow.clockwise")
                .foregroundStyle(.orange)
        case .disconnecting:
            Label("Disconnecting", systemImage: "arrow.clockwise")
                .foregroundStyle(.orange)
        case .disconnected:
            Label("Disconnected", systemImage: "circle.fill")
                .foregroundStyle(.secondary)
        case .error:
            Label("Error", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

extension StreamConfig.Quality {
    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
}

#Preview {
    let viewModel = ConnectionViewModel()
    return SettingsView(viewModel: viewModel)
} 