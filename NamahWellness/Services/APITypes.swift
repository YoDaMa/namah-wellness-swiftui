import Foundation

// MARK: - Top-Level Responses

struct ContentResponse: Decodable {
    let phases: [PhaseDTO]
    let meals: [MealDTO]
    let recipeIngredients: [RecipeIngredientDTO]
    let groceryItems: [GroceryItemDTO]
    let workouts: [WorkoutDTO]
    let workoutSessions: [WorkoutSessionDTO]
    let coreExercises: [CoreExerciseDTO]
    let phaseReminders: [PhaseReminderDTO]
    let phaseNutrients: [PhaseNutrientDTO]
    let supplementDefinitions: [SupplementDefinitionDTO]
    let supplementNutrients: [SupplementNutrientDTO]
    let planTemplates: [PlanTemplateDTO]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phases = try c.decodeIfPresent([PhaseDTO].self, forKey: .phases) ?? []
        meals = try c.decodeIfPresent([MealDTO].self, forKey: .meals) ?? []
        recipeIngredients = try c.decodeIfPresent([RecipeIngredientDTO].self, forKey: .recipeIngredients) ?? []
        groceryItems = try c.decodeIfPresent([GroceryItemDTO].self, forKey: .groceryItems) ?? []
        workouts = try c.decodeIfPresent([WorkoutDTO].self, forKey: .workouts) ?? []
        workoutSessions = try c.decodeIfPresent([WorkoutSessionDTO].self, forKey: .workoutSessions) ?? []
        coreExercises = try c.decodeIfPresent([CoreExerciseDTO].self, forKey: .coreExercises) ?? []
        phaseReminders = try c.decodeIfPresent([PhaseReminderDTO].self, forKey: .phaseReminders) ?? []
        phaseNutrients = try c.decodeIfPresent([PhaseNutrientDTO].self, forKey: .phaseNutrients) ?? []
        supplementDefinitions = try c.decodeIfPresent([SupplementDefinitionDTO].self, forKey: .supplementDefinitions) ?? []
        supplementNutrients = try c.decodeIfPresent([SupplementNutrientDTO].self, forKey: .supplementNutrients) ?? []
        planTemplates = try c.decodeIfPresent([PlanTemplateDTO].self, forKey: .planTemplates) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case phases, meals, recipeIngredients, groceryItems, workouts, workoutSessions
        case coreExercises, phaseReminders, phaseNutrients
        case supplementDefinitions, supplementNutrients, planTemplates
    }
}

struct UserDataResponse: Decodable {
    let cycleLogs: [CycleLogDTO]
    let mealCompletions: [MealCompletionDTO]
    let workoutCompletions: [WorkoutCompletionDTO]
    let symptomLogs: [SymptomLogDTO]
    let dailyNotes: [DailyNoteDTO]
    let groceryChecks: [GroceryCheckDTO]
    let userSupplements: [UserSupplementDTO]
    let supplementLogs: [SupplementLogDTO]
    let userPlanSelections: [UserPlanSelectionDTO]
    let userPlanItems: [UserPlanItemDTO]
    let userItemsHidden: [UserItemHiddenDTO]
    let planItemLogs: [PlanItemLogDTO]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cycleLogs = try c.decodeIfPresent([CycleLogDTO].self, forKey: .cycleLogs) ?? []
        mealCompletions = try c.decodeIfPresent([MealCompletionDTO].self, forKey: .mealCompletions) ?? []
        workoutCompletions = try c.decodeIfPresent([WorkoutCompletionDTO].self, forKey: .workoutCompletions) ?? []
        symptomLogs = try c.decodeIfPresent([SymptomLogDTO].self, forKey: .symptomLogs) ?? []
        dailyNotes = try c.decodeIfPresent([DailyNoteDTO].self, forKey: .dailyNotes) ?? []
        groceryChecks = try c.decodeIfPresent([GroceryCheckDTO].self, forKey: .groceryChecks) ?? []
        userSupplements = try c.decodeIfPresent([UserSupplementDTO].self, forKey: .userSupplements) ?? []
        supplementLogs = try c.decodeIfPresent([SupplementLogDTO].self, forKey: .supplementLogs) ?? []
        userPlanSelections = try c.decodeIfPresent([UserPlanSelectionDTO].self, forKey: .userPlanSelections) ?? []
        userPlanItems = try c.decodeIfPresent([UserPlanItemDTO].self, forKey: .userPlanItems) ?? []
        userItemsHidden = try c.decodeIfPresent([UserItemHiddenDTO].self, forKey: .userItemsHidden) ?? []
        planItemLogs = try c.decodeIfPresent([PlanItemLogDTO].self, forKey: .planItemLogs) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case cycleLogs, mealCompletions, workoutCompletions, symptomLogs
        case dailyNotes, groceryChecks, userSupplements, supplementLogs
        case userPlanSelections, userPlanItems, userItemsHidden, planItemLogs
    }
}

