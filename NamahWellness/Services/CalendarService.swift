import Foundation

struct DayPhaseInfo {
    let phaseSlug: String   // menstrual, follicular, ovulatory, luteal
    let cycleDay: Int       // 1-based from cycle start
    let dayInPhase: Int     // 1-based from phase start
    let isPeak: Bool        // true for ovulatory days 2-3
    let isProjected: Bool   // true if future or before first log
}

struct CalendarDay: Identifiable {
    let id: String          // "yyyy-MM-dd"
    let date: Date
    let dayOfMonth: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    let phase: DayPhaseInfo?
}

enum CalendarService {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Monday
        return c
    }()

    // MARK: - Generate 42-day grid

    static func generateCalendarDays(
        anchor: Date,
        logs: [CycleLog],
        stats: CycleStats,
        phaseRanges: PhaseRanges
    ) -> [CalendarDay] {
        let cal = calendar
        let today = formatter.string(from: Date())
        let anchorMonth = cal.component(.month, from: anchor)

        // Get first day of anchor's month, then snap to previous Monday
        let monthComponents = cal.dateComponents([.year, .month], from: anchor)
        guard let firstOfMonth = cal.date(from: monthComponents) else { return [] }
        let weekday = cal.component(.weekday, from: firstOfMonth) // 1=Sun, 2=Mon
        let mondayOffset = weekday == 1 ? -6 : 2 - weekday
        guard let gridStart = cal.date(byAdding: .day, value: mondayOffset, to: firstOfMonth) else { return [] }

        let sortedLogs = logs.sorted { $0.periodStartDate < $1.periodStartDate }

        var days: [CalendarDay] = []
        for i in 0..<42 {
            guard let date = cal.date(byAdding: .day, value: i, to: gridStart) else { continue }
            let dateStr = formatter.string(from: date)
            let dayOfMonth = cal.component(.day, from: date)
            let month = cal.component(.month, from: date)

            let phase = getPhaseForDate(dateStr, logs: sortedLogs, stats: stats, phaseRanges: phaseRanges)

            days.append(CalendarDay(
                id: dateStr,
                date: date,
                dayOfMonth: dayOfMonth,
                isCurrentMonth: month == anchorMonth,
                isToday: dateStr == today,
                phase: phase
            ))
        }
        return days
    }

    // MARK: - Phase for a specific date

    static func getPhaseForDate(
        _ dateStr: String,
        logs: [CycleLog],
        stats: CycleStats,
        phaseRanges: PhaseRanges
    ) -> DayPhaseInfo? {
        guard !logs.isEmpty else { return nil }

        guard let targetDate = formatter.date(from: dateStr) else { return nil }
        let cal = calendar

        // Find which cycle this date falls into
        var cycleStartDate: Date?
        var cycleLength: Int = stats.avgCycleLength
        var isProjected = false

        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: targetDate)

        if target > today {
            isProjected = true
        }

        // Sort logs ascending by date
        let logDates: [(date: Date, str: String)] = logs.compactMap { log in
            guard let d = formatter.date(from: log.periodStartDate) else { return nil }
            return (cal.startOfDay(for: d), log.periodStartDate)
        }.sorted { $0.date < $1.date }

        guard !logDates.isEmpty else { return nil }

        // Before first log
        if target < logDates[0].date {
            // Project backwards
            isProjected = true
            let daysBefore = cal.dateComponents([.day], from: target, to: logDates[0].date).day ?? 0
            let cyclesBack = (daysBefore / stats.avgCycleLength) + 1
            guard let projected = cal.date(byAdding: .day, value: -cyclesBack * stats.avgCycleLength, to: logDates[0].date) else { return nil }
            cycleStartDate = projected
            cycleLength = stats.avgCycleLength
        } else {
            // Find the cycle this date falls into
            for i in (0..<logDates.count).reversed() {
                if target >= logDates[i].date {
                    cycleStartDate = logDates[i].date

                    if i < logDates.count - 1 {
                        // Between two logs: use actual gap
                        let gap = cal.dateComponents([.day], from: logDates[i].date, to: logDates[i + 1].date).day ?? stats.avgCycleLength
                        cycleLength = (gap > 15 && gap <= 60) ? gap : stats.avgCycleLength
                    } else {
                        // After last log: use average
                        cycleLength = stats.avgCycleLength
                    }
                    break
                }
            }
        }

        guard let startDate = cycleStartDate else { return nil }

        var cycleDay = (cal.dateComponents([.day], from: startDate, to: target).day ?? 0) + 1

        // If past end of cycle, project forward
        if cycleDay > cycleLength {
            let overflow = cycleDay - 1
            let cyclesForward = overflow / stats.avgCycleLength
            cycleDay = (overflow % stats.avgCycleLength) + 1
            isProjected = true
            _ = cyclesForward // used for projection
        }

        // Determine phase from cycle day
        let ranges = CycleService.computePhaseRanges(cycleLength: cycleLength, periodLength: stats.avgPeriodLength)
        let phaseEntries: [(slug: String, start: Int, end: Int)] = [
            ("menstrual", ranges.menstrual.start, ranges.menstrual.end),
            ("follicular", ranges.follicular.start, ranges.follicular.end),
            ("ovulatory", ranges.ovulatory.start, ranges.ovulatory.end),
            ("luteal", ranges.luteal.start, ranges.luteal.end),
        ]

        let effectiveDay = min(cycleDay, cycleLength)
        let matched = phaseEntries.first(where: { effectiveDay >= $0.start && effectiveDay <= $0.end }) ?? phaseEntries[3]
        let dayInPhase = effectiveDay - matched.start + 1
        let isPeak = matched.slug == "ovulatory" && (dayInPhase == 2 || dayInPhase == 3)

        return DayPhaseInfo(
            phaseSlug: matched.slug,
            cycleDay: cycleDay,
            dayInPhase: dayInPhase,
            isPeak: isPeak,
            isProjected: isProjected
        )
    }
}
