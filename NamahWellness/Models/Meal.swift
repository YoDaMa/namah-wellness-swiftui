import Foundation
import SwiftData

@Model
final class Meal {
    @Attribute(.unique) var id: String
    var phaseId: String
    var dayNumber: Int
    var dayLabel: String
    var dayCalories: String?
    var mealType: String     // Breakfast, Lunch, Dinner, Snack
    var time: String         // "7:00am"
    var calories: String     // "250 cal"
    var title: String
    var mealDescription: String
    var saNote: String?
    var templateId: String?
    var proteinG: Int?
    var carbsG: Int?
    var fatG: Int?

    init(
        id: String = UUID().uuidString,
        phaseId: String, dayNumber: Int, dayLabel: String, dayCalories: String? = nil,
        mealType: String, time: String, calories: String,
        title: String, mealDescription: String, saNote: String? = nil,
        templateId: String? = nil,
        proteinG: Int? = nil, carbsG: Int? = nil, fatG: Int? = nil
    ) {
        self.id = id
        self.phaseId = phaseId
        self.dayNumber = dayNumber
        self.dayLabel = dayLabel
        self.dayCalories = dayCalories
        self.mealType = mealType
        self.time = time
        self.calories = calories
        self.title = title
        self.mealDescription = mealDescription
        self.saNote = saNote
        self.templateId = templateId
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }
}
