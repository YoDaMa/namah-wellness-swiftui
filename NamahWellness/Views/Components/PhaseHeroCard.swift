import SwiftUI

struct PhaseHeroCard: View {
    let phase: PhaseInfo
    let cycleStats: CycleStats
    let heroTitle: String?
    let heroSubtitle: String?
    let exerciseIntensity: String?

    init(phase: PhaseInfo, cycleStats: CycleStats, heroTitle: String? = nil, heroSubtitle: String? = nil, exerciseIntensity: String? = nil) {
        self.phase = phase
        self.cycleStats = cycleStats
        self.heroTitle = heroTitle
        self.heroSubtitle = heroSubtitle
        self.exerciseIntensity = exerciseIntensity
    }

    private var phaseColors: PhaseColors {
        PhaseColors.forSlug(phase.phaseSlug)
    }

    /// Extract the tagline from heroTitle (e.g., "Restore & Replenish" from "Menstrual — Restore & Replenish")
    private var tagline: String? {
        guard let title = heroTitle else { return nil }
        if let dashRange = title.range(of: " \u{2014} ") {
            return String(title[dashRange.upperBound...])
        }
        return title
    }

    /// First sentence of the subtitle (split on ". " and take the first).
    private var firstSentence: String? {
        guard let subtitle = heroSubtitle, !subtitle.isEmpty else { return nil }
        if let dotSpace = subtitle.range(of: ". ") {
            return String(subtitle[..<dotSpace.upperBound]).trimmingCharacters(in: .whitespaces)
        }
        return subtitle
    }

    /// Estimated card height so GeometryReader has an explicit frame.
    private var estimatedHeight: CGFloat {
        var h: CGFloat = 32   // vertical padding (16 top + 16 bottom)
        h += 18               // phase dot row
        h += 10               // spacing
        if tagline != nil {
            h += 34            // tagline
            h += 10            // spacing
        }
        if firstSentence != nil {
            h += 20            // description sentence
            h += 10            // spacing
        }
        h += 16               // day info line
        if phase.isOverridden {
            h += 10            // spacing
            h += 14            // override text
        }
        return h
    }

    var body: some View {
        GeometryReader { geo in
            let parallaxOffset = geo.frame(in: .global).minY * 0.05

            ZStack(alignment: .leading) {
                // Flat phase color base
                RoundedRectangle(cornerRadius: NamahRadius.medium)
                    .fill(phaseColors.mid)

                // Signature shape overlay with parallax
                PhaseColors.shapeOverlay(for: phase.phaseSlug)
                    .offset(y: parallaxOffset)
                    .clipShape(RoundedRectangle(cornerRadius: NamahRadius.medium))

                // Card content — unchanged
                VStack(alignment: .leading, spacing: 10) {
                    // Phase dot + label
                    HStack {
                        Circle()
                            .fill(phaseColors.color)
                            .frame(width: 10, height: 10)
                        Text(phase.phaseName.uppercased())
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .tracking(2)
                            .foregroundStyle(.secondary)
                    }

                    // Tagline as large display title
                    if let tagline {
                        Text(tagline)
                            .font(.display(26))
                            .foregroundStyle(.primary)
                    }

                    // Description — first sentence only, never truncated
                    if let sentence = firstSentence {
                        Text(sentence)
                            .font(.prose(13, relativeTo: .footnote))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Day info — plain text, no icons
                    Text("Day \(phase.dayInPhase) · Cycle day \(phase.cycleDay)/\(cycleStats.avgCycleLength)")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)

                    if phase.isOverridden {
                        Text("Manual override active")
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.spice)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: estimatedHeight)
    }
}
