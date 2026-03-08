import SwiftUI

struct PhaseHeroCard: View {
    let phase: PhaseInfo
    let cycleStats: CycleStats

    private var phaseColors: PhaseColors {
        PhaseColors.forSlug(phase.phaseSlug)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(phaseColors.color)
                    .frame(width: 10, height: 10)
                Text(phase.phaseName.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Text(phase.phaseName + " Phase")
                .font(.heading(24))
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                Label("Day \(phase.dayInPhase) of phase", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Cycle day \(phase.cycleDay) of \(cycleStats.avgCycleLength)", systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if phase.isOverridden {
                Text("Manual override active")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.spice)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(phaseColors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