struct CycleBundleResponse: Decodable {
    let currentPhase: PhaseInfoDTO?
    let cycleStats: CycleStatsDTO
    let phaseRanges: PhaseRangesDTO
}

// MARK: - Content DTOs

struct PhaseDTO: Decodable {
    let id: String
    let name: String
    let slug: String
    let dayStart: Int
    let dayEnd: Int
    let calorieTarget: String
    let proteinTarget: String
    let fatTarget: String
    let carbTarget: String
    let heroEyebrow: String
    let heroTitle: String
    let heroSubtitle: String
    let description: String
    let exerciseIntensity: String
    let saNote: String
    let color: String
    let colorSoft: String
    let colorMid: String

    func toModel() -> Phase {
        Phase(
            id: id, name: name, slug: slug, dayStart: dayStart, dayEnd: dayEnd,
            calorieTarget: calorieTarget, proteinTarget: proteinTarget,
            fatTarget: fatTarget, carbTarget: carbTarget,
            heroEyebrow: heroEyebrow, heroTitle: heroTitle, heroSubtitle: heroSubtitle,
            phaseDescription: description, exerciseIntensity: exerciseIntensity,
            saNote: saNote, color: color, colorSoft: colorSoft, colorMid: colorMid
        )
    }
}

struct MealDTO: Decodable {
    let id: String
    let phaseId: String
    let dayNumber: Int
    let dayLabel: String
    let dayCalories: String?
    let mealType: String
    let time: String
    let calories: String
    let title: String
    let description: String
    let saNote: String?
    let templateId: String?
    let proteinG: Int?
    let carbsG: Int?
    let fatG: Int?
    let instructions: String?

    func toModel() -> Meal {
        Meal(
            id: id, phaseId: phaseId, dayNumber: dayNumber, dayLabel: dayLabel,
            dayCalories: dayCalories, mealType: mealType, time: time, calories: calories,
            title: title, mealDescription: description, saNote: saNote,
            templateId: templateId,
            proteinG: proteinG, carbsG: carbsG, fatG: fatG,
            instructions: instructions
        )
    }
}

struct RecipeIngredientDTO: Decodable {
    let id: String
    let mealId: String
    let name: String
    let quantity: String?
    let unit: String?
    let sortOrder: Int

    func toModel() -> RecipeIngredient {
        RecipeIngredient(id: id, mealId: mealId, name: name, quantity: quantity, unit: unit, sortOrder: sortOrder)
    }
}

struct GroceryItemDTO: Decodable {
    let id: String
    let phaseId: String
    let category: String
    let name: String
    let saFlag: String?
    let templateId: String?

    func toModel() -> GroceryItem {
        GroceryItem(id: id, phaseId: phaseId, category: category, name: name, saFlag: saFlag, templateId: templateId)
    }
}

struct WorkoutDTO: Decodable {
    let id: String
    let dayOfWeek: Int
    let dayLabel: String
    let dayFocus: String
    let templateId: String?
    let isRestDay: Bool

    func toModel() -> Workout {
        Workout(id: id, dayOfWeek: dayOfWeek, dayLabel: dayLabel, dayFocus: dayFocus, templateId: templateId, isRestDay: isRestDay)
    }
}

struct WorkoutSessionDTO: Decodable {
    let id: String
    let workoutId: String
    let timeSlot: String
    let title: String
    let description: String

    func toModel() -> WorkoutSession {
        WorkoutSession(id: id, workoutId: workoutId, timeSlot: timeSlot, title: title, sessionDescription: description)
    }
}

struct CoreExerciseDTO: Decodable {
    let id: String
    let name: String
    let description: String
    let sets: String

    func toModel() -> CoreExercise {
        CoreExercise(id: id, name: name, exerciseDescription: description, sets: sets)
    }
}

struct PhaseReminderDTO: Decodable {
    let id: String
    let phaseId: String
    let icon: String
    let text: String
    let evidenceLevel: String?

    func toModel() -> PhaseReminder {
        PhaseReminder(id: id, phaseId: phaseId, icon: icon, text: text, evidenceLevel: evidenceLevel)
    }
}

