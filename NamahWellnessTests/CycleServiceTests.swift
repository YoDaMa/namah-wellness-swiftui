import XCTest
@testable import NamahWellness

final class CycleServiceTests: XCTestCase {

    // MARK: - effectiveCycleLength

    func testEffectiveLengthUsesOverrideWhenSet() {
        let log1 = CycleLog(periodStartDate: "2026-02-01")
        let log2 = CycleLog(periodStartDate: "2026-03-03") // 30-day gap
        let stats = CycleService.computeCycleStats(
            logs: [log1, log2],
            cycleLengthOverride: 32,
            periodLengthOverride: nil
        )
        XCTAssertEqual(stats.effectiveCycleLength, 32)
        XCTAssertEqual(stats.observedAvgCycleLength, 30)
    }

    func testEffectiveLengthFallsBackToObservedAvg() {
        let log1 = CycleLog(periodStartDate: "2026-02-01")
        let log2 = CycleLog(periodStartDate: "2026-03-03") // 30-day gap
        let stats = CycleService.computeCycleStats(
            logs: [log1, log2],
            cycleLengthOverride: nil,
            periodLengthOverride: nil
        )
        XCTAssertEqual(stats.effectiveCycleLength, 30)
        XCTAssertEqual(stats.observedAvgCycleLength, 30)
    }

    func testEffectiveLengthFallsBackToDefaultWhenNoLogs() {
        let stats = CycleService.computeCycleStats(
            logs: [],
            cycleLengthOverride: nil,
            periodLengthOverride: nil
        )
        XCTAssertEqual(stats.effectiveCycleLength, 28)
    }

    func testEffectivePeriodLengthUsesOverride() {
        let stats = CycleService.computeCycleStats(
            logs: [],
            cycleLengthOverride: nil,
            periodLengthOverride: 7
        )
        XCTAssertEqual(stats.effectivePeriodLength, 7)
    }

    // MARK: - Bounds clamping

    func testPhaseRangesClampsCycleLengthToMin20() {
        let ranges = CycleService.computePhaseRanges(cycleLength: 10, periodLength: 3)
        XCTAssertEqual(ranges.luteal.end, 20)
    }

    func testPhaseRangesClampsCycleLengthToMax40() {
        let ranges = CycleService.computePhaseRanges(cycleLength: 50, periodLength: 5)
        XCTAssertEqual(ranges.luteal.end, 40)
    }

    func testPhaseRangesClampsPeriodLengthWhenExceedsCycle() {
        let ranges = CycleService.computePhaseRanges(cycleLength: 20, periodLength: 18)
        XCTAssertTrue(ranges.menstrual.end <= 10)
    }

    // MARK: - Overdue detection

    func testDaysOverdueWhenPastEffectiveLength() {
        // 35 days ago → cycle day 36 (1-based) → 36 - 32 = 4 days overdue
        let log = CycleLog(periodStartDate: daysAgo(35))
        let stats = CycleService.computeCycleStats(
            logs: [log],
            cycleLengthOverride: 32,
            periodLengthOverride: nil
        )
        XCTAssertEqual(stats.daysOverdue, 4)
        XCTAssertTrue(stats.isOverdue)
    }

    func testNotOverdueWhenWithinCycle() {
        let log = CycleLog(periodStartDate: daysAgo(20))
        let stats = CycleService.computeCycleStats(
            logs: [log],
            cycleLengthOverride: 32,
            periodLengthOverride: nil
        )
        XCTAssertEqual(stats.daysOverdue, 0)
        XCTAssertFalse(stats.isOverdue)
    }

    // MARK: - No wrap when overdue (extend luteal)

    func testCurrentPhaseExtendsLutealWhenOverdue() {
        let log = CycleLog(periodStartDate: daysAgo(35))
        let allPhases = [
            Phase(id: "m", name: "Menstrual", slug: "menstrual", dayStart: 1, dayEnd: 5,
                  calorieTarget: "", proteinTarget: "", fatTarget: "", carbTarget: "",
                  heroEyebrow: "", heroTitle: "", heroSubtitle: "",
                  phaseDescription: "", exerciseIntensity: "", saNote: "",
                  color: "#EF4444", colorSoft: "#FEE2E2", colorMid: "#F87171"),
            Phase(id: "f", name: "Follicular", slug: "follicular", dayStart: 6, dayEnd: 13,
                  calorieTarget: "", proteinTarget: "", fatTarget: "", carbTarget: "",
                  heroEyebrow: "", heroTitle: "", heroSubtitle: "",
                  phaseDescription: "", exerciseIntensity: "", saNote: "",
                  color: "#10B981", colorSoft: "#D1FAE5", colorMid: "#34D399"),
            Phase(id: "o", name: "Ovulatory", slug: "ovulatory", dayStart: 14, dayEnd: 17,
                  calorieTarget: "", proteinTarget: "", fatTarget: "", carbTarget: "",
                  heroEyebrow: "", heroTitle: "", heroSubtitle: "",
                  phaseDescription: "", exerciseIntensity: "", saNote: "",
                  color: "#F59E0B", colorSoft: "#FEF3C7", colorMid: "#FBBF24"),
            Phase(id: "l", name: "Luteal", slug: "luteal", dayStart: 18, dayEnd: 32,
                  calorieTarget: "", proteinTarget: "", fatTarget: "", carbTarget: "",
                  heroEyebrow: "", heroTitle: "Luteal", heroSubtitle: "",
                  phaseDescription: "", exerciseIntensity: "", saNote: "",
                  color: "#8B5CF6", colorSoft: "#EDE9FE", colorMid: "#A78BFA")
        ]
        let stats = CycleService.computeCycleStats(
            logs: [log],
            cycleLengthOverride: 32,
            periodLengthOverride: nil
        )
        let result = CycleService.computeCurrentPhase(logs: [log], phases: allPhases, stats: stats)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.phaseSlug, "luteal", "Should stay in luteal, not wrap to menstrual")
        XCTAssertEqual(result?.cycleDay, 36, "Should show raw cycle day, not wrapped")
    }

    // MARK: - Helpers

    private func daysAgo(_ n: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let date = Calendar.current.date(byAdding: .day, value: -n, to: Date())!
        return formatter.string(from: date)
    }
}
