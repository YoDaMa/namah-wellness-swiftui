# Cycle Length Intelligence Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the broken cycle length override, add overdue period detection with "Has your period started?" UX, and display dual stats (user-set vs observed average).

**Architecture:** `CycleService.recalculate()` gains a `profile` parameter so user-set cycle/period length overrides drive all calculations. `CycleStats` expands to carry `effectiveCycleLength` (override ?? observed avg ?? 28), `observedAvgCycleLength`, `daysOverdue`, and `isOverdue`. The overdue state extends luteal phase instead of wrapping. A new `PeriodPromptBanner` in TodayView asks "Has your period started?" when overdue. ContentView watches profile changes to trigger recalculation.

**Tech Stack:** SwiftUI, SwiftData, XCTest

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `NamahWellness/Services/CycleService.swift` | Modify | Add profile param, expand CycleStats, effective length logic, overdue computation, no-wrap when overdue |
| `NamahWellness/Models/UserProfile.swift` | Modify | Add `overdueAckDate`, `isPregnant`, `pregnancyStartDate` fields |
| `NamahWellness/App/ContentView.swift` | Modify | Add `@Query profiles`, `profileSnapshot`, pass profile to recalculate |
| `NamahWellness/Views/Profile/EditProfileView.swift` | Modify | Tighten picker to 20-40, add validation |
| `NamahWellness/Services/CycleLogManager.swift` | Modify | Use effectiveCycleLength, skip auto-log when overdue |
| `NamahWellness/Services/CalendarService.swift` | Modify | Use effectiveCycleLength from stats, extend luteal when overdue |
| `NamahWellness/Views/Today/TodayView.swift` | Modify | Add PeriodPromptBanner, days-since-period counter |
| `NamahWellness/Views/MyCycle/MyCycleView.swift` | Modify | Dual stats display, use effectiveCycleLength in pill |
| `NamahWellness/Services/NotificationService.swift` | Modify | Smart notification copy with cycle length |
| `NamahWellnessTests/CycleServiceTests.swift` | Create | Unit tests for all new CycleService logic |

---

## Task 1: Expand CycleStats and Wire Override into CycleService

**Files:**
- Modify: `NamahWellness/Services/CycleService.swift:17-21` (CycleStats struct)
- Modify: `NamahWellness/Services/CycleService.swift:54-62` (recalculate method)
- Modify: `NamahWellness/Services/CycleService.swift:66-95` (computeCycleStats)
- Modify: `NamahWellness/Services/CycleService.swift:97-112` (computePhaseRanges — add clamping)
- Modify: `NamahWellness/Services/CycleService.swift:114-160` (computeCurrentPhase — no wrap when overdue)
- Create: `NamahWellnessTests/CycleServiceTests.swift`

- [ ] **Step 1: Write failing tests for effective cycle length**

```swift
// NamahWellnessTests/CycleServiceTests.swift
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
        // Should clamp to 20
        XCTAssertEqual(ranges.luteal.end, 20)
    }

    func testPhaseRangesClampsCycleLengthToMax40() {
        let ranges = CycleService.computePhaseRanges(cycleLength: 50, periodLength: 5)
        XCTAssertEqual(ranges.luteal.end, 40)
    }

    func testPhaseRangesClampsPeriodLengthWhenExceedsCycle() {
        let ranges = CycleService.computePhaseRanges(cycleLength: 20, periodLength: 18)
        // Period should be clamped to max cycleLength - 10
        XCTAssertTrue(ranges.menstrual.end <= 10)
    }

    // MARK: - Overdue detection

    func testDaysOverdueWhenPastEffectiveLength() {
        // Last period 35 days ago, effective cycle = 32
        let log = CycleLog(periodStartDate: daysAgo(35))
        let stats = CycleService.computeCycleStats(
            logs: [log],
            cycleLengthOverride: 32,
            periodLengthOverride: nil
        )
        XCTAssertEqual(stats.daysOverdue, 3)
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
        // Last period 35 days ago, effective cycle = 32
        let log = CycleLog(periodStartDate: daysAgo(35))
        let phase = Phase(
            id: "luteal-id", name: "Luteal", slug: "luteal",
            dayStart: 1, dayEnd: 28,
            calorieTarget: "", proteinTarget: "", fatTarget: "", carbTarget: "",
            heroEyebrow: "", heroTitle: "Luteal", heroSubtitle: "",
            phaseDescription: "", exerciseIntensity: "", saNote: "",
            color: "#8B5CF6", colorSoft: "#EDE9FE", colorMid: "#A78BFA"
        )
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
            phase
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:NamahWellnessTests/CycleServiceTests 2>&1 | tail -20`

