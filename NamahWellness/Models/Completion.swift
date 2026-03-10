import Foundation
import SwiftData

@Model
final class MealCompletion {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var mealId: String
    var date: String          // "YYYY-MM-DD"
    var completedAt: Date

    init(id: String = UUID().uuidString, userId: String = "", mealId: String, date: String, completedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.mealId = mealId
        self.date = date
        self.completedAt = completedAt
    }
}

@Model
final class WorkoutCompletion {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var workoutId: String
    var date: String
    var completedAt: Date

    init(id: String = UUID().uuidString, userId: String = "", workoutId: String, date: String, completedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.workoutId = workoutId
        self.date = date
        self.completedAt = completedAt
    }
}

@Model
final class GroceryCheck {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var groceryItemId: String
    var checked: Bool
    var updatedAt: Date

    init(id: String = UUID().uuidString, userId: String = "", groceryItemId: String, checked: Bool = false, updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.groceryItemId = groceryItemId
        self.checked = checked
        self.updatedAt = updatedAt
    }
}
