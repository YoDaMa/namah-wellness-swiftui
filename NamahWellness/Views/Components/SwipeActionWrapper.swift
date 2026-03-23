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

    private let threshold: CGFloat = 70
    private let revealWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .leading) {
            // Background action revealed on swipe
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
        }
        .contentShape(Rectangle())
        .simultaneousGesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onChanged { value in
                let h = value.translation.width
                // Only rightward, and must be clearly horizontal (not a scroll)
                guard h > 0, abs(h) > abs(value.translation.height) * 2.0 else {
                    return
                }
                offset = min(h * 0.6, revealWidth + 20)
            }
            .onEnded { value in
                let h = value.translation.width
                if h > threshold, abs(h) > abs(value.translation.height) * 2.0 {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onAction()
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    offset = 0
                }
            }
    }
}
