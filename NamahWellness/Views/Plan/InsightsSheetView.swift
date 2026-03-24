import SwiftUI
import SwiftData

struct InsightsSheetView: View {
    let phaseSlug: String

    @Environment(\.dismiss) private var dismiss
    @Query private var phases: [Phase]
    @Query private var reminders: [PhaseReminder]

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }
    private var colors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    private var phaseReminders: [PhaseReminder] {
        guard let id = phase?.id else { return [] }
        return reminders.filter { $0.phaseId == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(phaseReminders.enumerated()), id: \.element.id) { index, reminder in
                        InsightRowView(
                            text: reminder.text,
                            evidenceLevel: reminder.evidenceLevel,
                            icon: reminder.icon,
                            horizontalPadding: 16
                        )

                        if index < phaseReminders.count - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
                    .background(colors.soft)
            }
            .navigationTitle("Phase Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
