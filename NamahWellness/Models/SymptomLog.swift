import Foundation
import SwiftData

@Model
final class SymptomLog {
    @Attribute(.unique) var id: String
    var userId: String
    var date: String          // "YYYY-MM-DD"
    var mood: Int?
    var energy: Int?
    var cramps: Int?
    var bloating: Int?
    var fatigue: Int?
    var acne: Int?
    var headache: Int?
    var breastTenderness: Int?
    var sleepQuality: Int?
    var anxiety: Int?
    var irritability: Int?
    var libido: Int?
    var appetite: Int?
    var flowIntensity: String?  // none|spotting|light|medium|heavy

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        date: String,
        mood: Int? = nil, energy: Int? = nil, cramps: Int? = nil,
        bloating: Int? = nil, fatigue: Int? = nil, acne: Int? = nil,
        headache: Int? = nil, breastTenderness: Int? = nil, sleepQuality: Int? = nil,
        anxiety: Int? = nil, irritability: Int? = nil, libido: Int? = nil,
        appetite: Int? = nil, flowIntensity: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.mood = mood
        self.energy = energy
        self.cramps = cramps
        self.bloating = bloating
        self.fatigue = fatigue
        self.acne = acne
        self.headache = headache
        self.breastTenderness = breastTenderness
        self.sleepQuality = sleepQuality
        self.anxiety = anxiety
        self.irritability = irritability
        self.libido = libido
        self.appetite = appetite
        self.flowIntensity = flowIntensity
    }
}

@Model
final class DailyNote {
    @Attribute(.unique) var id: String
    var userId: String
    var date: String
    var content: String
    var updatedAt: Date

    init(id: String = UUID().uuidString, userId: String = "", date: String, content: String = "", updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.date = date
        self.content = content
        self.updatedAt = updatedAt
    }
}
