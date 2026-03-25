import Foundation

// MARK: - UnifiedPlanItem

struct UnifiedPlanItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let time: String?
    let category: HabitCategory
    let isCustom: Bool
    let sourceId: String
    let sourceType: String          // "meal", "workout", "supplement", "habit"
}

// MARK: - PlanAggregatorService

@Observable
final class PlanAggregatorService {

    // Stored model arrays (set via recalculate)
    private var meals: [Meal] = []
    private var workouts: [Workout] = []
    private var workoutSessions: [WorkoutSession] = []
    private var supplements: [UserSupplement] = []
    private var supplementDefs: [SupplementDefinition] = []
    private var customItems: [Habit] = []
    private var hiddenItems: [UserItemHidden] = []
    private var mealCompletions: [MealCompletion] = []
    private var workoutCompletions: [WorkoutCompletion] = []
    private var supplementLogs: [SupplementLog] = []
    private var habitLogs: [HabitLog] = []

    // MARK: - Recalculate

    func recalculate(
        meals: [Meal],
        workouts: [Workout],
        workoutSessions: [WorkoutSession],
        supplements: [UserSupplement],
        supplementDefs: [SupplementDefinition],
        customItems: [Habit],
        hiddenItems: [UserItemHidden],
        mealCompletions: [MealCompletion],
        workoutCompletions: [WorkoutCompletion],
        supplementLogs: [SupplementLog],
        habitLogs: [HabitLog]
    ) {
        self.meals = meals
        self.workouts = workouts
        self.workoutSessions = workoutSessions
        self.supplements = supplements
        self.supplementDefs = supplementDefs
        self.customItems = customItems
        self.hiddenItems = hiddenItems
        self.mealCompletions = mealCompletions
        self.workoutCompletions = workoutCompletions
        self.supplementLogs = supplementLogs
        self.habitLogs = habitLogs
    }

    // MARK: - Hidden IDs

    private var hiddenIds: Set<String> {
        Set(hiddenItems.map(\.itemId))
    }

    // MARK: - Meals

    func mealsForDate(date: String, phaseSlug: String, dayInPhase: Int) -> [UnifiedPlanItem] {
        let templateMeals = meals.filter { meal in
            meal.phaseId.contains(phaseSlug) || phases(for: meal, matchSlug: phaseSlug)
        }
        // Filter by day in phase
        let dayMeals = templateMeals.filter { $0.dayNumber == dayInPhase }

        let visible = dayMeals
            .filter { !hiddenIds.contains($0.id) }
            .map { meal in
                UnifiedPlanItem(
                    id: meal.id, title: meal.title,
                    subtitle: meal.mealDescription,
                    time: meal.time, category: .meal,
                    isCustom: false, sourceId: meal.id, sourceType: "meal"
                )
            }

        let custom = customItems
            .filter { $0.category == .meal && $0.appliesOnDate(date) }
            .map { item in
                UnifiedPlanItem(
                    id: item.id, title: item.title,
                    subtitle: item.subtitle,
                    time: item.time, category: .meal,
                    isCustom: true, sourceId: item.id, sourceType: "habit"
                )
            }

        return (visible + custom).sorted { sortTime($0.time) < sortTime($1.time) }
    }

    // MARK: - Workouts

    func workoutForDate(date: String) -> [UnifiedPlanItem] {
        let weekday = weekdayIndex(from: date) // 1-7 (Sun=1)
        let dayOfWeek = weekday == 1 ? 7 : weekday - 1 // Convert to 1=Mon

        let todayWorkout = workouts.first { $0.dayOfWeek == dayOfWeek }
        let sessions: [WorkoutSession]
        if let w = todayWorkout {
            sessions = workoutSessions.filter { $0.workoutId == w.id }
        } else {
            sessions = []
        }

        let visible = sessions
            .filter { !hiddenIds.contains($0.id) }
            .map { session in
                UnifiedPlanItem(
                    id: session.id, title: session.title,
                    subtitle: session.sessionDescription,
                    time: session.timeSlot, category: .workout,
                    isCustom: false, sourceId: session.id, sourceType: "workout"
                )
            }

        let custom = customItems
            .filter { $0.category == .workout && $0.appliesOnDate(date) }
            .map { item in
                UnifiedPlanItem(
                    id: item.id, title: item.title,
                    subtitle: item.subtitle,
                    time: item.time, category: .workout,
                    isCustom: true, sourceId: item.id, sourceType: "habit"
                )
            }

        return (visible + custom).sorted { sortTime($0.time) < sortTime($1.time) }
    }

    // MARK: - Supplements

