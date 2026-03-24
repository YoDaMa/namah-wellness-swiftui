import SwiftUI

/// Renders a single phase insight/reminder with bold headline, body text, and evidence badge.
/// Shared between InsightsSheetView and PhaseDetailView.
struct InsightRowView: View {
    let text: String
    let evidenceLevel: String?
    var showIcon: Bool = false
    var horizontalPadding: CGFloat = 14

    var body: some View {
        let parts = splitHeadline(text)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                if showIcon {
                    Image(systemName: NamahIcons.forReminder(text))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                }
                Text(parts.headline)
                    .font(.proseBold(13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !parts.body.isEmpty {
                Text(parts.body)
                    .font(.prose(12))
                    .foregroundStyle(.primary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }

            if let level = evidenceLevel, !level.isEmpty {
                EvidenceBadge(level: level)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 12)
    }

    private func splitHeadline(_ text: String) -> (headline: String, body: String) {
        if let dotRange = text.range(of: ". ") {
            let headline = String(text[text.startIndex...dotRange.lowerBound])
            let body = String(text[dotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (headline, body)
        }
        return (text, "")
    }
}
