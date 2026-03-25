import Foundation
import SwiftData

@Model
final class UserItemHidden {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var itemId: String          // References Meal.id, Workout.id, WorkoutSession.id, or GroceryItem.id
    var itemTypeRaw: String     // "meal" | "workout" | "grocery"
    var hiddenAt: Date

    var itemType: HabitCategory {
        get { HabitCategory(rawValue: itemTypeRaw) ?? .meal }
        set { itemTypeRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        itemId: String,
        itemType: HabitCategory,
        hiddenAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.itemId = itemId
        self.itemTypeRaw = itemType.rawValue
        self.hiddenAt = hiddenAt
    }
}