Expected: FAIL — `computeCycleStats` doesn't accept override params, `CycleStats` doesn't have `effectiveCycleLength`

- [ ] **Step 3: Expand CycleStats struct**

Replace the `CycleStats` struct at `CycleService.swift:17-21` with:

```swift
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
```

- [ ] **Step 4: Update computeCycleStats to accept overrides**

Replace `computeCycleStats` at `CycleService.swift:66-95` with:

```swift
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
```

- [ ] **Step 5: Add bounds clamping to computePhaseRanges**

Replace `computePhaseRanges` at `CycleService.swift:97-112` with:

```swift
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
```

- [ ] **Step 6: Update computeCurrentPhase to extend luteal instead of wrapping**

In `computeCurrentPhase` at `CycleService.swift:114-160`, replace the cycle day wrapping logic (lines 122-128) with:

```swift
let ranges = computePhaseRanges(cycleLength: stats.effectiveCycleLength, periodLength: stats.effectivePeriodLength)
let rawCycleDay = getCycleDay(from: latest.periodStartDate)

// When overdue, stay in luteal — don't wrap
let cycleDay: Int
if rawCycleDay > stats.effectiveCycleLength {
    cycleDay = stats.effectiveCycleLength  // pin to last day (luteal)
} else {
    cycleDay = rawCycleDay
}
```

Also update the phase matching to use `stats.effectiveCycleLength` and `stats.effectivePeriodLength` where `stats.avgCycleLength` and `stats.avgPeriodLength` were used (the backward-compatible aliases make this work, but update for clarity).

- [ ] **Step 7: Update recalculate() to accept profile**

Replace `recalculate` at `CycleService.swift:54-62` with:

```swift
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
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `xcodebuild test -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:NamahWellnessTests/CycleServiceTests 2>&1 | tail -20`

Expected: All CycleServiceTests PASS

- [ ] **Step 9: Build the full project to catch compilation errors**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)" | tail -20`

Fix any compilation errors in callers that construct `CycleStats` directly (e.g., `APITypes.swift` `CycleBundleResponse`). The backward-compatible `avgCycleLength`/`avgPeriodLength` aliases should handle most callsites, but the `CycleStats` initializer changed. Search for all callsites:

Run: `grep -rn "CycleStats(" NamahWellness/ --include="*.swift"`

Update each callsite to use the new initializer. For `APITypes.swift` `CycleStatsDTO.toCycleStats()`, update to:

```swift
func toCycleStats() -> CycleStats {
    CycleStats(
        observedAvgCycleLength: avgCycleLength,
        observedAvgPeriodLength: avgPeriodLength,
        effectiveCycleLength: avgCycleLength,
        effectivePeriodLength: avgPeriodLength,
        userDefaultCycleLength: nil,
        userDefaultPeriodLength: nil,
        cycleCount: cycleCount,
        daysOverdue: 0,
        isOverdue: false
    )
}
```

Also update the default value in `CycleService` line 46:

```swift
private(set) var cycleStats: CycleStats = CycleStats(
    observedAvgCycleLength: 28, observedAvgPeriodLength: 5,
    effectiveCycleLength: 28, effectivePeriodLength: 5,
    userDefaultCycleLength: nil, userDefaultPeriodLength: nil,
    cycleCount: 0, daysOverdue: 0, isOverdue: false
)
```

- [ ] **Step 10: Commit**

