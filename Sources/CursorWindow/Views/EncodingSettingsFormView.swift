import SwiftUI
import CursorWindowCore

struct EncodingSettingsFormView: View {
    let settings: EncodingSettings
    let onUpdate: (EncodingSettings.Update) async -> Void
    
    var body: some View {
        Form {
            Section(header: Text("Output Settings")) {
                TextField("Output Path", text: Binding(
                    get: { settings.outputPath },
                    set: { newValue in
                        Task {
                            await onUpdate(.outputPath(newValue))
                        }
                    }
                ))
                
                HStack {
                    TextField("Width", value: Binding(
                        get: { settings.width },
                        set: { newValue in
                            Task {
                                await onUpdate(.width(newValue))
                            }
                        }
                    ), format: .number)
                    Text("x")
                    TextField("Height", value: Binding(
                        get: { settings.height },
                        set: { newValue in
                            Task {
                                await onUpdate(.height(newValue))
                            }
                        }
                    ), format: .number)
                }
                
                Slider(value: Binding(
                    get: { settings.frameRate },
                    set: { newValue in
                        Task {
                            await onUpdate(.frameRate(newValue))
                        }
                    }
                ), in: 1...60, step: 1) {
                    Text("Frame Rate: \(Int(settings.frameRate)) fps")
                }
                
                Slider(value: Binding(
                    get: { settings.quality },
                    set: { newValue in
                        Task {
                            await onUpdate(.quality(newValue))
                        }
                    }
                ), in: 0...1, step: 0.1) {
                    Text("Quality: \(Int(settings.quality * 100))%")
                }
            }
        }
        .padding()
    }
} 