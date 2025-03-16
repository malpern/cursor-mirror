import SwiftUI
import AVFoundation

struct EncodingControlView: View {
    @ObservedObject var frameProcessor: EncodingFrameProcessor
    @State private var isEncoding = false
    @State private var isRecording = false
    @State private var encodedFrameCount = 0
    @State private var encodedDataSize: Int64 = 0
    @State private var encodingStartTime: Date?
    @State private var frameRate: Int = 30
    @State private var resolution = Resolution.hd720p
    @State private var showSavePanel = false
    @State private var recordingURL: URL?
    @State private var savedVideoURL: URL?
    @State private var showingSavedAlert = false
    
    enum Resolution: String, CaseIterable, Identifiable {
        case sd480p = "480p (854x480)"
        case hd720p = "720p (1280x720)"
        case hd1080p = "1080p (1920x1080)"
        
        var id: String { self.rawValue }
        
        var dimensions: (width: Int, height: Int) {
            switch self {
            case .sd480p: return (854, 480)
            case .hd720p: return (1280, 720)
            case .hd1080p: return (1920, 1080)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Preview image
            if let image = frameProcessor.latestImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        Text("No preview available")
                            .foregroundColor(.secondary)
                    )
            }
            
            // Error display
            if let error = frameProcessor.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Encoding status
            Group {
                HStack {
                    Text("Status:")
                        .bold()
                    Text(statusText)
                        .foregroundColor(statusColor)
                }
                
                if isEncoding || isRecording, let startTime = encodingStartTime {
                    HStack {
                        Text("Duration:")
                            .bold()
                        Text(formattedDuration(since: startTime))
                    }
                }
                
                HStack {
                    Text("Frames encoded:")
                        .bold()
                    Text("\(encodedFrameCount)")
                }
                
                HStack {
                    Text("Data size:")
                        .bold()
                    Text(formattedDataSize(encodedDataSize))
                }
            }
            .font(.system(.body, design: .monospaced))
            
            Divider()
            
            // Encoding settings
            Group {
                HStack {
                    Text("Resolution:")
                        .bold()
                        .frame(width: 100, alignment: .leading)
                    
                    Picker("", selection: $resolution) {
                        ForEach(Resolution.allCases) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    .pickerStyle(PopUpButtonPickerStyle())
                    .disabled(isEncoding || isRecording)
                }
                
                HStack {
                    Text("Frame rate:")
                        .bold()
                        .frame(width: 100, alignment: .leading)
                    
                    Slider(value: Binding(
                        get: { Double(frameRate) },
                        set: { frameRate = Int($0) }
                    ), in: 1...60, step: 1)
                    .disabled(isEncoding || isRecording)
                    
                    Text("\(frameRate) fps")
                        .frame(width: 60)
                }
            }
            
            Divider()
            
            // Control buttons
            HStack {
                Button(action: toggleEncoding) {
                    Text(isEncoding ? "Stop Encoding" : "Start Encoding")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(isEncoding ? .red : .green)
                .disabled(isRecording)
                
                Button(action: toggleRecording) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : .blue)
                .disabled(isEncoding)
                
                Spacer()
                
                Button("Reset") {
                    resetStats()
                }
                .buttonStyle(.bordered)
                .disabled(isEncoding || isRecording)
            }
            
            if let savedURL = savedVideoURL {
                HStack {
                    Text("Saved to:")
                        .bold()
                    Text(savedURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(savedURL.path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .onAppear {
            setupCallbacks()
        }
        .alert("Video Saved", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
            Button("Show in Finder") {
                if let url = savedVideoURL {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
            }
        } message: {
            if let url = savedVideoURL {
                Text("Video has been saved to:\n\(url.path)")
            } else {
                Text("Video has been saved successfully.")
            }
        }
    }
    
    private var statusText: String {
        if isRecording {
            return "Recording"
        } else if isEncoding {
            return "Encoding"
        } else {
            return "Idle"
        }
    }
    
    private var statusColor: Color {
        if isRecording {
            return .red
        } else if isEncoding {
            return .green
        } else {
            return .secondary
        }
    }
    
    private func setupCallbacks() {
        frameProcessor.setEncodedFrameCallback { data, time in
            DispatchQueue.main.async {
                encodedFrameCount += 1
                encodedDataSize += Int64(data?.count ?? 0)
            }
        }
    }
    
    private func toggleEncoding() {
        if isEncoding {
            stopEncoding()
        } else {
            startEncoding()
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            Task {
                await stopRecording()
            }
        } else {
            startRecording()
        }
    }
    
    private func startEncoding() {
        do {
            let dimensions = resolution.dimensions
            try frameProcessor.startEncoding(
                width: dimensions.width,
                height: dimensions.height,
                frameRate: frameRate
            )
            isEncoding = true
            encodingStartTime = Date()
        } catch {
            print("Failed to start encoding: \(error)")
        }
    }
    
    private func stopEncoding() {
        do {
            try frameProcessor.stopEncoding()
            isEncoding = false
        } catch {
            print("Failed to stop encoding: \(error)")
        }
    }
    
    private func startRecording() {
        showSavePanel = true
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.mpeg4Movie]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Video As"
        savePanel.message = "Choose a location to save the encoded video"
        savePanel.nameFieldLabel = "File name:"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let dimensions = resolution.dimensions
                try frameProcessor.startRecording(
                    toFile: url,
                    width: dimensions.width,
                    height: dimensions.height,
                    frameRate: frameRate
                )
                isRecording = true
                encodingStartTime = Date()
                recordingURL = url
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }
    
    private func stopRecording() async {
        do {
            try await frameProcessor.stopRecording()
            isRecording = false
            if let url = recordingURL {
                savedVideoURL = url
                showingSavedAlert = true
            }
        } catch {
            print("Failed to stop recording: \(error)")
        }
    }
    
    private func resetStats() {
        encodedFrameCount = 0
        encodedDataSize = 0
        encodingStartTime = nil
    }
    
    private func formattedDuration(since date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formattedDataSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// Preview provider
struct EncodingControlView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock frame processor for preview
        let mockProcessor = EncodingFrameProcessor(encoder: H264VideoEncoder())
        return EncodingControlView(frameProcessor: mockProcessor)
            .frame(width: 600, height: 700)
            .padding()
    }
} 