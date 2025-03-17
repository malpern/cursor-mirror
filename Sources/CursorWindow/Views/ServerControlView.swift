import SwiftUI
import CursorWindowCore

struct ServerControlView: View {
    @EnvironmentObject var viewModel: ServerControlViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Server status section
                serverStatusSection
                
                Divider()
                
                // iCloud status section
                iCloudStatusSection
                
                Divider()
                
                // Configuration section
                serverConfigSection
                
                Divider()
                
                // Server control section
                serverControlSection
                
                Divider()
                
                // Stream status section
                streamStatusSection
                
                Divider()
                
                // Stream URL and QR Code section
                if !viewModel.streamURL.isEmpty {
                    streamURLSection
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 600)
        .task {
            // Check if there's active stream when view appears
            await viewModel.checkStreamStatus()
        }
    }
    
    private var serverStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Server Status")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(viewModel.isServerRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
            }
            
            Text(viewModel.serverStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var iCloudStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("iCloud Connection")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(viewModel.iCloudAvailable ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
            }
            
            Text(viewModel.iCloudStatus)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if viewModel.iCloudAvailable {
                HStack {
                    Text("Device Name:")
                        .fontWeight(.medium)
                    
                    TextField("Device Name", text: $viewModel.deviceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.top, 5)
            }
        }
    }
    
    private var serverConfigSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Server Configuration")
                .font(.headline)
            
            HStack {
                Text("Hostname:")
                    .frame(width: 100, alignment: .leading)
                
                TextField("Hostname", text: $viewModel.hostname)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(viewModel.isServerRunning)
            }
            
            HStack {
                Text("Port:")
                    .frame(width: 100, alignment: .leading)
                
                TextField("Port", value: $viewModel.port, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(viewModel.isServerRunning)
            }
            
            Toggle("Enable SSL/TLS", isOn: $viewModel.enableSSL)
                .disabled(viewModel.isServerRunning)
            
            Toggle("Enable Admin Dashboard", isOn: $viewModel.adminDashboardEnabled)
                .disabled(viewModel.isServerRunning)
        }
    }
    
    private var serverControlSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Server Controls")
                .font(.headline)
            
            HStack(spacing: 15) {
                Button(viewModel.isServerRunning ? "Stop Server" : "Start Server") {
                    Task {
                        await viewModel.toggleServer()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                if viewModel.isServerRunning && viewModel.adminDashboardEnabled {
                    Button("Open Admin Dashboard") {
                        viewModel.openAdminDashboard()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private var streamStatusSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Stream Status")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.checkStreamStatus()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            
            HStack {
                Text("Active Stream:")
                    .frame(width: 100, alignment: .leading)
                
                HStack {
                    Circle()
                        .fill(viewModel.streamActive ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text(viewModel.streamActive ? "Active" : "None")
                }
                
                Spacer()
            }
        }
    }
    
    private var streamURLSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Stream Access")
                .font(.headline)
            
            // Stream URL with copy button
            HStack {
                Text("URL:")
                    .frame(width: 50, alignment: .leading)
                
                Text(viewModel.streamURL)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Button {
                    viewModel.copyStreamURLToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
            
            // QR Code display
            if let qrCode = viewModel.qrCodeImage {
                VStack {
                    Text("Scan to connect:")
                        .font(.subheadline)
                    
                    Image(nsImage: qrCode)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 200, height: 200)
                        .padding()
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
} 