import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: String
    var name: String
    var dailyReminderEnabled: Bool
    var dailyReminderTime: Date
    var periodReminderEnabled: Bool
    var cycleLengthOverride: Int?
    var periodLengthOverride: Int?
    var overdueAckDate: String?
    var isPregnant: Bool = false
    var pregnancyStartDate: String?

    init(
        id: String = "default",
        name: String = "",
        dailyReminderEnabled: Bool = false,
        dailyReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date(),
        periodReminderEnabled: Bool = false,
        cycleLengthOverride: Int? = nil,
        periodLengthOverride: Int? = nil,
        overdueAckDate: String? = nil,
        isPregnant: Bool = false,
        pregnancyStartDate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderTime = dailyReminderTime
        self.periodReminderEnabled = periodReminderEnabled
        self.cycleLengthOverride = cycleLengthOverride
        self.periodLengthOverride = periodLengthOverride
        self.overdueAckDate = overdueAckDate
        self.isPregnant = isPregnant
        self.pregnancyStartDate = pregnancyStartDate
    }
}
