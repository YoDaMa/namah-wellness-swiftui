import Foundation
import SwiftData

// MARK: - Shared Enums

enum HabitCategory: String, Codable, CaseIterable {
    case meal = "meal"
    case workout = "workout"
    case grocery = "grocery"
    case habit = "habit"
    case medication = "medication"
    case supplement = "supplement"

    var displayName: String {
        switch self {
        case .meal: return "Meal"
        case .workout: return "Workout"
        case .grocery: return "Grocery Item"
        case .habit: return "Habit"
        case .medication: return "Medication"
        case .supplement: return "Supplement"
        }
    }

    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .workout: return "figure.run"
        case .grocery: return "bag"
        case .habit: return "sparkles"
        case .medication: return "pills"
        case .supplement: return "pill"
        }
    }
}

enum HabitRecurrence: String, Codable, CaseIterable {
    case daily = "daily"
    case weekdays = "weekdays"
    case specificDays = "specific_days"
    case once = "once"

    var displayName: String {
        switch self {
        case .daily: return "Every Day"
        case .weekdays: return "Weekdays"
        case .specificDays: return "Specific Days"
        case .once: return "One Time"
        }
    }
}

// MARK: - Habit (formerly UserPlanItem)

@Model
final class Habit {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var categoryRaw: String
    var title: String
    var subtitle: String?
    var time: String?
    var phaseSlug: String?          // nil = all phases
    var recurrenceRaw: String
    var recurrenceDays: String?     // "0,2,4" for Mon/Wed/Fri (0=Monday)
    var specificDate: String?       // "2026-03-15" for one-off items
    var isActive: Bool
    var createdAt: Date

    // Meal-specific
    var mealType: String?           // Breakfast, Lunch, Dinner, Snack
    var calories: String?
    var proteinG: Int?
    var carbsG: Int?
    var fatG: Int?

    // Workout-specific
    var workoutFocus: String?       // Strength, Cardio, Yoga, Core, Other
    var duration: String?           // "30 min"

    // Grocery-specific
    var groceryCategory: String?    // Protein, Produce, Pantry, Other

    // Recipe (custom meals only)
    var ingredientsJSON: String?    // JSON array of {name, quantity, unit}
    var instructions: String?       // JSON array of step strings

    // Reminders
    var reminderEnabled: Bool = false
    var reminderTime: String?

    // Copy-on-write tracking
    var replacesItemId: String?

    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .meal }
        set { categoryRaw = newValue.rawValue }
    }

    var recurrence: HabitRecurrence {
        get { HabitRecurrence(rawValue: recurrenceRaw) ?? .specificDays }
        set { recurrenceRaw = newValue.rawValue }
    }

    /// Parse recurrenceDays string into array of weekday indices (0=Monday)
    var recurrenceDayIndices: [Int] {
        guard let days = recurrenceDays else { return [] }
        return days.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Check if this item applies on a given date
    func appliesOnDate(_ dateStr: String) -> Bool {
        guard isActive else { return false }

        // Phase filter
        if let slug = phaseSlug, !slug.isEmpty {
            // Caller must check phase externally — this method can't access CycleService
            // Phase filtering is handled by PlanResolver
        }

        switch recurrence {
        case .daily:
            return true
        case .weekdays:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            guard let date = formatter.date(from: dateStr) else { return false }
            let weekday = Calendar.current.component(.weekday, from: date)
            // weekday: 1=Sunday, 7=Saturday
            return weekday >= 2 && weekday <= 6
        case .specificDays:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            guard let date = formatter.date(from: dateStr) else { return false }
            let weekday = Calendar.current.component(.weekday, from: date)
            let dayIndex = weekday == 1 ? 6 : weekday - 2  // Convert to 0=Monday
            return recurrenceDayIndices.contains(dayIndex)
        case .once:
            return specificDate == dateStr
        }
    }

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        category: HabitCategory,
        title: String,
        subtitle: String? = nil,
        time: String? = nil,
        phaseSlug: String? = nil,
        recurrence: HabitRecurrence = .specificDays,
        recurrenceDays: String? = nil,
        specificDate: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        mealType: String? = nil,
        calories: String? = nil,
        proteinG: Int? = nil,
        carbsG: Int? = nil,
        fatG: Int? = nil,
        workoutFocus: String? = nil,
        duration: String? = nil,
        groceryCategory: String? = nil,
        ingredientsJSON: String? = nil,
        instructions: String? = nil,
        reminderEnabled: Bool = false,
        reminderTime: String? = nil,
        replacesItemId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.categoryRaw = category.rawValue
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.phaseSlug = phaseSlug
        self.recurrenceRaw = recurrence.rawValue
        self.recurrenceDays = recurrenceDays
        self.specificDate = specificDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.mealType = mealType
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.workoutFocus = workoutFocus
        self.duration = duration
        self.groceryCategory = groceryCategory
        self.ingredientsJSON = ingredientsJSON
        self.instructions = instructions
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.replacesItemId = replacesItemId
    }
}
