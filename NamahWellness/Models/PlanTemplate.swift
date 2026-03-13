import Foundation
import SwiftData

@Model
final class PlanTemplate {
    @Attribute(.unique) var id: String
    var name: String
    var templateDescription: String
    var categoryRaw: String  // "meal" | "workout" | "grocery"
    var isDefault: Bool
    var createdAt: Date

    var category: PlanItemCategory {
        get { PlanItemCategory(rawValue: categoryRaw) ?? .meal }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        templateDescription: String = "",
        category: PlanItemCategory = .meal,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.templateDescription = templateDescription
        self.categoryRaw = category.rawValue
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}
