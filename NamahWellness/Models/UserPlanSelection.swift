import Foundation
import SwiftData

@Model
final class UserPlanSelection {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var templateId: String
    var categoryRaw: String
    var isActive: Bool
    var selectedAt: Date

    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .meal }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        templateId: String,
        category: HabitCategory = .meal,
        isActive: Bool = true,
        selectedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.templateId = templateId
        self.categoryRaw = category.rawValue
        self.isActive = isActive
        self.selectedAt = selectedAt
    }
}
