import Foundation
import SwiftData

// MARK: - Types

struct PhaseInfo {
    let phaseName: String
    let phaseSlug: String
    let cycleDay: Int
    let dayInPhase: Int
    let periodStartDate: String
    let isOverridden: Bool
    let color: String
    let colorSoft: String
}

struct CycleStats {
    let avgCycleLength: Int
    let avgPeriodLength: Int
    let cycleCount: Int
}

struct PhaseRange {
    let start: Int
    let end: Int
}

struct PhaseRanges {
    let menstrual: PhaseRange
    let follicular: PhaseRange
    let ovulatory: PhaseRange
    let luteal: PhaseRange
}

struct CycleBundle {
    let currentPhase: PhaseInfo?
    let cycleStats: CycleStats
    let phaseRanges: PhaseRanges
}

// MARK: - CycleService

@Observable
final class CycleService {
    private(set) var currentPhase: PhaseInfo?
    private(set) var cycleStats: CycleStats = CycleStats(avgCycleLength: 28, avgPeriodLength: 5, cycleCount: 0)
    private(set) var phaseRanges: PhaseRanges = CycleService.computePhaseRanges(cycleLength: 28, periodLength: 5)

    private static let defaultCycleLength = 28
    private static let defaultPeriodLength = 5
    private static let follicularRatio = 8.0 / 23.0
    private static let ovulatoryRatio = 4.0 / 23.0

    func recalculate(logs: [CycleLog], phases: [Phase]) {
        let stats = Self.computeCycleStats(logs: logs)
        let ranges = Self.computePhaseRanges(cycleLength: stats.avgCycleLength, periodLength: stats.avgPeriodLength)
        let phase = Self.computeCurrentPhase(logs: logs, phases: phases, stats: stats)

        self.cycleStats = stats
        self.phaseRanges = ranges
        self.currentPhase = phase
    }

    // MARK: - Pure computation

    static func computeCycleStats(logs: [CycleLog]) -> CycleStats {
        // Logs should be sorted newest-first by createdAt
        let sorted = logs.sorted { $0.createdAt > $1.createdAt }

        guard !sorted.isEmpty else {
            return CycleStats(avgCycleLength: defaultCycleLength, avgPeriodLength: defaultPeriodLength, cycleCount: 0)
        }

        var periodLengths: [Int] = []
        for log in sorted {
            if let endDate = log.periodEndDate {
                let days = daysBetween(log.periodStartDate, endDate)
                if days > 0 && days <= 15 { periodLengths.append(days) }
            }
        }

        var cycleLengths: [Int] = []
        for i in 0..<(sorted.count - 1) {
            let days = daysBetween(sorted[i + 1].periodStartDate, sorted[i].periodStartDate)
            if days > 15 && days <= 60 { cycleLengths.append(days) }
        }

        let recentCycles = Array(cycleLengths.prefix(3))
        let recentPeriods = Array(periodLengths.prefix(3))

        let avgCycle = recentCycles.isEmpty ? defaultCycleLength : recentCycles.reduce(0, +) / recentCycles.count
        let avgPeriod = recentPeriods.isEmpty ? defaultPeriodLength : recentPeriods.reduce(0, +) / recentPeriods.count

        return CycleStats(avgCycleLength: avgCycle, avgPeriodLength: avgPeriod, cycleCount: sorted.count)
    }

    static func computePhaseRanges(cycleLength: Int, periodLength: Int) -> PhaseRanges {
        let remaining = Double(cycleLength - periodLength)
        let follicularDays = Int(round(remaining * follicularRatio))
        let ovulatoryDays = Int(round(remaining * ovulatoryRatio))

        let menstrualEnd = periodLength
        let follicularEnd = menstrualEnd + follicularDays
        let ovulatoryEnd = follicularEnd + ovulatoryDays

        return PhaseRanges(
            menstrual: PhaseRange(start: 1, end: menstrualEnd),
            follicular: PhaseRange(start: menstrualEnd + 1, end: follicularEnd),
            ovulatory: PhaseRange(start: follicularEnd + 1, end: ovulatoryEnd),
            luteal: PhaseRange(start: ovulatoryEnd + 1, end: cycleLength)
        )
    }

    static func computeCurrentPhase(logs: [CycleLog], phases: [Phase], stats: CycleStats) -> PhaseInfo? {
        let sorted = logs.sorted { $0.createdAt > $1.createdAt }
        guard let latest = sorted.first else { return nil }

        if let override = latest.phaseOverride, let phase = phases.first(where: { $0.slug == override }) {
            return PhaseInfo(
                phaseName: phase.name, phaseSlug: phase.slug,
                cycleDay: getCycleDay(from: latest.periodStartDate),
                dayInPhase: 1, periodStartDate: latest.periodStartDate,
                isOverridden: true, color: phase.color, colorSoft: phase.colorSoft
            )
        }

        let ranges = computePhaseRanges(cycleLength: stats.avgCycleLength, periodLength: stats.avgPeriodLength)
        let cycleDay = getCycleDay(from: latest.periodStartDate)
        let effectiveDay = min(cycleDay, stats.avgCycleLength)

        let phaseEntries: [(slug: String, range: PhaseRange)] = [
            ("menstrual", ranges.menstrual),
            ("follicular", ranges.follicular),
            ("ovulatory", ranges.ovulatory),
            ("luteal", ranges.luteal),
        ]

        let matched = phaseEntries.first(where: { effectiveDay >= $0.range.start && effectiveDay <= $0.range.end }) ?? phaseEntries[3]

        guard let phase = phases.first(where: { $0.slug == matched.slug }) else { return nil }

        return PhaseInfo(
            phaseName: phase.name, phaseSlug: phase.slug,
            cycleDay: cycleDay, dayInPhase: effectiveDay - matched.range.start + 1,
            periodStartDate: latest.periodStartDate, isOverridden: false,
            color: phase.color, colorSoft: phase.colorSoft
        )
    }

    // MARK: - Helpers

    private static func getCycleDay(from periodStartDate: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let start = formatter.date(from: periodStartDate) else { return 1 }
        let today = Calendar.current.startOfDay(for: Date())
        let startDay = Calendar.current.startOfDay(for: start)
        let days = Calendar.current.dateComponents([.day], from: startDay, to: today).day ?? 0
        return max(1, days + 1)
    }

    private static func daysBetween(_ from: String, _ to: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let d1 = formatter.date(from: from), let d2 = formatter.date(from: to) else { return 0 }
        return Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0
    }
}