```bash
git add NamahWellness/Services/CycleService.swift NamahWellnessTests/CycleServiceTests.swift NamahWellness/Services/APITypes.swift
git commit -m "feat(cycle): wire override into CycleService, expand CycleStats, add overdue detection"
```

---

## Task 2: Add UserProfile Fields and Wire ContentView

**Files:**
- Modify: `NamahWellness/Models/UserProfile.swift`
- Modify: `NamahWellness/App/ContentView.swift`

- [ ] **Step 1: Add new fields to UserProfile**

Add after `periodLengthOverride` at `UserProfile.swift:12`:

```swift
var overdueAckDate: String?
var isPregnant: Bool = false
var pregnancyStartDate: String?
```

Add to the `init` parameters and body accordingly (with defaults `nil`, `false`, `nil`).

- [ ] **Step 2: Wire profile into ContentView recalculate**

In `ContentView.swift`, add after line 12 (`@Query private var schedules`):

```swift
@Query private var profiles: [UserProfile]
```

Add a profile snapshot computed property (after `cycleLogSnapshot`):

```swift
private var profileSnapshot: String {
    guard let p = profiles.first else { return "" }
    return "\(p.cycleLengthOverride ?? 0)|\(p.periodLengthOverride ?? 0)|\(p.overdueAckDate ?? "")"
}
```

Add an onChange watcher (after the existing `onChange(of: cycleLogSnapshot)`):

```swift
.onChange(of: profileSnapshot) { recalculate() }
```

Update `recalculate()` to pass profile:

```swift
private func recalculate() {
    cycleService.recalculate(logs: cycleLogs, phases: phases, profile: profiles.first)
}
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Models/UserProfile.swift NamahWellness/App/ContentView.swift
git commit -m "feat(cycle): add profile fields, wire override into ContentView recalculate"
```

---

## Task 3: Update EditProfileView Bounds and CalendarService

**Files:**
- Modify: `NamahWellness/Views/Profile/EditProfileView.swift:28` (picker range)
- Modify: `NamahWellness/Services/CalendarService.swift:91,117,127-131,142-148,151`

- [ ] **Step 1: Tighten EditProfileView picker range to 20-40**

In `EditProfileView.swift`, change line 28:

```swift
// Old: ForEach(20...45, id: \.self)
ForEach(20...40, id: \.self) { day in
```

- [ ] **Step 2: Update CalendarService to use effectiveCycleLength**

In `CalendarService.swift`, the `stats.avgCycleLength` references now automatically use `effectiveCycleLength` via the backward-compatible alias. However, the wrapping logic at lines 142-148 needs to extend luteal instead of wrapping when overdue:

Replace lines 141-148:

```swift
// If past end of cycle, extend luteal instead of wrapping
if cycleDay > cycleLength {
    // Stay in luteal — show as extended cycle
    let ranges = CycleService.computePhaseRanges(cycleLength: cycleLength, periodLength: stats.avgPeriodLength)
    return DayPhaseInfo(
        phaseSlug: "luteal",
        cycleDay: cycleDay,
        dayInPhase: cycleDay - ranges.luteal.start + 1,
        isPeak: false,
        isProjected: isProjected
    )
}
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Views/Profile/EditProfileView.swift NamahWellness/Services/CalendarService.swift
git commit -m "feat(cycle): tighten picker bounds 20-40, extend luteal in calendar when overdue"
```

---

## Task 4: Update CycleLogManager — Overdue Guard on Auto-Log

**Files:**
- Modify: `NamahWellness/Services/CycleLogManager.swift:95-119`

- [ ] **Step 1: Add overdue guard to checkAndAutoLog**

Replace `checkAndAutoLog` at `CycleLogManager.swift:95-119`:

