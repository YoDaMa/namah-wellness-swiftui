import Foundation

/// Unifies template Meals and custom UserPlanItems for MealDetailView display.
protocol MealDisplayable {
    var title: String { get }
    var displayMealType: String? { get }
    var displayTime: String? { get }
    var displayDescription: String? { get }
    var displayCalories: String? { get }
    var proteinG: Int? { get }
    var carbsG: Int? { get }
    var fatG: Int? { get }
    var steps: [String] { get }
    var isCustomMeal: Bool { get }
    var displaySaNote: String? { get }
}

// MARK: - Meal conformance

extension Meal: MealDisplayable {
    var displayMealType: String? { mealType }
    var displayTime: String? { time }
    var displayDescription: String? { mealDescription }
    var displayCalories: String? { calories }
    var displaySaNote: String? { saNote }
    var isCustomMeal: Bool { false }

    var steps: [String] {
        guard let json = instructions, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

// MARK: - UserPlanItem conformance

extension UserPlanItem: MealDisplayable {
    var displayMealType: String? { mealType }
    var displayTime: String? { time }
    var displayDescription: String? { subtitle }
    var displayCalories: String? { calories }
    var displaySaNote: String? { nil }
    var isCustomMeal: Bool { true }

    var steps: [String] {
        guard let json = instructions, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    var decodedIngredients: [Ingredient] {
        guard let json = ingredientsJSON, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Ingredient].self, from: data)) ?? []
    }
}
