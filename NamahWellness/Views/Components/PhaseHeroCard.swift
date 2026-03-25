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

    private let slugOrder = ["menstrual", "follicular", "ovulatory", "luteal"]

    private var isPeak: Bool {
        phase.phaseSlug == "ovulatory" && (phase.dayInPhase == 2 || phase.dayInPhase == 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Phase badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(.white.opacity(0.8))
                        .frame(width: 8, height: 8)
                    Text(phase.phaseName.uppercased())
                        .font(.nCaption2)
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.8))

                    if phase.isOverridden {
                        Text("· OVERRIDE")
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                // Hero title
                if let title = heroTitle {
                    Text(title)
                        .font(.display(22, relativeTo: .title2))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Hero subtitle
                if let subtitle = heroSubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.prose(13, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Footer
            HStack {
                Text("Day \(phase.dayInPhase) · Cycle day \(phase.cycleDay)")
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                if isPeak {
                    Text("Peak Fertility")
                        .font(.nCaption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    HStack(spacing: 6) {
                        ForEach(slugOrder, id: \.self) { slug in
                            let isCurrent = phase.phaseSlug == slug
                            Circle()
                                .fill(isCurrent ? .white : .white.opacity(0.3))
                                .frame(width: isCurrent ? 8 : 6, height: isCurrent ? 8 : 6)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(phaseColors.color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