    func supplementsForDate(date: String) -> [UnifiedPlanItem] {
        let defMap = Dictionary(uniqueKeysWithValues: supplementDefs.map { ($0.id, $0) })
        return supplements
            .filter { $0.isActive }
            .map { supp in
                let name = supp.supplementId.flatMap { defMap[$0]?.name } ?? supp.supplementTitle ?? "Supplement"
                return UnifiedPlanItem(
                    id: supp.id, title: name,
                    subtitle: "\(Int(supp.dosage))x \(supp.frequency)",
                    time: timeOfDayToTime(supp.timeOfDay), category: .supplement,
                    isCustom: false, sourceId: supp.id, sourceType: "supplement"
                )
            }
            .sorted { sortTime($0.time) < sortTime($1.time) }
    }

    // MARK: - Habits

    func habitsForDate(date: String) -> [UnifiedPlanItem] {
        customItems
            .filter { $0.category == .habit && $0.appliesOnDate(date) }
            .map { item in
                UnifiedPlanItem(
                    id: item.id, title: item.title,
                    subtitle: item.subtitle,
                    time: item.time, category: .habit,
                    isCustom: true, sourceId: item.id, sourceType: "habit"
                )
            }
            .sorted { sortTime($0.time) < sortTime($1.time) }
    }

    // MARK: - All Items

    func allItemsForDate(date: String, phaseSlug: String, dayInPhase: Int) -> [UnifiedPlanItem] {
        let all = mealsForDate(date: date, phaseSlug: phaseSlug, dayInPhase: dayInPhase)
            + workoutForDate(date: date)
            + supplementsForDate(date: date)
            + habitsForDate(date: date)
        return all.sorted { sortTime($0.time) < sortTime($1.time) }
    }

    // MARK: - Completion

    func isCompleted(itemId: String, sourceType: String, date: String) -> Bool {
        switch sourceType {
        case "meal":
            return mealCompletions.contains { $0.mealId == itemId && $0.date == date }
        case "workout":
            // Workout completions are day-level (by workoutId, not session)
            let sessionWorkoutId = workoutSessions.first { $0.id == itemId }?.workoutId
            if let wId = sessionWorkoutId {
                return workoutCompletions.contains { $0.workoutId == wId && $0.date == date }
            }
            return false
        case "supplement":
            return supplementLogs.contains { $0.userSupplementId == itemId && $0.date == date && $0.taken }
        case "habit":
            return habitLogs.contains { $0.habitId == itemId && $0.date == date && $0.completed }
        default:
            return false
        }
    }

    func completionRate(date: String, phaseSlug: String, dayInPhase: Int) -> Double {
        let items = allItemsForDate(date: date, phaseSlug: phaseSlug, dayInPhase: dayInPhase)
        guard !items.isEmpty else { return 0 }
        let completed = items.filter { isCompleted(itemId: $0.sourceId, sourceType: $0.sourceType, date: date) }
        return Double(completed.count) / Double(items.count)
    }

    func currentStreak() -> Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        var streak = 0
        var checkDate = Date()

        // Check backwards from today
        for _ in 0..<365 {
            let dateStr = formatter.string(from: checkDate)
            let hasActivity = mealCompletions.contains { $0.date == dateStr }
                || workoutCompletions.contains { $0.date == dateStr }
                || supplementLogs.contains { $0.date == dateStr && $0.taken }
                || habitLogs.contains { $0.date == dateStr && $0.completed }

            if hasActivity {
                streak += 1
            } else if streak > 0 {
                break
            }
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    // MARK: - Grocery (for PlanView)

    func groceriesForPhase(phaseSlug: String, templateItems: [GroceryItem]) -> [PlanResolver.ResolvedGrocery] {
        PlanResolver.resolveGrocery(
            templateItems: templateItems,
            customItems: customItems,
            hiddenIds: hiddenIds
        )
    }

    // MARK: - Helpers

    private func sortTime(_ time: String?) -> Int {
        guard let t = time else { return 720 }
        return TimeParser.minutesSinceMidnight(from: t) ?? 720
    }

    private func weekdayIndex(from dateStr: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        guard let date = formatter.date(from: dateStr) else { return 1 }
        return Calendar.current.component(.weekday, from: date)
    }

    private func phases(for meal: Meal, matchSlug: String) -> Bool {
        // Meals are linked by phaseId — check if the meal's phase matches the slug
        // This is a simplified check; the full check would look up Phase by id
        return false
    }

    private func timeOfDayToTime(_ timeOfDay: String) -> String {
        switch timeOfDay {
        case "morning": return "8:00am"
        case "with_meals": return "12:00pm"
        case "evening": return "8:00pm"
        default: return "12:00pm"
        }
    }
}