```swift
func checkAndAutoLog(stats: CycleStats) {
    // Don't auto-log when the user is overdue — they've acknowledged the period hasn't started
    guard !stats.isOverdue else { return }

    let logs = fetchLogs()
    let sorted = logs.sorted { $0.periodStartDate > $1.periodStartDate }
    guard let latest = sorted.first else { return }

    guard let lastStart = dateFormatter.date(from: latest.periodStartDate) else { return }
    let cal = Calendar.current
    guard let predictedDate = cal.date(byAdding: .day, value: stats.effectiveCycleLength, to: lastStart) else { return }

    let today = cal.startOfDay(for: Date())
    let predicted = cal.startOfDay(for: predictedDate)

    guard predicted <= today else { return }

    let predictedStr = dateFormatter.string(from: predicted)

    guard !logs.contains(where: { $0.periodStartDate == predictedStr }) else { return }
    guard findClosestLog(date: predicted, in: logs, thresholdDays: 15) == nil else { return }

    insertLog(dateStr: predictedStr)
}
```

Key changes: (1) early return when `stats.isOverdue`, (2) use `stats.effectiveCycleLength` instead of `stats.avgCycleLength`.

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Services/CycleLogManager.swift
git commit -m "fix(cycle): guard auto-log when overdue, use effectiveCycleLength"
```

---

## Task 5: Period Prompt Banner in TodayView

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift`

- [ ] **Step 1: Add overdue state properties**

Add after the existing `@State` properties (around line 38):

```swift
@AppStorage("lastOverdueDismissDate") private var lastOverdueDismissDate: String = ""
```

Add computed properties (after `hasCycleData` around line 53):

```swift
private var isOverdue: Bool {
    cycleService.cycleStats.isOverdue
}

private var daysOverdue: Int {
    cycleService.cycleStats.daysOverdue
}

private var daysSinceLastPeriod: Int {
    cycleService.currentPhase.map { $0.cycleDay } ?? 0
}

private var shouldShowPeriodPrompt: Bool {
    isOverdue && lastOverdueDismissDate != today
}
```

- [ ] **Step 2: Add PeriodPromptBanner view**

Add as a private method in TodayView (before or after the existing view builder methods):

```swift
@ViewBuilder
private var periodPromptBanner: some View {
    if shouldShowPeriodPrompt {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "drop.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Has your period started?")
                        .font(.nSubheadline)
                        .fontWeight(.semibold)
                    Text("Day \(daysSinceLastPeriod) · \(daysOverdue) day\(daysOverdue == 1 ? "" : "s") late")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    showLogPeriod = true
                } label: {
                    Text("Yes, log it")
                        .font(.nCaption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.phaseM)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    lastOverdueDismissDate = today
                    // Update profile overdueAckDate
                    if let profile = profiles.first {
                        profile.overdueAckDate = today
                        try? modelContext.save()
                    }
                } label: {
                    Text("Not yet")
                        .font(.nCaption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))

        if daysOverdue >= 14 {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(.pink)
                Text("Your period is significantly late. Consider consulting your healthcare provider.")
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.pink.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
```

- [ ] **Step 3: Insert banner into TodayView body**

In the TodayView body, insert the banner after the `PhaseHeroCard` / before the time block sections. Find the conditional that shows `logCycleCTA` vs `timeBlockSections` (around line 277-282) and add the banner inside the `if hasCycleData` branch, right at the top:

```swift
if hasCycleData {
    periodPromptBanner  // NEW — shows only when overdue
    timeBlockSections
} else {
    logCycleCTA
}
```

