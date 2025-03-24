import SwiftUI

struct DeviceDiscoveryView: View {
    @Bindable var viewModel: ConnectionViewModel
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var showingHelpSheet = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.connectionState.status == .error {
                    ErrorBannerView(error: viewModel.connectionState.lastError) {
                        viewModel.clearError()
                    }
                }
                
                List {
                    Section {
                        if filteredDevices.isEmpty {
                            ContentUnavailableView {
                                Label("No Devices Found", systemImage: "wifi.slash")
                            } description: {
                                if !searchText.isEmpty {
                                    Text("No devices match '\(searchText)'")
                                } else {
                                    Text("Pull down to refresh or check that devices are on the same iCloud account")
                                }
                            } actions: {
                                Button(action: refreshDevices) {
                                    Text("Refresh")
                                }
                                .buttonStyle(.borderedProminent)
                                
                                if viewModel.connectionState.status == .error {
                                    Button(action: retryConnection) {
                                        Text("Retry Connection")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Button(action: { showingHelpSheet = true }) {
                                    Text("Help")
                                }
                                .buttonStyle(.bordered)
                            }
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(filteredDevices, id: \.id) { device in
                                DeviceRow(device: device, isSelected: isSelected(device), connectionStatus: viewModel.connectionState.status)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleDeviceSelection(device)
                                    }
                                    .accessibilityLabel("\(device.name), \(device.isOnline ? "Online" : "Offline")")
                                    .accessibilityHint("Double tap to \(isSelected(device) ? "disconnect from" : "connect to") this device")
                                    .contextMenu {
                                        Button(action: { handleDeviceSelection(device) }) {
                                            Label("Connect", systemImage: "link")
                                        }
                                        
                                        Button(action: { 
                                            // Share device info via system share sheet
                                            // For future implementation
                                        }) {
                                            Label("Share Device Info", systemImage: "square.and.arrow.up")
                                        }
                                    }
                            }
                        }
                    } header: {
                        Text("Available Devices")
                    } footer: {
                        Text("Showing devices that are available on your iCloud account. Last updated: \(formattedLastUpdateTime)")
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await refreshDevicesAsync()
                }
                .searchable(text: $searchText, prompt: "Search devices")
                
                if let selectedDevice = viewModel.connectionState.selectedDevice {
                    ConnectionStatusView(
                        device: selectedDevice,
                        status: viewModel.connectionState.status,
                        disconnect: {
                            viewModel.disconnect()
                        }
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring, value: viewModel.connectionState.selectedDevice)
            .animation(.spring, value: viewModel.connectionState.status)
            .navigationTitle("Cursor Mirror")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refreshDevices) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingHelpSheet = true }) {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingHelpSheet) {
                HelpView()
            }
        }
        .onAppear {
            refreshDevices()
        }
    }
    
    private var filteredDevices: [DeviceInfo] {
        if searchText.isEmpty {
            return viewModel.connectionState.discoveredDevices
        } else {
            return viewModel.connectionState.discoveredDevices.filter { device in
                device.name.localizedCaseInsensitiveContains(searchText) ||
                device.type.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var formattedLastUpdateTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: viewModel.connectionState.lastUpdated, relativeTo: Date())
    }
    
    private func isSelected(_ device: DeviceInfo) -> Bool {
        viewModel.connectionState.selectedDevice?.id == device.id
    }
    
    private func handleDeviceSelection(_ device: DeviceInfo) {
        // If we're already connected to this device, do nothing
        if viewModel.connectionState.selectedDevice?.id == device.id && viewModel.connectionState.status == .connected {
            return
        }
        
        // If we're already connected to a different device, disconnect first
        if viewModel.connectionState.status == .connected {
            viewModel.disconnect()
        }
        
        // Connect to the selected device
        viewModel.connectToDevice(device)
    }
    
    private func refreshDevices() {
        isRefreshing = true
        viewModel.startDeviceDiscovery()
        
        // Reset isRefreshing after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRefreshing = false
        }
    }
    
    private func refreshDevicesAsync() async {
        isRefreshing = true
        viewModel.startDeviceDiscovery()
        
        // Add a small delay to ensure the refresh control animation looks good
        try? await Task.sleep(for: .seconds(1))
        isRefreshing = false
    }
    
    private func retryConnection() {
        // Clear any existing error
        viewModel.clearError()
        
        // If we have a selected device, try to connect again
        if let selectedDevice = viewModel.connectionState.selectedDevice {
            viewModel.connectToDevice(selectedDevice)
        } else {
            // Otherwise, just refresh the device list
            refreshDevices()
        }
    }
}

struct DeviceRow: View {
    let device: DeviceInfo
    let isSelected: Bool
    let connectionStatus: ConnectionStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                
                Text(device.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 10) {
                    Text("Last seen: \(device.lastSeenText)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    if device.isOnline {
                        Text("Online")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.2))
                            )
                    }
                }
            }
            
            Spacer()
            
            StatusIndicator(device: device, isSelected: isSelected, connectionStatus: connectionStatus)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

struct StatusIndicator: View {
    let device: DeviceInfo
    let isSelected: Bool
    let connectionStatus: ConnectionStatus
    
    var body: some View {
        if isSelected {
            switch connectionStatus {
            case .connecting:
                ProgressView()
                    .controlSize(.small)
            case .connected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .disconnecting:
                ProgressView()
                    .controlSize(.small)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .disconnected:
                EmptyView()
            }
        } else {
            Text(device.statusIndicator)
        }
    }
}

struct ErrorBannerView: View {
    let error: Error?
    let dismissAction: () -> Void
    
    var body: some View {
        if let error = error {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                    
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Button(action: dismissAction) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Dismiss error")
                }
                .padding()
            }
            .background(Color.red.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("About Device Discovery")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Connect Devices")
                            .font(.headline)
                        
                        Text("Cursor Mirror uses CloudKit to discover devices on your Apple ID. Both devices need to be signed in with the same Apple ID and have iCloud enabled.")
                            .padding(.bottom, 4)
                        
                        Text("Troubleshooting Steps:")
                            .font(.subheadline)
                            .bold()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Check that both devices are on the same Apple ID", systemImage: "1.circle")
                            Label("Make sure iCloud is enabled on both devices", systemImage: "2.circle")
                            Label("Check internet connectivity on both devices", systemImage: "3.circle") 
                            Label("Try refreshing the device list", systemImage: "4.circle")
                            Label("Restart the Cursor Mirror app on both devices", systemImage: "5.circle")
                        }
                        .padding(.bottom, 4)
                    }
                }
                
                Section(header: Text("Connection Issues")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If you're having trouble connecting:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Make sure both devices are on the same network", systemImage: "wifi")
                            Label("Check firewall settings on Mac", systemImage: "shield")
                            Label("Try the 'Retry Connection' button", systemImage: "arrow.clockwise")
                            Label("Ensure screen recording permissions are granted on Mac", systemImage: "display")
                        }
                    }
                }
            }
            .navigationTitle("Help & Troubleshooting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let viewModel = ConnectionViewModel()
    return DeviceDiscoveryView(viewModel: viewModel)
} 