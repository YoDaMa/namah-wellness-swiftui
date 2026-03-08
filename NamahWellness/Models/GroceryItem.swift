import Foundation
import SwiftData

@Model
final class GroceryItem {
    @Attribute(.unique) var id: String
    var phaseId: String
    var category: String     // Protein, Produce, Pantry / Grains
    var name: String
    var saFlag: String?

    init(id: String = UUID().uuidString, phaseId: String, category: String, name: String, saFlag: String? = nil) {
        self.id = id
        self.phaseId = phaseId
        self.category = category
        self.name = name
        self.saFlag = saFlag
    }
}

@Model
final class PhaseReminder {
    @Attribute(.unique) var id: String
    var phaseId: String
    var icon: String
    var text: String
    var evidenceLevel: String?  // strong, moderate, emerging, expert_opinion

    init(id: String = UUID().uuidString, phaseId: String, icon: String, text: String, evidenceLevel: String? = nil) {
        self.id = id
        self.phaseId = phaseId
        self.icon = icon
        self.text = text
        self.evidenceLevel = evidenceLevel
    }
}

@Model
final class PhaseNutrient {
    @Attribute(.unique) var id: String
    var phaseId: String
    var icon: String
    var label: String

    init(id: String = UUID().uuidString, phaseId: String, icon: String, label: String) {
        self.id = id
        self.phaseId = phaseId
        self.icon = icon
        self.label = label
    }
}
