import Foundation
import SwiftData

@Model
final class DailySchedule {
    @Attribute(.unique) var id: String
    var wakeTime: Date
    var sleepTime: Date
    var quietHoursEnabled: Bool
    var habitNotificationsEnabled: Bool

    init(
        id: String = "default",
        wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 6, minute: 0)) ?? Date(),
        sleepTime: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date(),
        quietHoursEnabled: Bool = true,
        habitNotificationsEnabled: Bool = false
    ) {
        self.id = id
        self.wakeTime = wakeTime
        self.sleepTime = sleepTime
        self.quietHoursEnabled = quietHoursEnabled
        self.habitNotificationsEnabled = habitNotificationsEnabled
    }
}
