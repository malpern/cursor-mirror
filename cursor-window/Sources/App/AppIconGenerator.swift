import SwiftUI

struct AppIconGenerator: View {
    var body: some View {
        Image(systemName: "macwindow")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.blue)
            .font(.system(size: 800))
            .frame(width: 1024, height: 1024)
    }
}

#Preview {
    AppIconGenerator()
} 