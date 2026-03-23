import Foundation
import SwiftData

@Model
final class Workout {
    @Attribute(.unique) var id: String
    var dayOfWeek: Int       // 0=Monday, 6=Sunday
    var dayLabel: String     // "Monday"
    var dayFocus: String     // "Strength", "Cardio", "Rest"
    var templateId: String?
    var isRestDay: Bool
    var hasCoreProtocol: Bool = true

    init(
        id: String = UUID().uuidString,
        dayOfWeek: Int, dayLabel: String, dayFocus: String, templateId: String? = nil, isRestDay: Bool, hasCoreProtocol: Bool = true
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.dayLabel = dayLabel
        self.dayFocus = dayFocus
        self.templateId = templateId
        self.isRestDay = isRestDay
        self.hasCoreProtocol = hasCoreProtocol
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: String
    var workoutId: String
    var timeSlot: String     // "9:10am"
    var title: String
    var sessionDescription: String

    init(
        id: String = UUID().uuidString,
        workoutId: String, timeSlot: String, title: String, sessionDescription: String
    ) {
        self.id = id
        self.workoutId = workoutId
        self.timeSlot = timeSlot
        self.title = title
        self.sessionDescription = sessionDescription
    }
}

@Model
final class CoreExercise {
    @Attribute(.unique) var id: String
    var name: String
    var exerciseDescription: String
    var sets: String

    init(id: String = UUID().uuidString, name: String, exerciseDescription: String, sets: String) {
        self.id = id
        self.name = name
        self.exerciseDescription = exerciseDescription
        self.sets = sets
    }
}
