import SwiftUI

/// Protocol for views that can be tagged for testing
protocol TaggedView {
    var tag: Any { get }
}

extension View {
    func tag(_ tag: Any) -> some View {
        modifier(ViewTagModifier(tag: tag))
    }
}

private struct ViewTagModifier: ViewModifier {
    let tag: Any
    
    func body(content: Content) -> some View {
        content.background(
            TaggedViewWrapper(tag: tag)
                .frame(width: 0, height: 0)
                .hidden()
        )
    }
}

private struct TaggedViewWrapper: View, TaggedView {
    let tag: Any
    
    var body: some View {
        EmptyView()
    }
} 