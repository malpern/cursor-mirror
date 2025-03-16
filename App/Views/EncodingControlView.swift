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
            frameProcessor.handleError(error)
        }
    }
    
    private func stopEncoding() {
        frameProcessor.stopEncoding()
        isEncoding = false
    }
    
    private func startRecording() {
        do {
            // Create a temporary file for the encoded video
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("temp_encoded_video_\(UUID().uuidString).mp4")
            recordingURL = tempFile
            
            let dimensions = resolution.dimensions
            try frameProcessor.startRecording(
                to: tempFile,
                width: dimensions.width,
                height: dimensions.height,
                frameRate: frameRate
            )
            
            isRecording = true
            encodingStartTime = Date()
            
        } catch {
            frameProcessor.handleError(error)
        }
    }
    
    private func stopRecording() async {
        do {
            if let finalURL = try await frameProcessor.stopRecording() {
                // Show save panel
                showSavePanel = true
                
                // Use the system save panel
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.mpeg4Movie]
                savePanel.canCreateDirectories = true
                savePanel.isExtensionHidden = false
                savePanel.title = "Save Recorded Video"
                savePanel.message = "Choose a location to save your recorded video"
                savePanel.nameFieldLabel = "File name:"
                savePanel.nameFieldStringValue = "recorded_video.mp4"
                
                let response = await savePanel.beginSheetModal(for: NSApp.keyWindow!)
                
                if response == .OK, let url = savePanel.url {
                    // Copy the temporary file to the selected location
                    try FileManager.default.copyItem(at: finalURL, to: url)
                    
                    // Delete the temporary file
                    try? FileManager.default.removeItem(at: finalURL)
                    
                    // Update the saved URL
                    savedVideoURL = url
                    showingSavedAlert = true
                }
            }
        } catch {
            frameProcessor.handleError(error)
        }
        
        isRecording = false
    }
    
    private func resetStats() {
        encodedFrameCount = 0
        encodedDataSize = 0
        encodingStartTime = nil
        frameProcessor.error = nil
        savedVideoURL = nil
    }
    
    private func formattedDuration(since startTime: Date) -> String {
        let duration = Int(-startTime.timeIntervalSinceNow)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formattedDataSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// Document type for file exporter
struct EncodedVideoDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.mpeg4Movie] }
    
    var url: URL?
    
    init(url: URL?) {
        self.url = url
    }
    
    init(configuration: ReadConfiguration) throws {
        url = nil
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url, let data = try? Data(contentsOf: url) else {
            throw CocoaError(.fileReadUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

struct EncodingControlView_Previews: PreviewProvider {
    static var previews: some View {
        EncodingControlView(
            frameProcessor: EncodingFrameProcessor(
                encoder: H264VideoEncoder(),
                frameRate: 30
            )
        )
        .frame(width: 500, height: 600)
    }
} 