struct PhaseNutrientDTO: Decodable {
    let id: String
    let phaseId: String
    let icon: String
    let label: String

    func toModel() -> PhaseNutrient {
        PhaseNutrient(id: id, phaseId: phaseId, icon: icon, label: label)
    }
}

struct SupplementDefinitionDTO: Decodable {
    let id: String
    let name: String
    let brand: String?
    let category: String
    let servingSize: Int
    let servingUnit: String
    let isCustom: Bool
    let notes: String?

    func toModel() -> SupplementDefinition {
        SupplementDefinition(
            id: id, name: name, brand: brand, category: category,
            servingSize: servingSize, servingUnit: servingUnit,
            isCustom: isCustom, notes: notes
        )
    }
}

struct SupplementNutrientDTO: Decodable {
    let id: String
    let supplementId: String
    let nutrientKey: String
    let amount: Double
    let unit: String

    func toModel() -> SupplementNutrient {
        SupplementNutrient(id: id, supplementId: supplementId, nutrientKey: nutrientKey, amount: amount, unit: unit)
    }
}

// MARK: - User Data DTOs

struct CycleLogDTO: Decodable {
    let id: String
    let userId: String
    let periodStartDate: String
    let periodEndDate: String?
    let phaseOverride: String?

    func toModel() -> CycleLog {
        CycleLog(
            id: id, userId: userId,
            periodStartDate: periodStartDate, periodEndDate: periodEndDate,
            phaseOverride: phaseOverride
        )
    }
}

struct MealCompletionDTO: Decodable {
    let id: String
    let userId: String
    let mealId: String
    let date: String

    func toModel() -> MealCompletion {
        MealCompletion(id: id, userId: userId, mealId: mealId, date: date)
    }
}

struct WorkoutCompletionDTO: Decodable {
    let id: String
    let userId: String
    let workoutId: String
    let date: String

    func toModel() -> WorkoutCompletion {
        WorkoutCompletion(id: id, userId: userId, workoutId: workoutId, date: date)
    }
}

struct SymptomLogDTO: Decodable {
    let id: String
    let userId: String
    let date: String
    let mood: Int?
    let energy: Int?
    let cramps: Int?
    let bloating: Int?
    let fatigue: Int?
    let acne: Int?
    let headache: Int?
    let breastTenderness: Int?
    let sleepQuality: Int?
    let anxiety: Int?
    let irritability: Int?
    let libido: Int?
    let appetite: Int?
    let flowIntensity: String?

    func toModel() -> SymptomLog {
        SymptomLog(
            id: id, userId: userId, date: date,
            mood: mood, energy: energy, cramps: cramps,
            bloating: bloating, fatigue: fatigue, acne: acne,
            headache: headache, breastTenderness: breastTenderness, sleepQuality: sleepQuality,
            anxiety: anxiety, irritability: irritability, libido: libido,
            appetite: appetite, flowIntensity: flowIntensity
        )
    }
}

struct DailyNoteDTO: Decodable {
    let id: String
    let userId: String
    let date: String
    let content: String

    func toModel() -> DailyNote {
        DailyNote(id: id, userId: userId, date: date, content: content)
    }
}

struct GroceryCheckDTO: Decodable {
    let id: String
    let userId: String
    let groceryItemId: String
    let checked: Bool

    func toModel() -> GroceryCheck {
        GroceryCheck(id: id, userId: userId, groceryItemId: groceryItemId, checked: checked)
    }
}

struct UserSupplementDTO: Decodable {
    let id: String
    let userId: String
    let supplementId: String
    let dosage: Double
    let frequency: String
    let timeOfDay: String
    let isActive: Bool

    func toModel() -> UserSupplement {
        UserSupplement(
            id: id, userId: userId, supplementId: supplementId,
            dosage: dosage, frequency: frequency, timeOfDay: timeOfDay,
            isActive: isActive
        )
    }
}

struct SupplementLogDTO: Decodable {
    let id: String
    let userId: String
    let userSupplementId: String
    let date: String
    let taken: Bool

    func toModel() -> SupplementLog {
        SupplementLog(id: id, userId: userId, userSupplementId: userSupplementId, date: date, taken: taken)
    }
}

// MARK: - Plan Template DTOs

struct PlanTemplateDTO: Decodable {
    let id: String
    let name: String
    let description: String
    let category: String
    let isDefault: Bool