- [ ] **Step 4: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift
git commit -m "feat(today): add 'Has your period started?' banner when overdue"
```

---

## Task 6: Dual Stats Display in MyCycleView

**Files:**
- Modify: `NamahWellness/Views/MyCycle/MyCycleView.swift:146-158` (pill), `217-224` (stats)

- [ ] **Step 1: Update cycle info pill to show effective length**

Replace the pill label at `MyCycleView.swift:146`:

```swift
Label("\(cycleService.cycleStats.effectiveCycleLength) day cycle", systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90")
```

And line 148:

```swift
Label("\(cycleService.cycleStats.effectivePeriodLength) day period", systemImage: "drop.fill")
```

- [ ] **Step 2: Update stats section with dual display**

Replace the stats HStack at `MyCycleView.swift:217-224`:

```swift
HStack(spacing: 0) {
    statCard(
        value: "\(cycleService.cycleStats.effectiveCycleLength)",
        unit: "days",
        label: cycleService.cycleStats.userDefaultCycleLength != nil ? "YOUR CYCLE" : "AVG CYCLE"
    )
    if cycleService.cycleStats.userDefaultCycleLength != nil
        && cycleService.cycleStats.observedAvgCycleLength != cycleService.cycleStats.effectiveCycleLength {
        statCard(
            value: "\(cycleService.cycleStats.observedAvgCycleLength)",
            unit: "days",
            label: "OBSERVED"
        )
    }
    statCard(value: "\(cycleService.cycleStats.effectivePeriodLength)", unit: "days", label: "PERIOD")
    statCard(value: "\(cycleService.cycleStats.cycleCount)", unit: "", label: "CYCLES")
}
.background(Color(uiColor: .secondarySystemGroupedBackground))
.clipShape(RoundedRectangle(cornerRadius: 12))
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Views/MyCycle/MyCycleView.swift
git commit -m "feat(mycycle): dual stats display — user-set vs observed average"
```

---

## Task 7: Smart Notification Copy

**Files:**
- Modify: `NamahWellness/Services/NotificationService.swift:91-118`

- [ ] **Step 1: Update period prediction notification copy**

In `NotificationService.swift`, update the `schedulePeriodPrediction` method signature and body at lines 91-118. Change the content body to use the cycle length:

```swift
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
```

- [ ] **Step 2: Update callers of schedulePeriodPrediction**

Search for all callers:

Run: `grep -rn "schedulePeriodPrediction" NamahWellness/ --include="*.swift"`

Update each caller to pass `effectiveCycleLength:` instead of `avgCycleLength:`. The typical callsite in `ProfileView.swift` will look like:

```swift
await NotificationService.schedulePeriodPrediction(
    lastPeriodStart: lastLog.periodStartDate,
    effectiveCycleLength: cycleService.cycleStats.effectiveCycleLength
)
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Services/NotificationService.swift NamahWellness/Views/Profile/ProfileView.swift
git commit -m "feat(notif): smart period prediction copy with cycle length"
```

---

## Task 8: Calendar Recolor Animation

**Files:**
- Modify: `NamahWellness/App/ContentView.swift`

- [ ] **Step 1: Wrap recalculate in animation**

In `ContentView.swift`, update the `recalculate()` method:

```swift
private func recalculate() {
    withAnimation(.easeInOut(duration: 0.3)) {
        cycleService.recalculate(logs: cycleLogs, phases: phases, profile: profiles.first)
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)" | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/App/ContentView.swift
git commit -m "feat(calendar): animate phase recolor on cycle data changes"
```

---

## Task 9: Run Full Test Suite and Final Build

- [ ] **Step 1: Run all tests**

Run: `xcodebuild test -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(Test Case|PASS|FAIL|error:)" | tail -30`

Expected: All tests PASS including new CycleServiceTests

- [ ] **Step 2: Full clean build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Update CLAUDE.md architecture section**

Update the `CycleService` entry in the Key Services table in `CLAUDE.md` to mention the profile parameter:

```
| `CycleService` | @Observable class | Cycle state: current phase, cycle day, stats, phase ranges. Takes user profile for cycle/period length overrides. |
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md to reflect CycleService profile param"
```

---

## TODOs (Phase 2+)

These items were discussed during plan review and deferred:

1. **Pregnancy/Nursing Mode (P2, L)** — Full app mode that suspends cycle tracking. `isPregnant` flag added to UserProfile in this plan as hook point. Needs: dedicated content, UX, exit flow, timeline.

2. **Cycle Trend Insights (P3, S)** — One-line label in MyCycleView: "Your cycles are getting shorter/longer/stable" based on comparing last 3 cycle gaps.

3. **Cycle Range Stats (P3, S)** — Display "Shortest: 28d · Longest: 34d · Most common: 30d" in MyCycleView stats section.
