import SwiftUI

struct PhaseHeaderView: View {
    let phase: PhaseInfo

    private var phaseColors: PhaseColors {
        PhaseColors.forSlug(phase.phaseSlug)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(phaseColors.color)
                .frame(width: 10, height: 10)

            Text("Day \(phase.cycleDay) \u{00b7} \(phase.phaseName) Phase")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
