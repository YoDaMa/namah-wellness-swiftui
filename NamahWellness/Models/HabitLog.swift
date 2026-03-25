import Foundation
import SwiftData

@Model
final class HabitLog {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var habitId: String        // References Habit.id
    var date: String           // "YYYY-MM-DD"
    var completed: Bool
    var completedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        habitId: String,
        date: String,
        completed: Bool = false,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.habitId = habitId
        self.date = date
        self.completed = completed
        self.completedAt = completedAt
    }
}
