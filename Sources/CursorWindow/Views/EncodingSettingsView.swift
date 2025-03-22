import SwiftUI
import CursorWindowCore

@available(macOS 14.0, *)
struct EncodingSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var settings: EncodingSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Encoding Settings")
                .font(.headline)
                .padding(.bottom)
            
            HStack {
                Text("Output File:")
                TextField("Output Path", text: $settings.outputPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Browse") {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.mpeg4Movie]
                    panel.canCreateDirectories = true
                    
                    if panel.runModal() == .OK, let url = panel.url {
                        settings.outputPath = url.path
                    }
                }
            }
            
            HStack {
                Text("Resolution:")
                TextField("Width", value: $settings.width, formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("x")
                TextField("Height", value: $settings.height, formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Text("Frame Rate:")
                TextField("FPS", value: $settings.frameRate, formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("fps")
            }
            
            HStack {
                Text("Quality:")
                Slider(value: $settings.quality, in: 0.1...1.0, step: 0.1)
                Text(String(format: "%.1f", settings.quality))
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500)
    }
} 