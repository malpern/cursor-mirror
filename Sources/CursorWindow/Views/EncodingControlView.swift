import SwiftUI
import CursorWindowCore

struct EncodingControlView: View {
    let viewModel: EncodingControlViewModel
    @State private var isEncoding: Bool = false
    @State private var showEncodingSettings = false
    @State private var localSettings: EncodingSettings?
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isLoading {
                ProgressView("Loading settings...")
            } else if let settings = localSettings {
                Text("Encoding Settings")
                    .font(.headline)
                    .padding(.bottom)
                
                HStack {
                    Text("Output File:")
                    TextField("Output Path", text: Binding(
                        get: { settings.outputPath },
                        set: { newValue in
                            Task {
                                await settings.apply(.outputPath(newValue))
                            }
                        }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Browse") {
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.mpeg4Movie]
                        panel.canCreateDirectories = true
                        
                        if panel.runModal() == .OK, let url = panel.url {
                            Task {
                                await settings.apply(.outputPath(url.path))
                            }
                        }
                    }
                }
                
                HStack {
                    Text("Resolution:")
                    TextField("Width", value: Binding(
                        get: { settings.width },
                        set: { newValue in
                            Task {
                                await settings.apply(.width(newValue))
                            }
                        }
                    ), format: .number)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("x")
                    TextField("Height", value: Binding(
                        get: { settings.height },
                        set: { newValue in
                            Task {
                                await settings.apply(.height(newValue))
                            }
                        }
                    ), format: .number)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Button(isEncoding ? "Stop Encoding" : "Start Encoding") {
                        if isEncoding {
                            Task {
                                await viewModel.stopEncoding()
                                isEncoding = false
                            }
                        } else {
                            Task {
                                do {
                                    try await viewModel.startEncoding()
                                    isEncoding = true
                                } catch {
                                    print("Error starting encoding: \(error)")
                                }
                            }
                        }
                    }
                    .padding()
                    .background(isEncoding ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
            }
        }
        .padding()
        .task {
            do {
                localSettings = await viewModel.encodingSettings
                isLoading = false
            } catch {
                print("Error loading settings: \(error)")
            }
        }
    }
} 