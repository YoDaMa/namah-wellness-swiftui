import SwiftUI

/// Three-dot evidence indicator replacing verbose text pills.
/// Tap for tooltip. Compact, scannable, doesn't interrupt reading flow.
struct EvidenceBadge: View {
    let level: String

    private var filledCount: Int {
        switch level {
        case "strong": return 3
        case "moderate": return 2
        case "emerging": return 1
        case "expert_opinion": return 1
        default: return 0
        }
    }

    private var label: String {
        switch level {
        case "strong": return "Strong evidence"
        case "moderate": return "Moderate evidence"
        case "emerging": return "Emerging research"
        case "expert_opinion": return "Expert opinion"
        default: return level
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < filledCount ? Color.primary.opacity(0.5) : Color.primary.opacity(0.12))
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(.sans(9))
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
        }
        .accessibilityLabel(label)
    }
}
