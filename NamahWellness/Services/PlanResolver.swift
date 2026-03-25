import Foundation

/// Stateless service that resolves what plan items to display.
/// Merges template content (Meals, WorkoutSessions, GroceryItems) with
/// user custom items (Habit) while filtering out hidden items (UserItemHidden).
enum PlanResolver {

    // MARK: - Resolved Item Types

    /// A resolved meal item — either from a template or user-created.
    struct ResolvedMeal: Identifiable {
        let id: String
        let title: String
        let mealDescription: String
        let mealType: String
        let time: String
        let calories: String?
        let proteinG: Int?
        let carbsG: Int?
        let fatG: Int?
        let saNote: String?
        let isCustom: Bool

        /// Create from a template Meal
        init(meal: Meal) {
            self.id = meal.id
            self.title = meal.title
            self.mealDescription = meal.mealDescription
            self.mealType = meal.mealType
            self.time = meal.time
            self.calories = meal.calories
            self.proteinG = meal.proteinG
            self.carbsG = meal.carbsG
            self.fatG = meal.fatG
            self.saNote = meal.saNote
            self.isCustom = false
        }

        /// Create from a Habit
        init(planItem: Habit) {
            self.id = planItem.id
            self.title = planItem.title
            self.mealDescription = planItem.subtitle ?? ""
            self.mealType = planItem.mealType ?? "Meal"
            self.time = planItem.time ?? "12:00pm"
            self.calories = planItem.calories
            self.proteinG = planItem.proteinG
            self.carbsG = planItem.carbsG
            self.fatG = planItem.fatG
            self.saNote = nil
            self.isCustom = true
        }
    }

    /// A resolved workout item — either from a template or user-created.
    struct ResolvedWorkout: Identifiable {
        let id: String
        let title: String
        let sessionDescription: String
        let timeSlot: String
        let focus: String?
        let duration: String?
        let isCustom: Bool

        /// Create from a template WorkoutSession
        init(session: WorkoutSession) {
            self.id = session.id
            self.title = session.title
            self.sessionDescription = session.sessionDescription
            self.timeSlot = session.timeSlot
            self.focus = nil
            self.duration = nil
            self.isCustom = false
        }

        /// Create from a Habit
        init(planItem: Habit) {
            self.id = planItem.id
            self.title = planItem.title
            self.sessionDescription = planItem.subtitle ?? ""
            self.timeSlot = planItem.time ?? "9:00am"
            self.focus = planItem.workoutFocus
            self.duration = planItem.duration
            self.isCustom = true
        }
    }

    /// A resolved grocery item — either from a template or user-created.
    struct ResolvedGrocery: Identifiable {
        let id: String
        let name: String
        let category: String
        let saFlag: String?
        let isCustom: Bool

        /// Create from a template GroceryItem
        init(item: GroceryItem) {
            self.id = item.id
            self.name = item.name
            self.category = item.category
            self.saFlag = item.saFlag
            self.isCustom = false
        }

        /// Create from a Habit
        init(planItem: Habit) {
            self.id = planItem.id
            self.name = planItem.title
            self.category = planItem.groceryCategory ?? "Other"
            self.saFlag = nil
            self.isCustom = true
        }
    }

    // MARK: - Resolve Meals

    /// Resolve meals for a given date: template meals + custom meals - hidden.
    /// - Parameters:
    ///   - templateMeals: Phase-filtered meals from the active template
    ///   - customItems: All Habits with category=meal
    ///   - hiddenIds: Set of item IDs the user has hidden
    ///   - dateStr: The date string ("yyyy-MM-dd") to check recurrence against
    /// - Returns: Merged, sorted array of ResolvedMeal
    static func resolveMeals(
        templateMeals: [Meal],
        customItems: [Habit],
        hiddenIds: Set<String>,
        dateStr: String
    ) -> [ResolvedMeal] {
        let visible = templateMeals
            .filter { !hiddenIds.contains($0.id) }
            .map { ResolvedMeal(meal: $0) }

        let custom = customItems
            .filter { $0.category == .meal && $0.appliesOnDate(dateStr) }
            .map { ResolvedMeal(planItem: $0) }

        return (visible + custom).sorted { sortTime($0.time) < sortTime($1.time) }
    }

    // MARK: - Resolve Workouts

    /// Resolve workout sessions for a given date: template sessions + custom workouts - hidden.
    static func resolveWorkouts(
        templateSessions: [WorkoutSession],
        customItems: [Habit],
        hiddenIds: Set<String>,
        dateStr: String
    ) -> [ResolvedWorkout] {
        let visible = templateSessions
            .filter { !hiddenIds.contains($0.id) }
            .map { ResolvedWorkout(session: $0) }

        let custom = customItems
            .filter { $0.category == .workout && $0.appliesOnDate(dateStr) }
            .map { ResolvedWorkout(planItem: $0) }

        return (visible + custom).sorted { sortTime($0.timeSlot) < sortTime($1.timeSlot) }
    }

    // MARK: - Resolve Grocery

    /// Resolve grocery items for a phase: template items + custom items - hidden.
    static func resolveGrocery(
        templateItems: [GroceryItem],
        customItems: [Habit],
        hiddenIds: Set<String>
    ) -> [ResolvedGrocery] {
        let visible = templateItems
            .filter { !hiddenIds.contains($0.id) }
            .map { ResolvedGrocery(item: $0) }

        let custom = customItems
            .filter { $0.category == .grocery && $0.isActive }
            .map { ResolvedGrocery(planItem: $0) }

        return (visible + custom).sorted { $0.category < $1.category }
    }

    // MARK: - Helpers

    /// Convert time string to minutes for sorting (e.g., "7:00am" → 420)
    private static func sortTime(_ time: String) -> Int {
        TimeParser.minutesSinceMidnight(from: time) ?? 720  // Default to noon
    }
}
