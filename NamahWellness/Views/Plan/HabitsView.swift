import SwiftUI
import SwiftData

struct HabitsView: View {
    let phaseSlug: String

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Query private var habits: [Habit]
    @Query private var habitLogs: [HabitLog]

    @State private var showAddHabit = false

    private var activeHabits: [Habit] {
        habits.filter { $0.category == .habit && $0.isActive }
    }

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    // Group habits by time of day
    private var morningHabits: [Habit] {
        activeHabits.filter { timeBlock(for: $0.time) == "Morning" }
    }
    private var afternoonHabits: [Habit] {
        activeHabits.filter { timeBlock(for: $0.time) == "Afternoon" }
    }
    private var eveningHabits: [Habit] {
        activeHabits.filter { timeBlock(for: $0.time) == "Evening" }
    }
    private var anytimeHabits: [Habit] {
        activeHabits.filter { $0.time == nil || $0.time?.isEmpty == true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if activeHabits.isEmpty {
                emptyState
            } else {
                if !morningHabits.isEmpty {
                    habitSection("Morning", habits: morningHabits)
                }
                if !afternoonHabits.isEmpty {
                    habitSection("Afternoon", habits: afternoonHabits)
                }
                if !eveningHabits.isEmpty {
                    habitSection("Evening", habits: eveningHabits)
                }
                if !anytimeHabits.isEmpty {
                    habitSection("Anytime", habits: anytimeHabits)
                }
            }
        }
        .sheet(isPresented: $showAddHabit) {
            AddPlanItemSheet(
                defaultCategory: .habit,
                phaseSlug: phaseSlug,
                allowedCategories: [.habit]
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(phaseColors.color.opacity(0.4))

            Text("No habits yet")
                .font(.nSubheadline)
                .foregroundStyle(.secondary)

            Text("Add daily habits like meditation, journaling, or mindfulness.")
                .font(.nCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showAddHabit = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Habit")
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

    // MARK: - Habit Section

    private func habitSection(_ title: String, habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .namahLabel()

            ForEach(habits) { habit in
                habitCard(habit)
            }
        }
    }

    // MARK: - Habit Card

    private func habitCard(_ habit: Habit) -> some View {
        let completed = isCompleted(habit)

        return HStack(spacing: 12) {
            // Completion checkbox
            Button {
                toggleCompletion(habit)
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(completed ? phaseColors.color : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .strikethrough(completed, color: .secondary)
                    .foregroundStyle(completed ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let duration = habit.duration, !duration.isEmpty {
                        Text(duration)
                            .font(.nCaption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(recurrenceSummary(habit))
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let time = habit.time, !time.isEmpty {
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
                deleteHabit(habit)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func isCompleted(_ habit: Habit) -> Bool {
        habitLogs.contains { $0.habitId == habit.id && $0.date == today && $0.completed }
    }

    private func toggleCompletion(_ habit: Habit) {
        if let existing = habitLogs.first(where: { $0.habitId == habit.id && $0.date == today }) {
            existing.completed.toggle()
            syncService.queueChange(
                table: "habitLogs", action: "upsert",
                data: ["id": existing.id, "habitId": habit.id, "date": today, "completed": existing.completed],
                modelContext: modelContext
            )
        } else {
            let log = HabitLog(habitId: habit.id, date: today, completed: true)
            modelContext.insert(log)
            syncService.queueChange(
                table: "habitLogs", action: "upsert",
                data: ["id": log.id, "habitId": habit.id, "date": today, "completed": true],
                modelContext: modelContext
            )
        }
    }

    private func deleteHabit(_ habit: Habit) {
        syncService.queueChange(
            table: "habits", action: "delete",
            data: ["id": habit.id],
            modelContext: modelContext
        )
        modelContext.delete(habit)
    }

    private func recurrenceSummary(_ habit: Habit) -> String {
        switch habit.recurrence {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .once: return "Once"
        case .specificDays:
            let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let indices = habit.recurrenceDayIndices
            return indices.map { dayNames[$0] }.joined(separator: ", ")
        }
    }

    private func timeBlock(for time: String?) -> String {
        guard let t = time, let mins = TimeParser.minutesSinceMidnight(from: t) else { return "Anytime" }
        if mins < 720 { return "Morning" }
        if mins < 1020 { return "Afternoon" }
        return "Evening"
    }
}
