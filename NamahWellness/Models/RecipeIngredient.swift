import Foundation
import SwiftData

@Model
final class RecipeIngredient {
    @Attribute(.unique) var id: String
    var mealId: String
    var name: String
    var quantity: String?
    var unit: String?
    var sortOrder: Int
    var category: String?  // Protein, Produce, Pantry / Grains, Other

    init(
        id: String = UUID().uuidString,
        mealId: String,
        name: String,
        quantity: String? = nil,
        unit: String? = nil,
        sortOrder: Int = 0,
        category: String? = nil
    ) {
        self.id = id
        self.mealId = mealId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.sortOrder = sortOrder
        self.category = category
    }

    func toIngredient() -> Ingredient {
        Ingredient(name: name, quantity: quantity, unit: unit)
    }
}
