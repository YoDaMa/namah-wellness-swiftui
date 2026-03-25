import Foundation
import UserNotifications
import os

enum NotificationService {
    private static let dailyReminderId = "namah.dailyReminder"
    private static let periodPredictionId = "namah.periodPrediction"
    private static let mealPrefix = "namah.meal."
    private static let supplementPrefix = "namah.supplement."
    private static let workoutId = "namah.workout"

    static let mealCategoryId = "MEAL_REMINDER"
    static let supplementCategoryId = "SUPPLEMENT_REMINDER"
    static let workoutCategoryId = "WORKOUT_REMINDER"
    static let markDoneActionId = "MARK_DONE"

    private static let logger = Logger(subsystem: "com.namah.wellness", category: "NotificationService")

    // MARK: - Permission

    static func requestPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Category Registration (call at app launch)

    static func registerCategories() {
        let markDone = UNNotificationAction(
            identifier: markDoneActionId,
            title: "Done",
            options: []
        )

        let mealCategory = UNNotificationCategory(
            identifier: mealCategoryId,
            actions: [markDone],
            intentIdentifiers: []
        )
        let supplementCategory = UNNotificationCategory(
            identifier: supplementCategoryId,
            actions: [markDone],
            intentIdentifiers: []
        )
        let workoutCategory = UNNotificationCategory(
            identifier: workoutCategoryId,
            actions: [markDone],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            mealCategory, supplementCategory, workoutCategory
        ])
        logger.info("Registered notification categories")
    }

    // MARK: - Daily Reminder (existing)

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
        do {
            try await center.add(request)
            logger.info("Scheduled daily reminder at \(components.hour ?? 0):\(components.minute ?? 0)")
        } catch {
            logger.error("Failed to schedule daily reminder: \(error.localizedDescription)")
        }
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyReminderId])
    }

    // MARK: - Period Prediction (existing)

    static func schedulePeriodPrediction(lastPeriodStart: String, effectiveCycleLength: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [periodPredictionId])

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let lastDate = formatter.date(from: lastPeriodStart) else { return }

        let daysUntilNext = effectiveCycleLength - 3
        guard let notifyDate = Calendar.current.date(byAdding: .day, value: daysUntilNext, to: lastDate),
              notifyDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Period Coming Soon"
        content.body = "Based on your \(effectiveCycleLength)-day cycle, your period may start in about 3 days."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: notifyDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: periodPredictionId, content: content, trigger: trigger)
        do {
            try await center.add(request)
            logger.info("Scheduled period prediction notification")
        } catch {
            logger.error("Failed to schedule period prediction: \(error.localizedDescription)")
        }
    }

    static func cancelPeriodPrediction() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [periodPredictionId])
    }

    // MARK: - Meal Reminders (NEW)

    struct MealNotificationInfo {
        let id: String
        let title: String
        let mealType: String
        let time: String
        let phaseName: String?
    }

    static func scheduleMealReminders(
        _ meals: [MealNotificationInfo],
        quietStart: Int? = nil,
        quietEnd: Int? = nil
    ) async {
        let center = UNUserNotificationCenter.current()

        // Remove existing meal notifications
        let pending = await center.pendingNotificationRequests()
        let oldMealIds = pending.map(\.identifier).filter { $0.hasPrefix(mealPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldMealIds)

        var scheduled = 0
        for meal in meals {
            let minutes = TimeParser.minutesSinceMidnight(from: meal.time)
                ?? TimeParser.defaultMinutes(forMealType: meal.mealType)

            // Quiet hours check
            if let qs = quietStart, let qe = quietEnd, isInQuietHours(minutes: minutes, quietStart: qs, quietEnd: qe) {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "\(meal.mealType.capitalized) Time"
            if let phase = meal.phaseName {
                content.body = "\(phase) phase pick: \(meal.title)"
            } else {
                content.body = meal.title
            }
            content.sound = .default
            content.categoryIdentifier = mealCategoryId
            content.userInfo = ["type": "meal", "itemId": meal.id]

            let hour = minutes / 60
            let minute = minutes % 60
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: "\(mealPrefix)\(meal.id)",
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                logger.error("Failed to schedule meal notification for \(meal.title): \(error.localizedDescription)")
            }
        }
        logger.info("Scheduled \(scheduled) meal notifications")
    }

    // MARK: - Supplement Reminders (NEW)

    struct SupplementNotificationInfo {
        let userSupplementId: String
        let name: String
        let timeOfDay: String
        let dosage: String
    }

    static func scheduleSupplementReminders(
        _ supplements: [SupplementNotificationInfo],
        wakeMinutes: Int = 360,
        sleepMinutes: Int = 1320,
        quietStart: Int? = nil,
        quietEnd: Int? = nil
    ) async {
        let center = UNUserNotificationCenter.current()

        // Remove existing supplement notifications
        let pending = await center.pendingNotificationRequests()
        let oldIds = pending.map(\.identifier).filter { $0.hasPrefix(supplementPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIds)

        // Group by timeOfDay to batch notifications
        let grouped = Dictionary(grouping: supplements) { $0.timeOfDay }
        var scheduled = 0

        for (timeOfDay, supps) in grouped {
            guard timeOfDay != "as_needed" else { continue }

            let minutes = TimeParser.defaultMinutes(
                forSupplementTime: timeOfDay,
                wakeMinutes: wakeMinutes,
                sleepMinutes: sleepMinutes
            )

            if let qs = quietStart, let qe = quietEnd, isInQuietHours(minutes: minutes, quietStart: qs, quietEnd: qe) {
                continue
            }

            let names = supps.map(\.name).joined(separator: ", ")

            let content = UNMutableNotificationContent()
            content.title = "\(timeOfDay == "with_meals" ? "Mealtime" : timeOfDay.capitalized) Supplements"
            content.body = "Time to take: \(names)"
            content.sound = .default
            content.categoryIdentifier = supplementCategoryId
            content.userInfo = [
                "type": "supplement",
                "itemIds": supps.map(\.userSupplementId),
                "timeOfDay": timeOfDay
            ]

            let hour = minutes / 60
            let minute = minutes % 60
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: "\(supplementPrefix)\(timeOfDay)",
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                logger.error("Failed to schedule supplement notification for \(timeOfDay): \(error.localizedDescription)")
            }
        }
        logger.info("Scheduled \(scheduled) supplement notifications")
    }

    // MARK: - Workout Reminder (NEW)

    static func scheduleWorkoutReminder(
        dayLabel: String,
        dayFocus: String,
        timeSlot: String,
        quietStart: Int? = nil,
        quietEnd: Int? = nil
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [workoutId])

        let minutes = TimeParser.minutesSinceMidnight(from: timeSlot) ?? (9 * 60)

        if let qs = quietStart, let qe = quietEnd, isInQuietHours(minutes: minutes, quietStart: qs, quietEnd: qe) {
            return
        }

        // Schedule 15 minutes before
        let notifyMinutes = max(0, minutes - 15)

        let content = UNMutableNotificationContent()
        content.title = "\(dayFocus) Workout"
        content.body = "Your \(dayLabel.lowercased()) workout starts in 15 minutes."
        content.sound = .default
        content.categoryIdentifier = workoutCategoryId
        content.userInfo = ["type": "workout"]

        let hour = notifyMinutes / 60
        let minute = notifyMinutes % 60

        // Schedule for the specific day of week
        let dayOfWeekMap = ["Monday": 2, "Tuesday": 3, "Wednesday": 4, "Thursday": 5, "Friday": 6, "Saturday": 7, "Sunday": 1]
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if let weekday = dayOfWeekMap[dayLabel] {
            components.weekday = weekday
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: workoutId, content: content, trigger: trigger)
        do {
            try await center.add(request)
            logger.info("Scheduled workout notification for \(dayLabel) at \(hour):\(minute)")
        } catch {
            logger.error("Failed to schedule workout notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Per-Item Habit Reminders

    private static let habitReminderPrefix = "namah.habitReminder."
    private static let supplementReminderPrefix = "namah.supplementReminder."
    static let habitReminderCategoryId = "HABIT_REMINDER"

    /// Schedule a notification reminder for a single habit
    static func scheduleHabitReminder(
        identifier: String,
        title: String,
        time: String,
        recurrence: HabitRecurrence,
        recurrenceDays: String?
    ) async {
        let center = UNUserNotificationCenter.current()
        let fullId = "\(habitReminderPrefix)\(identifier)"

        // Remove existing
        center.removePendingNotificationRequests(withIdentifiers: [fullId])

        guard let minutes = TimeParser.minutesSinceMidnight(from: time) else { return }
        let hour = minutes / 60
        let minute = minutes % 60

        let content = UNMutableNotificationContent()
        content.title = "Time for \(title)"
        content.sound = .default
        content.userInfo = ["type": "habit", "itemId": identifier]

        switch recurrence {
        case .daily:
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: fullId, content: content, trigger: trigger)
            try? await center.add(request)

        case .weekdays:
            for weekday in 2...6 {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: "\(fullId)-\(weekday)", content: content, trigger: trigger)
                try? await center.add(request)
            }

        case .specificDays:
            let dayIndices = (recurrenceDays ?? "").split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            for dayIndex in dayIndices {
                // dayIndex 0=Monday → weekday 2, 6=Sunday → weekday 1
                let weekday = dayIndex == 6 ? 1 : dayIndex + 2
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: "\(fullId)-\(weekday)", content: content, trigger: trigger)
                try? await center.add(request)
            }

        case .once:
            // Non-repeating — schedule for today at the specified time
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: fullId, content: content, trigger: trigger)
            try? await center.add(request)
        }

        logger.info("Scheduled habit reminder for '\(title)'")
    }

    /// Cancel a habit reminder
    static func cancelHabitReminder(identifier: String) {
        let center = UNUserNotificationCenter.current()
        let prefix = "\(habitReminderPrefix)\(identifier)"
        // Cancel all variants (daily + per-weekday)
        let ids = [prefix] + (1...7).map { "\(prefix)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Reschedule all habit and supplement reminders from current data
    static func rescheduleAllItemReminders(habits: [Habit], supplements: [UserSupplement]) async {
        let center = UNUserNotificationCenter.current()

        // Remove all existing item reminders
        let pending = await center.pendingNotificationRequests()
        let oldIds = pending.map(\.identifier).filter {
            $0.hasPrefix(habitReminderPrefix) || $0.hasPrefix(supplementReminderPrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: oldIds)

        // Schedule habit reminders
        for habit in habits where habit.reminderEnabled && habit.isActive {
            guard let time = habit.reminderTime else { continue }
            await scheduleHabitReminder(
                identifier: habit.id,
                title: habit.title,
                time: time,
                recurrence: habit.recurrence,
                recurrenceDays: habit.recurrenceDays
            )
        }

        // Schedule supplement/medication reminders
        for supp in supplements where supp.reminderEnabled && supp.isActive {
            guard let time = supp.reminderTime else { continue }
            let name = supp.supplementTitle ?? "Supplement"
            let fullId = "\(supplementReminderPrefix)\(supp.id)"

            let content = UNMutableNotificationContent()
            content.title = "Time for \(name)"
            content.sound = .default
            content.userInfo = ["type": "supplement", "itemId": supp.id]

            guard let minutes = TimeParser.minutesSinceMidnight(from: time) else { continue }
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: fullId, content: content, trigger: trigger)
            try? await center.add(request)
        }

        logger.info("Rescheduled all item reminders")
    }

    // MARK: - Reschedule All (orchestrator)

    static func cancelHabitNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let habitIds = pending.map(\.identifier).filter {
            $0.hasPrefix(mealPrefix) || $0.hasPrefix(supplementPrefix) || $0 == workoutId
                || $0.hasPrefix(habitReminderPrefix) || $0.hasPrefix(supplementReminderPrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: habitIds)
        logger.info("Cancelled \(habitIds.count) habit notifications")
    }

    // MARK: - Pending Count (for debug panel)

    static func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }

    static func pendingRequests() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    // MARK: - Quiet Hours

    private static func isInQuietHours(minutes: Int, quietStart: Int, quietEnd: Int) -> Bool {
        if quietStart < quietEnd {
            // Normal range (e.g., 22:00 - 06:00 won't hit this)
            return minutes >= quietStart && minutes < quietEnd
        } else {
            // Wraps midnight (e.g., quietStart=22:00, quietEnd=06:00)
            return minutes >= quietStart || minutes < quietEnd
        }
    }
}
