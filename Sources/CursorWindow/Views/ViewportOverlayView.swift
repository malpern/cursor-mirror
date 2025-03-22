import SwiftUI
import CursorWindowCore

@available(macOS 14.0, *)
struct ViewportOverlayView: View {
    @EnvironmentObject var viewportManager: ViewportManager
    @State private var dragOffset: CGSize = .zero
    @State private var previousPosition: CGPoint = .zero
    
    // Constants for the glow effect
    private let glowOpacity: Double = 0.8
    private let glowRadius: CGFloat = 15
    private let glowWidth: CGFloat = 5
    private let cornerRadius: CGFloat = 55  // iPhone 15 Pro corner radius
    private let strokeWidth: CGFloat = 5
    
    var body: some View {
        ZStack {
            // Transparent background
            Color.clear
            
            // Glow effect
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.blue.opacity(glowOpacity), lineWidth: glowWidth)
                .blur(radius: glowRadius)
                .frame(
                    width: ViewportManager.viewportSize.width,
                    height: ViewportManager.viewportSize.height
                )
            
            // Main viewport border
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.blue, lineWidth: strokeWidth)
                .frame(
                    width: ViewportManager.viewportSize.width,
                    height: ViewportManager.viewportSize.height
                )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newPosition = CGPoint(
                        x: previousPosition.x + value.translation.width,
                        y: previousPosition.y - value.translation.height
                    )
                    viewportManager.updatePosition(to: newPosition)
                }
                .onEnded { _ in
                    previousPosition = viewportManager.position
                }
        )
        .onAppear {
            previousPosition = viewportManager.position
        }
    }
} 