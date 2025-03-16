import SwiftUI
import CursorWindowCore

struct ViewportSize {
    static let width: CGFloat = 393
    static let height: CGFloat = 852
    static let strokeWidth: CGFloat = 5
    static let cornerRadius: CGFloat = 55  // iPhone 15 Pro corner radius
}

struct DraggableViewport: View {
    @StateObject var viewportState = ViewportState()
    @EnvironmentObject var screenCaptureManager: ScreenCaptureManager
    
    // Constants for the glow effect
    private let glowOpacity: Double = 0.8
    private let glowRadius: CGFloat = 15
    private let glowWidth: CGFloat = 5
    private let hitTestingBuffer: CGFloat = 60  // Buffer zone for dragging
    
    var body: some View {
        ZStack {
            // Permission request overlay if needed
            if !screenCaptureManager.isScreenCapturePermissionGranted {
                Button("Request Screen Capture Permission") {
                    Task {
                        // Create a temporary frame processor just for permission request
                        let tempProcessor = BasicFrameProcessor()
                        try? await screenCaptureManager.startCapture(frameProcessor: tempProcessor)
                        // We'll stop capture immediately since this is just for permission
                        try? await screenCaptureManager.stopCapture()
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Invisible hit testing area that extends inside and outside
            RoundedRectangle(cornerRadius: ViewportSize.cornerRadius)
                .fill(Color.clear)
                .frame(
                    width: ViewportSize.width + hitTestingBuffer * 2,
                    height: ViewportSize.height + hitTestingBuffer * 2
                )
                .contentShape(Rectangle())
                .offset(viewportState.offset)
            
            // Center area that allows click-through
            RoundedRectangle(cornerRadius: ViewportSize.cornerRadius)
                .fill(Color.clear)
                .frame(
                    width: ViewportSize.width - hitTestingBuffer * 2,
                    height: ViewportSize.height - hitTestingBuffer * 2
                )
                .contentShape(Rectangle())
                .allowsHitTesting(false)
                .offset(viewportState.offset)
            
            // Glow effect
            RoundedRectangle(cornerRadius: ViewportSize.cornerRadius)
                .strokeBorder(Color.blue.opacity(glowOpacity), lineWidth: glowWidth)
                .blur(radius: glowRadius)
                .frame(
                    width: ViewportSize.width + glowRadius * 2,
                    height: ViewportSize.height + glowRadius * 2
                )
                .offset(viewportState.offset)
                .allowsHitTesting(false)
            
            // Main viewport border
            RoundedRectangle(cornerRadius: ViewportSize.cornerRadius)
                .strokeBorder(Color.blue, lineWidth: ViewportSize.strokeWidth)
                .frame(width: ViewportSize.width, height: ViewportSize.height)
                .offset(viewportState.offset)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(DragGesture()
            .onChanged { gesture in
                viewportState.updateOffset(with: gesture.translation)
            }
            .onEnded { _ in
                viewportState.finalizeDrag()
            }
        )
    }
}

@MainActor
final class ViewportState: ObservableObject {
    @Published var offset: CGSize = .zero
    private var previousOffset: CGSize = .zero
    
    private var screenBounds: CGRect {
        NSScreen.main?.visibleFrame ?? .zero
    }
    
    func updateOffset(with translation: CGSize) {
        let proposedOffset = CGSize(
            width: translation.width + previousOffset.width,
            height: translation.height + previousOffset.height
        )
        
        // Calculate the viewport bounds
        let viewportWidth = ViewportSize.width
        let viewportHeight = ViewportSize.height
        
        // Calculate maximum allowed offsets to keep viewport on screen
        let maxX = (screenBounds.width - viewportWidth) / 2
        let maxY = (screenBounds.height - viewportHeight) / 2
        
        // Constrain the offset within screen bounds
        offset = CGSize(
            width: max(-maxX, min(maxX, proposedOffset.width)),
            height: max(-maxY, min(maxY, proposedOffset.height))
        )
    }
    
    func finalizeDrag() {
        previousOffset = offset
    }
} 