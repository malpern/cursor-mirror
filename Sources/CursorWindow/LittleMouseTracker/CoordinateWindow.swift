import SwiftUI

struct CoordinateWindow: View {
    @Binding var mouseLocation: NSPoint
    @Binding var isHovering: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current mouse position:")
                .font(.subheadline)
            
            Text("X: \(Int(mouseLocation.x)), Y: \(Int(mouseLocation.y))")
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            
            Text(isHovering ? "HOVERED" : "NOT HOVERED")
                .font(.system(.body, design: .rounded).bold())
                .foregroundColor(isHovering ? .red : .primary)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(isHovering ? Color.red.opacity(0.1) : Color.gray.opacity(0.05))
                .cornerRadius(4)
        }
        .padding()
        .frame(minWidth: 230)
        .background(Color.white)
    }
} 