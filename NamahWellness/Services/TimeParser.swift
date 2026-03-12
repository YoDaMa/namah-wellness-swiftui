import Foundation

/// Shared utility for parsing time strings (e.g., "7:00am", "4:30pm") into minutes since midnight.
/// Used by TimeBlockService, NotificationService, and views for time-based sorting and grouping.
enum TimeParser {

    /// Parses a time string like "7:00am" or "4:30pm" into minutes since midnight.
    /// Returns nil if the string cannot be parsed.
    static func minutesSinceMidnight(from timeString: String) -> Int? {
        let lower = timeString.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lower.isEmpty else { return nil }

        let isPM = lower.contains("pm")
        let isAM = lower.contains("am")
        let cleaned = lower
            .replacingOccurrences(of: "am", with: "")
            .replacingOccurrences(of: "pm", with: "")
            .trimmingCharacters(in: .whitespaces)

        let parts = cleaned.split(separator: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard let hour = parts.first else { return nil }
        let minute = parts.count > 1 ? parts[1] : 0

        var h = hour
        if isPM && h != 12 { h += 12 }
        if isAM && h == 12 { h = 0 }
        // If neither AM nor PM specified, assume the raw hour
        if !isAM && !isPM && h > 23 { return nil }

        guard h >= 0 && h < 24 && minute >= 0 && minute < 60 else { return nil }
        return h * 60 + minute
    }

    /// Default minutes-since-midnight for a given meal type.
    /// Used as fallback when Meal.time is missing or unparseable.
    static func defaultMinutes(forMealType mealType: String) -> Int {
        switch mealType.lowercased() {
        case "breakfast": return 7 * 60       // 7:00am
        case "lunch":     return 12 * 60      // 12:00pm
        case "dinner":    return 18 * 60 + 30 // 6:30pm
        case "snack":     return 15 * 60      // 3:00pm
        default:          return 12 * 60      // noon fallback
        }
    }

    /// Default minutes-since-midnight for a supplement timeOfDay category.
    static func defaultMinutes(forSupplementTime timeOfDay: String, wakeMinutes: Int = 360, sleepMinutes: Int = 1320) -> Int {
        switch timeOfDay.lowercased() {
        case "morning":    return wakeMinutes + 30  // 30 min after wake
        case "with_meals": return 12 * 60           // noon
        case "evening":    return max(sleepMinutes - 60, wakeMinutes + 60) // 1 hour before sleep
        default:           return 12 * 60           // noon fallback
        }
    }

    /// Extracts hour and minute components from a Date (ignoring the date portion).
    static func minutesSinceMidnight(from date: Date) -> Int {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return h * 60 + m
    }

    /// Creates a Date for today at the given minutes since midnight.
    static func dateToday(atMinutes minutes: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .minute, value: minutes, to: today) ?? today
    }
}
