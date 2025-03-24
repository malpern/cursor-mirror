import SwiftUI

struct SettingsView: View {
    @State private var settings = UserSettings.shared
    @State private var showingResetConfirmation = false
    
    enum SettingsSection: String, CaseIterable {
        case connection = "Connection"
        case video = "Video"
        case touch = "Touch Controls"
        case appearance = "Appearance"
        case cloudSync = "Cloud Sync"
        
        var icon: String {
            switch self {
            case .connection: return "network"
            case .video: return "film"
            case .touch: return "hand.tap"
            case .appearance: return "paintpalette"
            case .cloudSync: return "cloud"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    NavigationLink(destination: settingsDetailView(for: section)) {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
            .alert("Reset Settings", isPresented: $showingResetConfirmation) {
                Button("Reset", role: .destructive) {
                    settings.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to reset all settings to their defaults?")
            }
        }
    }
    
    @ViewBuilder
    func settingsDetailView(for section: SettingsSection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch section {
                case .connection:
                    ConnectionSettingsView(settings: settings)
                case .video:
                    VideoSettingsView(settings: settings)
                case .touch:
                    TouchSettingsView(settings: settings)
                case .appearance:
                    AppearanceSettingsView(settings: settings)
                case .cloudSync:
                    CloudSyncSettingsView(settings: settings)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(section.rawValue + " Settings")
    }
}

struct ConnectionSettingsView: View {
    @State var settings: UserSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section {
                Toggle("Auto Connect", isOn: $settings.autoConnect)
                    .padding(.vertical, 8)
                
                Toggle("Remember Last Device", isOn: $settings.rememberLastDevice)
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading) {
                    Text("Connection Timeout")
                        .font(.headline)
                    
                    HStack {
                        Slider(value: $settings.connectionTimeout, in: 5...60, step: 5)
                        Text("\(Int(settings.connectionTimeout)) seconds")
                            .frame(width: 80)
                    }
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading) {
                    Text("Max Reconnection Attempts")
                        .font(.headline)
                    
                    Stepper("\(settings.maxReconnectionAttempts) attempts", value: $settings.maxReconnectionAttempts, in: 0...10)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Connection Options")
                    .font(.headline)
            }
            
            Text("These settings control how the app connects to devices and handles connection issues.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct VideoSettingsView: View {
    @State var settings: UserSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section {
                VStack(alignment: .leading) {
                    Text("Default Quality")
                        .font(.headline)
                    
                    Picker("", selection: $settings.defaultQuality) {
                        ForEach(StreamQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 8)
                
                Toggle("Enable Adaptive Bitrate", isOn: $settings.enableAdaptiveBitrate)
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Buffer Size")
                            .font(.headline)
                        Spacer()
                        Text("\(settings.bufferSize, specifier: "%.1f") seconds")
                    }
                    
                    Slider(value: $settings.bufferSize, in: 1...10, step: 0.5)
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Max Bandwidth")
                            .font(.headline)
                        Spacer()
                        if settings.maxBandwidthUsage == 0 {
                            Text("Unlimited")
                        } else {
                            Text("\(Int(settings.maxBandwidthUsage)) Mbps")
                        }
                    }
                    
                    Slider(value: $settings.maxBandwidthUsage, in: 0...20, step: 1)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Video Options")
                    .font(.headline)
            }
            
            Text("These settings control video quality and streaming behavior. Higher quality settings require more bandwidth.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TouchSettingsView: View {
    @State var settings: UserSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section {
                Toggle("Enable Touch Controls", isOn: $settings.enableTouchControls)
                    .padding(.vertical, 8)
                
                Toggle("Show Touch Indicator", isOn: $settings.showTouchIndicator)
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Touch Sensitivity")
                            .font(.headline)
                        Spacer()
                        Text(sensitivityLabel)
                    }
                    
                    Slider(value: $settings.touchSensitivity, in: 0.5...2.0, step: 0.1)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Touch Control Options")
                    .font(.headline)
            }
            
            Text("These settings control how touch interactions work with the mirrored content.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Touch Control Preview")
                    .font(.headline)
                
                TouchDemoView(
                    enabled: settings.enableTouchControls,
                    showIndicator: settings.showTouchIndicator,
                    sensitivity: settings.touchSensitivity
                )
                .frame(height: 200)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(12)
            }
            .padding(.top, 20)
        }
    }
    
    private var sensitivityLabel: String {
        switch settings.touchSensitivity {
        case ..<0.7: return "Low"
        case 0.7..<0.9: return "Medium-Low"
        case 0.9..<1.1: return "Medium"
        case 1.1..<1.5: return "Medium-High"
        default: return "High"
        }
    }
}

struct AppearanceSettingsView: View {
    @State var settings: UserSettings
    @State private var selectedColorScheme: Int
    @State private var selectedColor: UIColor
    