    func toModel() -> PlanTemplate {
        PlanTemplate(
            id: id, name: name, templateDescription: description,
            category: PlanItemCategory(rawValue: category) ?? .meal,
            isDefault: isDefault
        )
    }
}

struct UserPlanSelectionDTO: Decodable {
    let id: String
    let userId: String
    let templateId: String
    let category: String
    let isActive: Bool

    func toModel() -> UserPlanSelection {
        UserPlanSelection(
            id: id, userId: userId, templateId: templateId,
            category: PlanItemCategory(rawValue: category) ?? .meal,
            isActive: isActive
        )
    }
}

struct UserPlanItemDTO: Decodable {
    let id: String
    let userId: String
    let category: String
    let title: String
    let subtitle: String?
    let time: String?
    let phaseSlug: String?
    let recurrence: String
    let recurrenceDays: String?
    let specificDate: String?
    let isActive: Bool
    let mealType: String?
    let calories: String?
    let proteinG: Int?
    let carbsG: Int?
    let fatG: Int?
    let workoutFocus: String?
    let duration: String?
    let groceryCategory: String?
    let ingredientsJSON: String?
    let instructions: String?

    func toModel() -> UserPlanItem {
        UserPlanItem(
            id: id, userId: userId,
            category: PlanItemCategory(rawValue: category) ?? .meal,
            title: title, subtitle: subtitle, time: time,
            phaseSlug: phaseSlug,
            recurrence: PlanItemRecurrence(rawValue: recurrence) ?? .specificDays,
            recurrenceDays: recurrenceDays, specificDate: specificDate,
            isActive: isActive,
            mealType: mealType, calories: calories,
            proteinG: proteinG, carbsG: carbsG, fatG: fatG,
            workoutFocus: workoutFocus, duration: duration,
            groceryCategory: groceryCategory,
            ingredientsJSON: ingredientsJSON,
            instructions: instructions
        )
    }
}

struct UserItemHiddenDTO: Decodable {
    let id: String
    let userId: String
    let itemId: String
    let itemType: String

    func toModel() -> UserItemHidden {
        UserItemHidden(
            id: id, userId: userId, itemId: itemId,
            itemType: PlanItemCategory(rawValue: itemType) ?? .meal
        )
    }
}

struct PlanItemLogDTO: Decodable {
    let id: String
    let userId: String
    let planItemId: String
    let date: String
    let completed: Bool

    func toModel() -> PlanItemLog {
        PlanItemLog(id: id, userId: userId, planItemId: planItemId, date: date, completed: completed)
    }
}

// MARK: - Cycle Bundle DTOs

struct PhaseInfoDTO: Decodable {
    let phaseName: String
    let phaseSlug: String
    let cycleDay: Int
    let dayInPhase: Int
    let periodStartDate: String
    let isOverridden: Bool
    let color: String
    let colorSoft: String

    func toPhaseInfo() -> PhaseInfo {
        PhaseInfo(
            phaseName: phaseName, phaseSlug: phaseSlug,
            cycleDay: cycleDay, dayInPhase: dayInPhase,
            periodStartDate: periodStartDate, isOverridden: isOverridden,
            color: color, colorSoft: colorSoft
        )
    }
}

struct CycleStatsDTO: Decodable {
    let avgCycleLength: Int
    let avgPeriodLength: Int
    let cycleCount: Int

    func toCycleStats() -> CycleStats {
        CycleStats(
            observedAvgCycleLength: avgCycleLength,
            observedAvgPeriodLength: avgPeriodLength,
            effectiveCycleLength: avgCycleLength,
            effectivePeriodLength: avgPeriodLength,
            userDefaultCycleLength: nil,
            userDefaultPeriodLength: nil,
            cycleCount: cycleCount,
            daysOverdue: 0,
            isOverdue: false
        )
    }
}

struct PhaseRangeDTO: Decodable {
    let start: Int
    let end: Int

    func toPhaseRange() -> PhaseRange {
        PhaseRange(start: start, end: end)
    }
}

struct PhaseRangesDTO: Decodable {
    let menstrual: PhaseRangeDTO
    let follicular: PhaseRangeDTO
    let ovulatory: PhaseRangeDTO
    let luteal: PhaseRangeDTO

    func toPhaseRanges() -> PhaseRanges {
        PhaseRanges(
            menstrual: menstrual.toPhaseRange(),
            follicular: follicular.toPhaseRange(),
            ovulatory: ovulatory.toPhaseRange(),
            luteal: luteal.toPhaseRange()
        )
    }
}
