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

            Text("Day \(phase.cycleDay) · \(phase.phaseName) Phase")
                .font(.bodyMedium(9))
                .textCase(.uppercase)
                .tracking(2.5)
                .foregroundStyle(.muted)
        }
    }
}
