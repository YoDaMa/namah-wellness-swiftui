import SwiftUI
import SwiftData

struct TodayView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var mealCompletions: [MealCompletion]
    @Query private var workoutCompletions: [WorkoutCompletion]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var phases: [Phase]

    @State private var activeTab = 0

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var todayMealCompletionIds: Set<String> {
        Set(mealCompletions.filter { $0.date == today }.map(\.mealId))
    }

    private var todayMeals: [Meal] {
        guard let phase = cycleService.currentPhase,
              let phaseRecord = phases.first(where: { $0.slug == phase.phaseSlug })
        else { return [] }

        let phaseMeals = allMeals.filter { $0.phaseId == phaseRecord.id && $0.proteinG != nil }
        let dayNumbers = Array(Set(phaseMeals.map(\.dayNumber))).sorted()
        guard !dayNumbers.isEmpty else { return [] }
        let todayDay = dayNumbers[(phase.dayInPhase - 1) % dayNumbers.count]
        return phaseMeals.filter { $0.dayNumber == todayDay }
    }

    private var todayWorkout: (Workout, [WorkoutSession])? {
        let jsDay = Calendar.current.component(.weekday, from: Date()) // 1=Sun
        let dayOfWeek = jsDay == 1 ? 6 : jsDay - 2 // 0=Mon
        guard let w = workouts.first(where: { $0.dayOfWeek == dayOfWeek }) else { return nil }
        let sessions = workoutSessions.filter { $0.workoutId == w.id }
        return (w, sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Phase header
                    if let phase = cycleService.currentPhase {
                        PhaseHeaderView(phase: phase)
                    }

                    // Page title
                    Text("Today")
                        .font(.heading(32))
                        .foregroundStyle(.ink)

                    // Macro summary
                    if !todayMeals.isEmpty {
                        MacroSummaryBar(meals: todayMeals, completedIds: todayMealCompletionIds)
                    }

                    // Tab picker
                    Picker("Section", selection: $activeTab) {
                        Text("Meals").tag(0)
                        Text("Workout").tag(1)
                        Text("Symptoms").tag(2)
                    }
                    .pickerStyle(.segmented)

                    // Tab content
                    switch activeTab {
                    case 0:
                        mealsTab
                    case 1:
                        workoutTab
                    case 2:
                        Text("Symptom tracking coming soon")
                            .font(.body(13))
                            .foregroundStyle(.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
            .background(Color.paper)
        }
    }

    // MARK: - Meals Tab

    @ViewBuilder
    private var mealsTab: some View {
        if todayMeals.isEmpty {
            Text("No meals for today. Log your cycle to see phase-specific meals.")
                .font(.body(13))
                .foregroundStyle(.muted)
                .padding(.vertical, 40)
        } else {
            VStack(spacing: 8) {
                ForEach(todayMeals, id: \.id) { meal in
                    MealCardView(
                        meal: meal,
                        isCompleted: todayMealCompletionIds.contains(meal.id),
                        onToggle: { toggleMeal(meal) }
                    )
                }
            }
        }
    }

    // MARK: - Workout Tab

    @ViewBuilder
    private var workoutTab: some View {
        if let (workout, sessions) = todayWorkout {
            if workout.isRestDay {
                VStack(spacing: 8) {
                    Text("Rest Day")
                        .font(.heading(24))
                        .foregroundStyle(.ink)
                    Text(workout.dayFocus)
                        .font(.body(13))
                        .foregroundStyle(.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(workout.dayLabel)
                            .font(.bodyMedium(11))
                            .namahLabel()
                        Spacer()
                        Text(workout.dayFocus)
                            .font(.bodyMedium(11))
                            .foregroundStyle(.muted)
                    }

                    ForEach(sessions, id: \.id) { session in
                        HStack(alignment: .top, spacing: 12) {
                            Text(session.timeSlot)
                                .font(.bodyMedium(10))
                                .foregroundStyle(.muted)
                                .frame(width: 56, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.bodyMedium(13))
                                    .foregroundStyle(.ink)
                                Text(session.sessionDescription)
                                    .font(.body(11))
                                    .foregroundStyle(.muted)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding()
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.border, lineWidth: 1)
                )
            }
        } else {
            Text("No workout data available.")
                .font(.body(13))
                .foregroundStyle(.muted)
                .padding(.vertical, 40)
        }
    }

    // MARK: - Actions

    private func toggleMeal(_ meal: Meal) {
        if let existing = mealCompletions.first(where: { $0.mealId == meal.id && $0.date == today }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(MealCompletion(mealId: meal.id, date: today))
        }
    }
}
