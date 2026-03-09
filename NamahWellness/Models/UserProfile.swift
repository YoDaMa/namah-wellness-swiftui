import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: String
    var name: String
    var dailyReminderEnabled: Bool
    var dailyReminderTime: Date
    var periodReminderEnabled: Bool

    init(
        id: String = "default",
        name: String = "",
        dailyReminderEnabled: Bool = false,
        dailyReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date(),
        periodReminderEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderTime = dailyReminderTime
        self.periodReminderEnabled = periodReminderEnabled
    }
}
