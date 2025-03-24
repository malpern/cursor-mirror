import SwiftUI
import AVKit

struct PlayerView: View {
    @Bindable var viewModel: ConnectionViewModel
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isFullscreen = false
    @State private var showQualityPicker = false
    @State private var selectedQuality: StreamQuality = .auto
    @State private var showStreamInfo = false
    @State private var isTouchEnabled = false
    @State private var touchPosition: CGPoint?
    
    // Stream statistics
    @State private var bitrate: Double = 0
    @State private var frameRate: Double = 0
    @State private var bufferingState: BufferingState = .ready
    @State private var reconnectAttempts = 0
    
    // Timer for updating stream statistics
    @State private var statsTimer: Timer? = nil
    
    // Add a touchState property to track the touch state
    @State private var touchState = TouchState()
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                VStack {
                    if viewModel.connectionState.status == .error {
                        ErrorBannerView(error: viewModel.connectionState.lastError) {
                            viewModel.clearError()
                        }
                    }
                    
                    if viewModel.connectionState.status == .connected, let streamURL = viewModel.getStreamURL() {
                        ZStack {
                            VideoPlayerView(player: player)
                                .aspectRatio(isFullscreen ? nil : 393/852, contentMode: isFullscreen ? .fill : .fit) // iPhone 15 Pro aspect ratio
                                .frame(maxWidth: isFullscreen ? geometry.size.width : nil, 
                                       maxHeight: isFullscreen ? geometry.size.height : nil)
                                .cornerRadius(isFullscreen ? 0 : 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: isFullscreen ? 0 : 16)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: isFullscreen ? 0 : 1)
                                )
                                .shadow(color: .black.opacity(isFullscreen ? 0 : 0.1), radius: isFullscreen ? 0 : 10, x: 0, y: 5)
                            
                            // Touch overlay when enabled
                            if isTouchEnabled {
                                TouchOverlayView(
                                    touchPosition: $touchPosition, 
                                    isPressed: Binding<Bool>(
                                        get: { self.touchState.isPressed },
                                        set: { self.touchState.isPressed = $0 }
                                    )
                                ) { position in
                                    sendTouchEvent(at: position)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            
                            // Stream quality indicator
                            if showStreamInfo && !isFullscreen {
                                StreamInfoOverlay(
                                    bitrate: bitrate,
                                    frameRate: frameRate,
                                    bufferingState: bufferingState,
                                    quality: selectedQuality,
                                    reconnectAttempts: reconnectAttempts
                                )
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding(8)
                                .transition(.opacity)
                                .animation(.easeInOut, value: showStreamInfo)
                                .position(x: geometry.size.width - 80, y: 40)
                            }
                            
                            // Fullscreen button
                            Button(action: toggleFullscreen) {
                                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 20))
                                    .padding(12)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .foregroundStyle(.white)
                            }
                            .position(x: geometry.size.width - 40, y: isFullscreen ? geometry.size.height - 40 : 40)
                        }
                        .padding(isFullscreen ? 0 : 16)
                        .onAppear {
                            setupPlayer(with: streamURL)
                            startStatsTimer()
                        }
                        .onDisappear {
                            stopPlayer()
                            stopStatsTimer()
                        }
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded { _ in
                                    withAnimation {
                                        toggleFullscreen()
                                    }
                                }
                        )
                    } else {
                        ContentUnavailableView {
                            Label("No Stream Available", systemImage: "play.slash")
                        } description: {
                            Text(getConnectionMessage())
                        } actions: {
                            NavigationLink(destination: DeviceDiscoveryView(viewModel: viewModel)) {
                                Text("Browse Devices")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            if viewModel.connectionState.status == .error {
                                Button(action: retryConnection) {
                                    Text("Retry Connection")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    if viewModel.connectionState.status == .connected && !isFullscreen {
                        VStack(spacing: 8) {
                            PlayerControls(isPlaying: $isPlaying) {
                                togglePlayback()
                            }
                            
                            HStack {
                                // Stream quality picker button
                                Button(action: { showQualityPicker.toggle() }) {
                                    Label("Quality: \(selectedQuality.displayName)", systemImage: "gear")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.tertiarySystemBackground))
                                        .cornerRadius(8)
                                }
                                
                                Spacer()
                                
                                // Stream info toggle button
                                Button(action: { withAnimation { showStreamInfo.toggle() } }) {
                                    Label(showStreamInfo ? "Hide Info" : "Show Info", systemImage: showStreamInfo ? "info.circle.fill" : "info.circle")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.tertiarySystemBackground))
                                        .cornerRadius(8)
                                }
                                
                                Spacer()
                                
                                // Touch control toggle button
                                Button(action: { isTouchEnabled.toggle() }) {
                                    Label(isTouchEnabled ? "Touch: On" : "Touch: Off", systemImage: isTouchEnabled ? "hand.tap.fill" : "hand.tap")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.tertiarySystemBackground))
                                        .cornerRadius(8)
                                }
                            }
                            .font(.subheadline)
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                    }
                }
                .animation(.spring, value: viewModel.connectionState.status)
                .navigationTitle(isFullscreen ? "" : "Stream Player")
                .navigationBarHidden(isFullscreen)
                .sheet(isPresented: $showQualityPicker) {
                    QualityPickerView(selectedQuality: $selectedQuality, onDismiss: {
                        showQualityPicker = false
                        applyQualityChange()
                    })
                }
                .statusBarHidden(isFullscreen)
                .ignoresSafeArea(isFullscreen ? .all : .keyboard)
            }
        }
    }
    
    private func getConnectionMessage() -> String {
        switch viewModel.connectionState.status {
        case .disconnected:
            return "Connect to a device to start streaming"
        case .connecting:
            return "Connecting to device..."
        case .disconnecting:
            return "Disconnecting from stream..."
        case .error:
            return viewModel.connectionState.lastError?.localizedDescription ?? "Connection error occurred"
        default:
            return "Connect to a device to start streaming"
        }
    }
    
    private func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Set the preferred playback quality
        updatePlayerQuality()
        
        // Add observer for status changes
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
        
        // Start playback
        player?.play()
        isPlaying = true
    }
    
    private func stopPlayer() {
        player?.pause()
        player = nil
        isPlaying = false
    }
    
    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    private func toggleFullscreen() {
        withAnimation(.spring) {
            isFullscreen.toggle()
        }
    }
    
    private func applyQualityChange() {
        updatePlayerQuality()
        
        // In a real implementation, you would update the stream URL 
        // to point to the appropriate quality variant
        if let currentURL = viewModel.getStreamURL(), let player = self.player {
            // Example: For demonstration, just restart the player
            let newItem = AVPlayerItem(url: currentURL)
            player.replaceCurrentItem(with: newItem)
            player.play()
        }
    }
    
    private func updatePlayerQuality() {
        // Set preferred peakBitRate based on selected quality
        if let player = player {
            switch selectedQuality {
            case .low:
                player.currentItem?.preferredPeakBitRate = 1_500_000 // 1.5 Mbps
            case .medium:
                player.currentItem?.preferredPeakBitRate = 4_000_000 // 4 Mbps
            case .high:
                player.currentItem?.preferredPeakBitRate = 8_000_000 // 8 Mbps
            case .auto:
                player.currentItem?.preferredPeakBitRate = 0 // Auto
            }
        }
    }
    
    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateStreamStats()
        }
    }
    
    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    private func updateStreamStats() {
        guard let player = player, let playerItem = player.currentItem else { return }
        
        // Update bitrate (from AVPlayer accessLog if available)
        if let accessLog = playerItem.accessLog(),
           let lastEvent = accessLog.events.last {
            bitrate = lastEvent.indicatedBitrate
            
            // Note: AVPlayerItemAccessLogEvent doesn't have indicatedFrameRate in all iOS versions
            // Using a fixed value for demonstration purposes
            frameRate = 30.0
        }
        
        // Update buffering state
        if playerItem.isPlaybackBufferEmpty {
            bufferingState = .buffering
        } else if playerItem.isPlaybackLikelyToKeepUp {
            bufferingState = .ready
        }
    }
    
    private func retryConnection() {
        guard viewModel.connectionState.status == .error else { return }
        
        // Clear errors
        viewModel.clearError()
        reconnectAttempts += 1
        
        // If we have a selected device, try to reconnect
        if let selectedDevice = viewModel.connectionState.selectedDevice {
            viewModel.connectToDevice(selectedDevice)
        } else {
            // Otherwise, go back to device discovery
            viewModel.startDeviceDiscovery()
        }
    }
    
    private func sendTouchEvent(at position: CGPoint) {
        // Calculate as percentage of viewport size
        let containerSize = CGSize(width: ViewportSize.width, height: ViewportSize.height)
        
        // Calculate normalized position (0-1)
        let percentX = position.x / containerSize.width
        let percentY = position.y / containerSize.height
        
        // Store touch position for visual feedback
        touchPosition = position
        
        // Determine the touch event type based on the touch state
        var touchType: TouchEventType
        
        if !touchState.isPressed {
            // Touch has ended
            touchType = .ended
        } else if touchPosition == nil {
            // First touch
            touchType = .began
        } else {
            // Moving touch
            touchType = .moved
        }
        
        // Create and send the touch event
        let touchEvent = TouchEvent(
            type: touchType,
            percentX: Double(percentX),
            percentY: Double(percentY)
        )
        
        // Send the event asynchronously
        Task {
            await viewModel.sendTouchEvent(touchEvent)
            
            // If this was an ended event, clear the touch position after sending
            if touchType == .ended {
                touchPosition = nil
            }
        }
    }
}

