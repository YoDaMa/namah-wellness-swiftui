import SwiftUI
import SwiftData

struct MedicationsView: View {
    let phaseSlug: String

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Query private var habits: [Habit]
    @Query private var habitLogs: [HabitLog]

    @State private var showAddMedication = false

    private var activeMedications: [Habit] {
        habits.filter { $0.category == .medication && $0.isActive }
    }

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if activeMedications.isEmpty {
                    emptyState
                } else {
                    ForEach(activeMedications) { med in
                        medicationCard(med)
                    }

                    Button { showAddMedication = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add Medication")
                        }
                        .font(.nCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(phaseColors.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(phaseColors.soft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Medications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddMedication = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMedication) {
            AddPlanItemSheet(
                defaultCategory: .medication,
                phaseSlug: phaseSlug,
                allowedCategories: [.medication]
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills")
                .font(.system(size: 36))
                .foregroundStyle(phaseColors.color.opacity(0.4))

            Text("No medications yet")
                .font(.nSubheadline)
                .foregroundStyle(.secondary)

            Text("Add your medications to track them alongside your cycle.")
                .font(.nCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showAddMedication = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Medication")
                }
                .font(.nCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(phaseColors.color)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Medication Card

    private func medicationCard(_ med: Habit) -> some View {
        let completed = isCompleted(med)

        return HStack(spacing: 12) {
            Button {
                toggleCompletion(med)
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(completed ? phaseColors.color : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(med.title)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .strikethrough(completed, color: .secondary)
                    .foregroundStyle(completed ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let sub = med.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.nCaption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(recurrenceSummary(med))
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }

                if med.reminderEnabled, let reminderTime = med.reminderTime, !reminderTime.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9))
                        Text(reminderTime)
                            .font(.nCaption2)
                    }
                    .foregroundStyle(phaseColors.color)
                }
            }

            Spacer()

            if let time = med.time, !time.isEmpty {
                Text(time)
                    .font(.nCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(role: .destructive) {
                deleteMedication(med)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func isCompleted(_ med: Habit) -> Bool {
        habitLogs.contains { $0.habitId == med.id && $0.date == today && $0.completed }
    }

    private func toggleCompletion(_ med: Habit) {
        if let existing = habitLogs.first(where: { $0.habitId == med.id && $0.date == today }) {
            existing.completed.toggle()
            syncService.queueChange(
                table: "habitLogs", action: "upsert",
                data: ["id": existing.id, "habitId": med.id, "date": today, "completed": existing.completed],
                modelContext: modelContext
            )
        } else {
            let log = HabitLog(habitId: med.id, date: today, completed: true)
            modelContext.insert(log)
            syncService.queueChange(
                table: "habitLogs", action: "upsert",
                data: ["id": log.id, "habitId": med.id, "date": today, "completed": true],
                modelContext: modelContext
            )
        }
    }

    private func deleteMedication(_ med: Habit) {
        syncService.queueChange(
            table: "habits", action: "delete",
            data: ["id": med.id],
            modelContext: modelContext
        )
        modelContext.delete(med)
    }

    private func recurrenceSummary(_ med: Habit) -> String {
        switch med.recurrence {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .once: return "Once"
        case .specificDays:
            let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let indices = med.recurrenceDayIndices
            return indices.map { dayNames[$0] }.joined(separator: ", ")
        }
    }
}