    init(settings: UserSettings) {
        self._settings = State(initialValue: settings)
        self._selectedColor = State(initialValue: UIColor(settings.accentColor))
        
        // Set initial value for color scheme
        if let scheme = settings.preferredColorScheme {
            self._selectedColorScheme = State(initialValue: scheme == .dark ? 2 : 1)
        } else {
            self._selectedColorScheme = State(initialValue: 0)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section {
                VStack(alignment: .leading) {
                    Text("Appearance Mode")
                        .font(.headline)
                    
                    Picker("", selection: $selectedColorScheme) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedColorScheme) { _, newValue in
                        switch newValue {
                        case 1: settings.preferredColorScheme = .light
                        case 2: settings.preferredColorScheme = .dark
                        default: settings.preferredColorScheme = nil
                        }
                    }
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading) {
                    Text("Interface Opacity")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.secondary.opacity(0.3))
                        Slider(value: $settings.interfaceOpacity, in: 0.5...1.0, step: 0.05)
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Controls how transparent or opaque the player controls appear")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                
                VStack(alignment: .leading) {
                    Text("Accent Color")
                        .font(.headline)
                    
                    ColorPicker("App accent color", selection: Binding(
                        get: { Color(uiColor: selectedColor) },
                        set: { newValue in
                            self.selectedColor = UIColor(newValue)
                            settings.accentColor = Color(uiColor: selectedColor)
                        }
                    ))
                }
                .padding(.vertical, 8)
                
            } header: {
                Text("Appearance Options")
                    .font(.headline)
            }
            
            Text("These settings control the visual appearance of the application.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Simplified appearance preview
            VStack(alignment: .leading, spacing: 10) {
                Text("Appearance Preview")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    // Light mode sample
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(
                            Circle()
                                .foregroundColor(Color(uiColor: selectedColor))
                                .frame(width: 24, height: 24)
                        )
                        .frame(width: 100, height: 60)
                        .shadow(radius: 2)
                    
                    // Dark mode sample
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .overlay(
                            Circle()
                                .foregroundColor(Color(uiColor: selectedColor))
                                .frame(width: 24, height: 24)
                        )
                        .frame(width: 100, height: 60)
                        .shadow(radius: 2)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 20)
        }
    }
}

struct CloudSyncSettingsView: View {
    @State var settings: UserSettings
    @State private var showingSyncConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section {
                Toggle("Enable Cloud Sync", isOn: $settings.enableCloudSync)
                    .padding(.vertical, 8)
                
                Toggle("Device-Specific Settings", isOn: $settings.deviceSpecificSettings)
                    .padding(.vertical, 8)
                    .onChange(of: settings.deviceSpecificSettings) { oldValue, newValue in
                        if oldValue != newValue {
                            settings.toggleDeviceSpecificSettings()
                        }
                    }
                
                VStack(alignment: .leading, spacing: 5) {
                    if let lastSync = settings.syncLastSuccessful {
                        Text("Last sync: \(formattedDate(lastSync))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never synced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: {
                        showingSyncConfirmation = true
                    }) {
                        Label("Force Sync Now", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .disabled(!settings.enableCloudSync)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Sync Options")
                    .font(.headline)
            }
            
            Text("Cloud sync allows your settings to be saved across devices and backed up to your iCloud account. Device-specific settings allow you to have different settings on each device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .alert("Sync Settings", isPresented: $showingSyncConfirmation) {
            Button("Sync", role: .none) {
                forceSync()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to manually sync your settings to iCloud now?")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func forceSync() {
        settings.syncLastAttempted = Date()  // This will trigger save() which will sync
    }
}

struct TouchDemoView: View {
    let enabled: Bool
    let showIndicator: Bool
    let sensitivity: Double
    
    @State private var touchPosition: CGPoint?
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            VStack {
                Text("Touch Preview Area")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !enabled {
                    Text("Touch Controls Disabled")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            
            if enabled && showIndicator && isPressed, let position = touchPosition {
                Circle()
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(width: 30 * sensitivity, height: 30 * sensitivity)
                    .position(position)
            }
        }
        .gesture(
            DragGesture(minimumDistance: enabled ? 0 : 1000) // Effectively disable when not enabled
                .onChanged { value in
                    touchPosition = value.location
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                    
                    // Fade out touch indicator after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            touchPosition = nil
                        }
                    }
                }
        )
    }
}

#Preview {
    SettingsView()
} 