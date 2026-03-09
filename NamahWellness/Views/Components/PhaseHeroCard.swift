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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: phase label + chevron
            HStack {
                Circle()
                    .fill(phaseColors.color)
                    .frame(width: 10, height: 10)
                Text(phase.phaseName.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }

            // Phase name + tagline
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.phaseName + " Phase")
                    .font(.heading(24))
                    .foregroundStyle(.primary)
                if let tagline {
                    Text(tagline)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(phaseColors.color)
                }
            }

            // Call to action / motivational description
            if let subtitle = heroSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Day info + exercise intensity
            HStack(spacing: 12) {
                Label("Day \(phase.dayInPhase)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Cycle day \(phase.cycleDay)/\(cycleStats.avgCycleLength)", systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let intensity = exerciseIntensity {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 9))
                        Text(intensity)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            if phase.isOverridden {
                Text("Manual override active")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.spice)
            }
        }
        .padding(16)
        .background(phaseColors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
