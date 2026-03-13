import Foundation
import SwiftData

@Model
final class PlanItemLog {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var planItemId: String      // References UserPlanItem.id
    var date: String            // "YYYY-MM-DD"
    var completed: Bool
    var completedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        planItemId: String,
        date: String,
        completed: Bool = false,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.planItemId = planItemId
        self.date = date
        self.completed = completed
        self.completedAt = completedAt
    }
}
