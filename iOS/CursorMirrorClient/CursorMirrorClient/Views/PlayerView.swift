import SwiftUI
import AVKit

struct PlayerView: View {
    @Bindable var viewModel: ConnectionViewModel
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.connectionState.status == .error {
                    ErrorBannerView(error: viewModel.connectionState.lastError) {
                        viewModel.clearError()
                    }
                }
                
                if viewModel.connectionState.status == .connected, let streamURL = viewModel.getStreamURL() {
                    VideoPlayerView(player: player)
                        .aspectRatio(393/852, contentMode: .fit) // iPhone 15 Pro aspect ratio
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding()
                        .onAppear {
                            setupPlayer(with: streamURL)
                        }
                        .onDisappear {
                            stopPlayer()
                        }
                } else {
                    ContentUnavailableView {
                        Label("No Stream Available", systemImage: "play.slash")
                    } description: {
                        Text("Connect to a device to start streaming")
                    } actions: {
                        NavigationLink(destination: DeviceDiscoveryView(viewModel: viewModel)) {
                            Text("Browse Devices")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                if viewModel.connectionState.status == .connected {
                    PlayerControls(isPlaying: $isPlaying) {
                        togglePlayback()
                    }
                    .padding()
                }
            }
            .animation(.spring, value: viewModel.connectionState.status)
            .navigationTitle("Stream Player")
        }
    }
    
    private func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
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
}

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
            
            Spacer()
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

#Preview {
    let viewModel = ConnectionViewModel()
    return PlayerView(viewModel: viewModel)
} 