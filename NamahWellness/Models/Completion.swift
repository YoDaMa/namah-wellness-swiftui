import Foundation
import SwiftData

@Model
final class MealCompletion {
    @Attribute(.unique) var id: String
    var mealId: String
    var date: String          // "YYYY-MM-DD"
    var completedAt: Date

    init(id: String = UUID().uuidString, mealId: String, date: String, completedAt: Date = Date()) {
        self.id = id
        self.mealId = mealId
        self.date = date
        self.completedAt = completedAt
    }
}

@Model
final class WorkoutCompletion {
    @Attribute(.unique) var id: String
    var workoutId: String
    var date: String
    var completedAt: Date

    init(id: String = UUID().uuidString, workoutId: String, date: String, completedAt: Date = Date()) {
        self.id = id
        self.workoutId = workoutId
        self.date = date
        self.completedAt = completedAt
    }
}

@Model
final class GroceryCheck {
    @Attribute(.unique) var id: String
    var groceryItemId: String
    var checked: Bool
    var updatedAt: Date

    init(id: String = UUID().uuidString, groceryItemId: String, checked: Bool = false, updatedAt: Date = Date()) {
        self.id = id
        self.groceryItemId = groceryItemId
        self.checked = checked
        self.updatedAt = updatedAt
    }
}
