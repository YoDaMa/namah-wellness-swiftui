import Foundation
import UserNotifications

enum NotificationService {
    private static let dailyReminderId = "namah.dailyReminder"
    private static let periodPredictionId = "namah.periodPrediction"

    static func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        return settings.authorizationStatus == .authorized
    }

    static func scheduleDailyReminder(at time: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderId])

        let content = UNMutableNotificationContent()
        content.title = "Daily Check-in"
        content.body = "Log your symptoms, meals, and how you're feeling today."
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: dailyReminderId, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyReminderId])
    }

    static func schedulePeriodPrediction(lastPeriodStart: String, avgCycleLength: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [periodPredictionId])

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let lastDate = formatter.date(from: lastPeriodStart) else { return }

        let daysUntilNext = avgCycleLength - 3
        guard let notifyDate = Calendar.current.date(byAdding: .day, value: daysUntilNext, to: lastDate),
              notifyDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Period Coming Soon"
        content.body = "Your period is predicted to start in about 3 days."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: notifyDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: periodPredictionId, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelPeriodPrediction() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [periodPredictionId])
    }
}
