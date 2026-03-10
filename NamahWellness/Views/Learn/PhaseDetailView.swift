import SwiftUI
import SwiftData

struct PhaseDetailView: View {
    let phase: Phase
    let cycleService: CycleService

    @Query private var phaseNutrients: [PhaseNutrient]
    @Query private var reminders: [PhaseReminder]

    private var colors: PhaseColors { PhaseColors.forSlug(phase.slug) }

    private var nutrients: [PhaseNutrient] {
        phaseNutrients.filter { $0.phaseId == phase.id }
    }

    private var phaseReminders: [PhaseReminder] {
        reminders.filter { $0.phaseId == phase.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Phase-colored header
                phaseHeader

                // Content sections
                VStack(alignment: .leading, spacing: 24) {
                    // Description
                    if !phase.phaseDescription.isEmpty {
                        Text(phase.phaseDescription)
                            .font(.prose(17))
                            .foregroundStyle(.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }

                    // Key nutrients
                    if !nutrients.isEmpty {
                        nutrientsSection
                    }

                    // Insights
                    if !phaseReminders.isEmpty {
                        insightsSection
                    }

                    // SA personalization
                    if !phase.saNote.isEmpty {
                        SACalloutView(text: phase.saNote)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Phase Header

    private var phaseHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
                Text(phase.name)
                    .font(.nCaption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Days \(phase.dayStart)\u{2013}\(phase.dayEnd)")
                    .font(.nCaption)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                if let info = cycleService.currentPhase, info.phaseSlug == phase.slug {
                    Text("Day \(info.dayInPhase)")
                        .font(.nCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Text(phase.heroTitle)
                .font(.display(26))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.color)
    }

    // MARK: - Nutrients Section

    private var nutrientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KEY NUTRIENTS")
                .namahLabel()

            FlowLayout(spacing: 6) {
                ForEach(nutrients, id: \.id) { nut in
                    Text(nut.label)
                        .font(.nCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(colors.soft)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("WHAT'S HAPPENING")
                    .namahLabel()
                Spacer()
                Text("\(phaseReminders.count) insights")
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(phaseReminders.enumerated()), id: \.element.id) { index, reminder in
                    InsightRowView(
                        text: reminder.text,
                        evidenceLevel: reminder.evidenceLevel
                    )

                    if index < phaseReminders.count - 1 {
                        Divider()
                            .padding(.horizontal, 14)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
