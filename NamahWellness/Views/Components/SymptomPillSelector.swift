import SwiftUI

/// A row of tappable pill buttons for symptom logging.
/// Tap to select, tap again to deselect (returns to nil/unlogged).
/// No default selection — all pills start unselected.
struct SymptomPillSelector: View {
    let options: [String]
    /// 1-based: first pill = 1, second = 2, etc. nil = unlogged.
    @Binding var selection: Int?
    let accentColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, label in
                let value = index + 1 // 1-based
                let isSelected = selection == value

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selection = isSelected ? nil : value
                    }
                } label: {
                    Text(label)
                        .font(.nCaption2)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? accentColor : Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: selection)
            }
        }
    }
}