// MARK: - Supporting Views

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer?
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

struct PlayerControls: View {
    @Binding var isPlaying: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Spacer()
            
            Button(action: toggleAction) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

struct StreamInfoOverlay: View {
    let bitrate: Double
    let frameRate: Double
    let bufferingState: BufferingState
    let quality: StreamQuality
    let reconnectAttempts: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quality: \(quality.displayName)")
                .font(.caption)
                .bold()
            
            Text(String(format: "Bitrate: %.1f Mbps", bitrate / 1_000_000))
                .font(.caption)
            
            Text(String(format: "FPS: %.1f", frameRate))
                .font(.caption)
            
            HStack {
                Circle()
                    .fill(bufferingState == .ready ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(bufferingState.description)
                    .font(.caption)
            }
            
            if reconnectAttempts > 0 {
                Text("Reconnects: \(reconnectAttempts)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .foregroundStyle(.white)
        .padding(8)
    }
}

struct QualityPickerView: View {
    @Binding var selectedQuality: StreamQuality
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(StreamQuality.allCases, id: \.self) { quality in
                    Button(action: {
                        selectedQuality = quality
                        onDismiss()
                    }) {
                        HStack {
                            Text(quality.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if quality == selectedQuality {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stream Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct TouchOverlayView: View {
    @Binding var touchPosition: CGPoint?
    @Binding var isPressed: Bool
    let onTouch: (CGPoint) -> Void
    
    var body: some View {
        ZStack {
            Color.clear
            
            if let position = touchPosition {
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 30, height: 30)
                    .position(position)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let position = value.location
                    
                    // Update state
                    touchPosition = position
                    isPressed = true
                    
                    // Pass to handler
                    onTouch(position)
                }
                .onEnded { _ in
                    // Mark as ended
                    isPressed = false
                    
                    // Send the ended event with the last known position
                    if let lastPosition = touchPosition {
                        onTouch(lastPosition)
                    }
                    
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

// MARK: - Helper Types

enum StreamQuality: String, CaseIterable {
    case auto
    case low
    case medium
    case high
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .low: return "Low (480p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        }
    }
}

enum BufferingState {
    case buffering
    case ready
    
    var description: String {
        switch self {
        case .buffering: return "Buffering"
        case .ready: return "Ready"
        }
    }
}

// Add a TouchState class to track touch state
class TouchState: ObservableObject {
    @Published var isPressed = false
}

#Preview {
    let viewModel = ConnectionViewModel()
    return PlayerView(viewModel: viewModel)
} 