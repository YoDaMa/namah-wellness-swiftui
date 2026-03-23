import SwiftUI

/// Wraps content with a leading swipe-to-reveal action.
/// Works in VStack/LazyVStack contexts (not List-dependent).
struct SwipeActionWrapper<Content: View>: View {
    let actionLabel: String
    let actionIcon: String
    let actionColor: Color
    let onAction: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isRevealed = false

    private let threshold: CGFloat = 70
    private let revealWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .leading) {
            // Background action
            HStack(spacing: 6) {
                Image(systemName: actionIcon)
                    .font(.system(size: 14, weight: .semibold))
                Text(actionLabel)
                    .font(.nCaption2)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .frame(width: revealWidth)
            .frame(maxHeight: .infinity)
            .background(actionColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(offset > 10 ? 1 : 0)

            // Main content
            content()
                .offset(x: offset)
                .gesture(swipeGesture)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let h = value.translation.width
                // Only allow rightward swipe, with resistance
                guard h > 0 else {
                    // Allow snapping back
                    if isRevealed {
                        withAnimation(.easeOut(duration: 0.2)) {
                            offset = 0
                            isRevealed = false
                        }
                    }
                    return
                }
                guard abs(h) > abs(value.translation.height) * 1.2 else { return }
                offset = min(h * 0.6, revealWidth + 20) // Rubber band effect
            }
            .onEnded { value in
                let h = value.translation.width
                if h > threshold {
                    // Trigger action
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onAction()
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset = 0
                        isRevealed = false
                    }
                } else {
                    // Snap back
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = 0
                        isRevealed = false
                    }
                }
            }
    }
}
