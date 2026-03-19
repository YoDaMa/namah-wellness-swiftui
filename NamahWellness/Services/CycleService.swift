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
    let observedAvgCycleLength: Int
    let observedAvgPeriodLength: Int
    let effectiveCycleLength: Int
    let effectivePeriodLength: Int
    let userDefaultCycleLength: Int?
    let userDefaultPeriodLength: Int?
    let cycleCount: Int
    let daysOverdue: Int
    let isOverdue: Bool

    // Backward-compatible aliases
    var avgCycleLength: Int { effectiveCycleLength }
    var avgPeriodLength: Int { effectivePeriodLength }
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
    private(set) var cycleStats: CycleStats = CycleStats(
        observedAvgCycleLength: 28, observedAvgPeriodLength: 5,
        effectiveCycleLength: 28, effectivePeriodLength: 5,
        userDefaultCycleLength: nil, userDefaultPeriodLength: nil,
        cycleCount: 0, daysOverdue: 0, isOverdue: false
    )
    private(set) var phaseRanges: PhaseRanges = CycleService.computePhaseRanges(cycleLength: 28, periodLength: 5)

    private static let defaultCycleLength = 28
    private static let defaultPeriodLength = 5
    private static let follicularRatio = 8.0 / 23.0
    private static let ovulatoryRatio = 4.0 / 23.0

    func recalculate(logs: [CycleLog], phases: [Phase], profile: UserProfile? = nil) {
        let stats = Self.computeCycleStats(
            logs: logs,
            cycleLengthOverride: profile?.cycleLengthOverride,
            periodLengthOverride: profile?.periodLengthOverride
        )
        let ranges = Self.computePhaseRanges(
            cycleLength: stats.effectiveCycleLength,
            periodLength: stats.effectivePeriodLength
        )
        let phase = Self.computeCurrentPhase(logs: logs, phases: phases, stats: stats)

        self.cycleStats = stats
        self.phaseRanges = ranges
        self.currentPhase = phase
    }

    // MARK: - Pure computation

    static func computeCycleStats(
        logs: [CycleLog],
        cycleLengthOverride: Int? = nil,
        periodLengthOverride: Int? = nil
    ) -> CycleStats {
        let sorted = logs.sorted { $0.periodStartDate > $1.periodStartDate }

        let observedCycle: Int
        let observedPeriod: Int
        let count: Int

        if sorted.isEmpty {
            observedCycle = defaultCycleLength
            observedPeriod = defaultPeriodLength
            count = 0
        } else {
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

            observedCycle = recentCycles.isEmpty ? defaultCycleLength : recentCycles.reduce(0, +) / recentCycles.count
            observedPeriod = recentPeriods.isEmpty ? defaultPeriodLength : recentPeriods.reduce(0, +) / recentPeriods.count
            count = sorted.count
        }

        let effectiveCycle = cycleLengthOverride ?? observedCycle
        let effectivePeriod = periodLengthOverride ?? observedPeriod

        // Compute overdue
        let daysOverdue: Int
        if let latest = sorted.first {
            let rawDay = getCycleDay(from: latest.periodStartDate)
            daysOverdue = max(0, rawDay - effectiveCycle)
        } else {
            daysOverdue = 0
        }

        return CycleStats(
            observedAvgCycleLength: observedCycle,
            observedAvgPeriodLength: observedPeriod,
            effectiveCycleLength: effectiveCycle,
            effectivePeriodLength: effectivePeriod,
            userDefaultCycleLength: cycleLengthOverride,
            userDefaultPeriodLength: periodLengthOverride,
            cycleCount: count,
            daysOverdue: daysOverdue,
            isOverdue: daysOverdue > 0
        )
    }

    static func computePhaseRanges(cycleLength: Int, periodLength: Int) -> PhaseRanges {
        // Clamp to safe bounds
        let clampedCycle = max(20, min(40, cycleLength))
        let clampedPeriod = max(2, min(min(10, clampedCycle - 10), periodLength))

        let remaining = Double(clampedCycle - clampedPeriod)
        let follicularDays = Int(round(remaining * follicularRatio))
        let ovulatoryDays = Int(round(remaining * ovulatoryRatio))

        let menstrualEnd = clampedPeriod
        let follicularEnd = menstrualEnd + follicularDays
        let ovulatoryEnd = follicularEnd + ovulatoryDays

        return PhaseRanges(
            menstrual: PhaseRange(start: 1, end: menstrualEnd),
            follicular: PhaseRange(start: menstrualEnd + 1, end: follicularEnd),
            ovulatory: PhaseRange(start: follicularEnd + 1, end: ovulatoryEnd),
            luteal: PhaseRange(start: ovulatoryEnd + 1, end: clampedCycle)
        )
    }

    static func computeCurrentPhase(logs: [CycleLog], phases: [Phase], stats: CycleStats) -> PhaseInfo? {
        // Sort by periodStartDate, newest first
        let sorted = logs.sorted { $0.periodStartDate > $1.periodStartDate }
        guard let latest = sorted.first else { return nil }

        let ranges = computePhaseRanges(cycleLength: stats.effectiveCycleLength, periodLength: stats.effectivePeriodLength)
        let rawCycleDay = getCycleDay(from: latest.periodStartDate)

        // When overdue, stay in luteal — don't wrap
        let cycleDay: Int
        if rawCycleDay > stats.effectiveCycleLength {
            cycleDay = stats.effectiveCycleLength  // pin to last day (luteal)
        } else {
            cycleDay = rawCycleDay
        }

        if let override = latest.phaseOverride, let phase = phases.first(where: { $0.slug == override }) {
            // Compute a meaningful dayInPhase for the override
            let overrideRange = rangeForSlug(override, ranges: ranges)
            let dayInPhase = max(1, cycleDay - overrideRange.start + 1)

            return PhaseInfo(
                phaseName: phase.name, phaseSlug: phase.slug,
                cycleDay: rawCycleDay,
                dayInPhase: dayInPhase, periodStartDate: latest.periodStartDate,
                isOverridden: true, color: phase.color, colorSoft: phase.colorSoft
            )
        }

        let phaseEntries: [(slug: String, range: PhaseRange)] = [
            ("menstrual", ranges.menstrual),
            ("follicular", ranges.follicular),
            ("ovulatory", ranges.ovulatory),
            ("luteal", ranges.luteal),
        ]

        let matched = phaseEntries.first(where: { cycleDay >= $0.range.start && cycleDay <= $0.range.end }) ?? phaseEntries[3]

        guard let phase = phases.first(where: { $0.slug == matched.slug }) else { return nil }

        return PhaseInfo(
            phaseName: phase.name, phaseSlug: phase.slug,
            cycleDay: rawCycleDay, dayInPhase: cycleDay - matched.range.start + 1,
            periodStartDate: latest.periodStartDate, isOverridden: false,
            color: phase.color, colorSoft: phase.colorSoft
        )
    }

    // MARK: - Helpers

    private static func rangeForSlug(_ slug: String, ranges: PhaseRanges) -> PhaseRange {
        switch slug {
        case "menstrual": return ranges.menstrual
        case "follicular": return ranges.follicular
        case "ovulatory": return ranges.ovulatory
        case "luteal": return ranges.luteal
        default: return ranges.luteal
        }
    }

    private static func getCycleDay(from periodStartDate: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        guard let start = formatter.date(from: periodStartDate) else { return 1 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startDay = cal.startOfDay(for: start)
        let days = cal.dateComponents([.day], from: startDay, to: today).day ?? 0
        return max(1, days + 1)
    }

    private static func daysBetween(_ from: String, _ to: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        guard let d1 = formatter.date(from: from), let d2 = formatter.date(from: to) else { return 0 }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: d1), to: cal.startOfDay(for: d2)).day ?? 0
    }
}
