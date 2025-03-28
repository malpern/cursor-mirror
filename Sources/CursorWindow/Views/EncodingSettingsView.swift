import SwiftUI
import CursorWindowCore

struct EncodingSettingsView: View {
    @ObservedObject var settings: EncodingSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            EncodingSettingsFormView(
                settings: settings,
                onUpdate: { update in
                    await settings.apply(update)
                }
            )
            .navigationTitle("Encoding Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 