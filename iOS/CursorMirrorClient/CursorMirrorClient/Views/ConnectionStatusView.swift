import SwiftUI

struct ConnectionStatusView: View {
    let device: DeviceInfo
    let status: ConnectionStatus
    let disconnect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection Status")
                        .font(.headline)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                connectionIndicator
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if status == .connected {
                    Button(action: disconnect) {
                        Text("Disconnect")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else if status == .disconnected {
                    Button(action: disconnect) {
                        Text("Cancel")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.secondary)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    private var statusText: String {
        switch status {
        case .connected:
            return "Connected to device"
        case .connecting:
            return "Connecting to device..."
        case .disconnecting:
            return "Disconnecting..."
        case .disconnected:
            return "Not connected"
        case .error:
            return "Connection error"
        }
    }
    
    private var connectionIndicator: some View {
        ZStack {
            switch status {
            case .connected:
                Circle()
                    .fill(Color.green)
                    .frame(width: 14, height: 14)
                
            case .connecting, .disconnecting:
                ProgressView()
                    .controlSize(.small)
                
            case .disconnected:
                Circle()
                    .fill(Color.gray)
                    .frame(width: 14, height: 14)
                
            case .error:
                Circle()
                    .fill(Color.red)
                    .frame(width: 14, height: 14)
            }
        }
        .frame(width: 30, height: 30)
    }
}

#Preview {
    VStack {
        let recordID = CKRecord.ID(recordName: "test-id")
        let device = DeviceInfo(id: "test-id", name: "MacBook Pro", recordID: recordID)
        
        ConnectionStatusView(device: device, status: .connected) {}
        ConnectionStatusView(device: device, status: .connecting) {}
        ConnectionStatusView(device: device, status: .disconnecting) {}
        ConnectionStatusView(device: device, status: .disconnected) {}
        ConnectionStatusView(device: device, status: .error) {}
    }
    .padding()
    .background(Color(UIColor.systemBackground))
} 