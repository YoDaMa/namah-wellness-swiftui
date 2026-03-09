import Foundation
import SwiftData

@Model
final class SupplementDefinition {
    @Attribute(.unique) var id: String
    var name: String
    var brand: String?
    var category: String     // Vitamins, Minerals, Omega / Fatty Acids, etc.
    var servingSize: Int
    var servingUnit: String  // capsule, tablet, softgel, scoop, ml
    var isCustom: Bool
    var createdByUserId: String?
    var notes: String?

    init(
        id: String = UUID().uuidString,
        name: String, brand: String? = nil, category: String,
        servingSize: Int = 1, servingUnit: String = "capsule",
        isCustom: Bool = false, createdByUserId: String? = nil, notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.isCustom = isCustom
        self.createdByUserId = createdByUserId
        self.notes = notes
    }
}

@Model
final class SupplementNutrient {
    @Attribute(.unique) var id: String
    var supplementId: String
    var nutrientKey: String  // vitaminD3, magnesium, omega3EPA, etc.
    var amount: Double
    var unit: String         // mg, mcg, IU, g

    init(id: String = UUID().uuidString, supplementId: String, nutrientKey: String, amount: Double, unit: String) {
        self.id = id
        self.supplementId = supplementId
        self.nutrientKey = nutrientKey
        self.amount = amount
        self.unit = unit
    }
}

@Model
final class UserSupplement {
    @Attribute(.unique) var id: String
    var userId: String
    var supplementId: String
    var dosage: Double
    var frequency: String    // daily, weekly, as_needed
    var timeOfDay: String    // morning, with_meals, evening, as_needed
    var isActive: Bool
    var startedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        supplementId: String, dosage: Double = 1.0,
        frequency: String = "daily", timeOfDay: String = "morning",
        isActive: Bool = true, startedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.supplementId = supplementId
        self.dosage = dosage
        self.frequency = frequency
        self.timeOfDay = timeOfDay
        self.isActive = isActive
        self.startedAt = startedAt
    }
}

@Model
final class SupplementLog {
    @Attribute(.unique) var id: String
    var userId: String
    var userSupplementId: String
    var date: String
    var taken: Bool
    var loggedAt: Date

    init(id: String = UUID().uuidString, userId: String = "", userSupplementId: String, date: String, taken: Bool = false, loggedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.userSupplementId = userSupplementId
        self.date = date
        self.taken = taken
        self.loggedAt = loggedAt
    }
}
