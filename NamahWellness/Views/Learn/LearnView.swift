import SwiftUI
import SwiftData

struct LearnView: View {
    let cycleService: CycleService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Framing copy
                    Text("Everything about your cycle, backed by science.")
                        .font(.prose(15))
                        .foregroundStyle(.secondary)

                    // Reference section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REFERENCE")
                            .namahLabel()

                        hormonesCard
                    }

                    // Phase grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("YOUR CYCLE")
                            .namahLabel()

                        phaseGrid
                    }
                }
                .padding()
            }
            .background(Color.paper.ignoresSafeArea())
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Learn")
        }
    }

    // MARK: - Hormones Card

    private var hormonesCard: some View {
        NavigationLink {
            HormonesView(cycleService: cycleService)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.sans(22))
                        .foregroundStyle(.phaseO)
                        .frame(width: 40, height: 40)
                        .background(Color.phaseOSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hormone Curves")
                            .font(.nSubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Estrogen, progesterone, LH & FSH across your cycle")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.nCaption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }

                // Mini preview bar
                HStack(spacing: 2) {
                    ForEach(0..<28, id: \.self) { day in
                        let slug = phaseForDay(day + 1)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(PhaseColors.forSlug(slug).color.opacity(0.6))
                            .frame(height: 4)
                    }
                }
                .clipShape(Capsule())
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.phaseO.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phase Grid (2×2)

    private var phaseGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(phases, id: \.id) { phase in
                NavigationLink {
                    PhaseDetailView(phase: phase, cycleService: cycleService)
                } label: {
                    phaseGridCard(phase)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func phaseGridCard(_ phase: Phase) -> some View {
        let colors = PhaseColors.forSlug(phase.slug)
        let isCurrent = cycleService.currentPhase?.phaseSlug == phase.slug

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(colors.color)
                    .frame(width: 10, height: 10)
                Spacer()
                if isCurrent {
                    Text("NOW")
                        .font(.sans(8))
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colors.color)
                        .clipShape(Capsule())
                }
            }

            Text(phase.name)
                .font(.nSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("Days \(phase.dayStart)\u{2013}\(phase.dayEnd)")
                .font(.nCaption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.nCaption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(colors.color.opacity(0.5))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(colors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrent ? colors.color.opacity(0.3) : .clear, lineWidth: 1.5)
        )
    }

    // MARK: - Helpers

    private func phaseForDay(_ day: Int) -> String {
        let ranges = cycleService.phaseRanges
        if day >= ranges.menstrual.start && day <= ranges.menstrual.end { return "menstrual" }
        if day >= ranges.follicular.start && day <= ranges.follicular.end { return "follicular" }
        if day >= ranges.ovulatory.start && day <= ranges.ovulatory.end { return "ovulatory" }
        return "luteal"
    }
}
