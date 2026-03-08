import Foundation
import SwiftData

@Model
final class Phase {
    @Attribute(.unique) var id: String
    var name: String
    var slug: String
    var dayStart: Int
    var dayEnd: Int
    var calorieTarget: String
    var proteinTarget: String
    var fatTarget: String
    var carbTarget: String
    var heroEyebrow: String
    var heroTitle: String
    var heroSubtitle: String
    var phaseDescription: String
    var exerciseIntensity: String
    var saNote: String
    var color: String      // hex
    var colorSoft: String  // hex
    var colorMid: String   // hex

    init(
        id: String = UUID().uuidString,
        name: String, slug: String, dayStart: Int, dayEnd: Int,
        calorieTarget: String, proteinTarget: String, fatTarget: String, carbTarget: String,
        heroEyebrow: String, heroTitle: String, heroSubtitle: String,
        phaseDescription: String, exerciseIntensity: String, saNote: String,
        color: String, colorSoft: String, colorMid: String
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.fatTarget = fatTarget
        self.carbTarget = carbTarget
        self.heroEyebrow = heroEyebrow
        self.heroTitle = heroTitle
        self.heroSubtitle = heroSubtitle
        self.phaseDescription = phaseDescription
        self.exerciseIntensity = exerciseIntensity
        self.saNote = saNote
        self.color = color
        self.colorSoft = colorSoft
        self.colorMid = colorMid
    }
}
