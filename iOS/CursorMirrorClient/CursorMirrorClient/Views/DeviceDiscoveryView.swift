import SwiftUI

struct DeviceDiscoveryView: View {
    @ObservedObject var viewModel: ConnectionViewModel
    @State private var isRefreshing = false
    
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
                        if viewModel.connectionState.discoveredDevices.isEmpty {
                            ContentUnavailableView {
                                Label("No Devices Found", systemImage: "wifi.slash")
                            } description: {
                                Text("Pull down to refresh or check that devices are on the same iCloud account")
                            } actions: {
                                Button(action: refreshDevices) {
                                    Text("Refresh")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewModel.connectionState.discoveredDevices, id: \.id) { device in
                                DeviceRow(device: device, isSelected: isSelected(device), connectionStatus: viewModel.connectionState.status)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleDeviceSelection(device)
                                    }
                            }
                        }
                    } header: {
                        Text("Available Devices")
                    } footer: {
                        Text("Showing devices that are available on your iCloud account")
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await refreshDevicesAsync()
                }
                
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
            }
        }
        .onAppear {
            refreshDevices()
        }
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
                
                Text("Last seen: \(device.lastSeenText)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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

#Preview {
    let viewModel = ConnectionViewModel()
    return DeviceDiscoveryView(viewModel: viewModel)
} 