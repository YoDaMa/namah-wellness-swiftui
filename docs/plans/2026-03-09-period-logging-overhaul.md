# Period Logging Overhaul — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix duplicate period logging, add validation (no future dates, 15-day proximity correction), auto-predict period starts, consolidate duplicated code, clean up MyCycleView, and remove existing bad data.

**Architecture:** New `CycleLogManager` service owns all period logging logic (validation, insertion, sync, auto-prediction, data cleanup). It fetches logs internally via `FetchDescriptor` to avoid `@Query` staleness. Passed to views via `.environment()` (matching `SyncService`/`AuthService` pattern). A shared `LogPeriodSheet` component replaces 3 duplicated sheets. ContentView wires the manager and triggers auto-prediction on foreground.

**Tech Stack:** SwiftUI, SwiftData, @Observable pattern, existing SyncService/AuthService

---

### Task 1: Create `CycleLogManager` service

**Files:**
- Create: `NamahWellness/Services/CycleLogManager.swift`

**Step 1: Create the file with LogResult enum and CycleLogManager class**

```swift
import Foundation
import SwiftData

// MARK: - LogResult

enum LogResult {
    case success
    case correctionNeeded(existingDate: String, newDate: String)
    case duplicate
    case futureDate
}

// MARK: - CycleLogManager

@Observable
final class CycleLogManager {

    private(set) var pendingCorrection: (existingLog: CycleLog, newDate: String)?

    private let modelContext: ModelContext
    private let syncService: SyncService
    private let authService: AuthService

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    init(modelContext: ModelContext, syncService: SyncService, authService: AuthService) {
        self.modelContext = modelContext
        self.syncService = syncService
        self.authService = authService
    }

    // MARK: - Fetch logs (always fresh from modelContext)

    private func fetchLogs() -> [CycleLog] {
        (try? modelContext.fetch(FetchDescriptor<CycleLog>())) ?? []
    }

    // MARK: - Log Period (user-initiated)

    func logPeriod(date: Date) -> LogResult {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)

        // 1. Reject future dates
        if target > today {
            return .futureDate
        }

        let dateStr = dateFormatter.string(from: date)
        let logs = fetchLogs()

        // 2. Reject exact duplicates
        if logs.contains(where: { $0.periodStartDate == dateStr }) {
            return .duplicate
        }

        // 3. Check proximity (within 15 days of any existing entry)
        if let nearby = findClosestLog(date: target, in: logs, thresholdDays: 15) {
            pendingCorrection = (existingLog: nearby, newDate: dateStr)
            return .correctionNeeded(existingDate: nearby.periodStartDate, newDate: dateStr)
        }

        // 4. Insert
        insertLog(dateStr: dateStr)
        return .success
    }

    // MARK: - Confirm Correction

    func confirmCorrection() {
        guard let correction = pendingCorrection else { return }
        let oldLog = correction.existingLog
        let newDate = correction.newDate

        // Update existing log's date
        oldLog.periodStartDate = newDate
        syncService.queueChange(table: "cycleLogs", action: "upsert",
                                data: ["id": oldLog.id, "periodStartDate": newDate],
                                modelContext: modelContext)
        try? modelContext.save()
        pendingCorrection = nil
    }

    func cancelCorrection() {
        pendingCorrection = nil
    }

    // MARK: - Auto-log (system-initiated, silent)

    func checkAndAutoLog(stats: CycleStats) {
        let logs = fetchLogs()
        let sorted = logs.sorted { $0.periodStartDate > $1.periodStartDate }
        guard let latest = sorted.first else { return }

        guard let lastStart = dateFormatter.date(from: latest.periodStartDate) else { return }
        let cal = Calendar.current
        guard let predictedDate = cal.date(byAdding: .day, value: stats.avgCycleLength, to: lastStart) else { return }

        let today = cal.startOfDay(for: Date())
        let predicted = cal.startOfDay(for: predictedDate)

        // Only auto-log if predicted date <= today
        guard predicted <= today else { return }

        let predictedStr = dateFormatter.string(from: predicted)

        // Don't insert if one already exists for that date
        guard !logs.contains(where: { $0.periodStartDate == predictedStr }) else { return }

        // Don't insert if within 15 days of another entry
        guard findClosestLog(date: predicted, in: logs, thresholdDays: 15) == nil else { return }

        insertLog(dateStr: predictedStr)
    }

    // MARK: - Cleanup (one-time, removes existing bad data)

    func cleanupDuplicates() {
        let logs = fetchLogs()
        guard logs.count > 1 else { return }

        // Group by periodStartDate, keep oldest (by createdAt) for each date
        let grouped = Dictionary(grouping: logs, by: \.periodStartDate)
        var toDelete: [CycleLog] = []

        for (_, group) in grouped where group.count > 1 {
            let sorted = group.sorted { $0.createdAt < $1.createdAt }
            toDelete.append(contentsOf: sorted.dropFirst())
        }

        // Remove entries too close together (within 15 days), keep oldest
        let remaining = logs.filter { !toDelete.contains(where: { $0.id == $1.id }) }
            .sorted { $0.periodStartDate < $1.periodStartDate }
        var i = 0
        while i < remaining.count - 1 {
            guard let d1 = dateFormatter.date(from: remaining[i].periodStartDate),
                  let d2 = dateFormatter.date(from: remaining[i + 1].periodStartDate) else {
                i += 1
                continue
            }
            let diff = Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0
            if diff > 0 && diff <= 15 {
                // Keep the earlier one, mark later for deletion
                if !toDelete.contains(where: { $0.id == remaining[i + 1].id }) {
                    toDelete.append(remaining[i + 1])
                }
            }
            i += 1
        }

        for log in toDelete {
            syncService.queueChange(table: "cycleLogs", action: "delete",
                                    data: ["id": log.id], modelContext: modelContext)
            modelContext.delete(log)
        }

        if !toDelete.isEmpty {
            try? modelContext.save()
        }
    }

    // MARK: - Private

    private func insertLog(dateStr: String) {
        let log = CycleLog(userId: authService.userId ?? "", periodStartDate: dateStr)
        modelContext.insert(log)
        syncService.queueChange(table: "cycleLogs", action: "upsert",
                                data: ["id": log.id, "periodStartDate": dateStr],
                                modelContext: modelContext)
        try? modelContext.save()
    }

    private func findClosestLog(date: Date, in logs: [CycleLog], thresholdDays: Int) -> CycleLog? {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        var closest: (log: CycleLog, diff: Int)?

        for log in logs {
            guard let logDate = dateFormatter.date(from: log.periodStartDate) else { continue }
            let logDay = cal.startOfDay(for: logDate)
            let diff = abs(cal.dateComponents([.day], from: logDay, to: target).day ?? 0)
            if diff > 0 && diff <= thresholdDays {
                if closest == nil || diff < closest!.diff {
                    closest = (log, diff)
                }
            }
        }

        return closest?.log
    }
}
```

**Step 2: Verify build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Services/CycleLogManager.swift
git commit -m "feat: add CycleLogManager with validation, auto-prediction, and cleanup"
```

---

### Task 2: Create shared `LogPeriodSheet` component

**Files:**
- Create: `NamahWellness/Views/Components/LogPeriodSheet.swift`

**Step 1: Create the shared sheet view**

Note: `LogPeriodSheet` no longer needs a `cycleLogs` parameter — `CycleLogManager` fetches internally.

```swift
import SwiftUI
import SwiftData

struct LogPeriodSheet: View {
    let cycleLogManager: CycleLogManager
    @Binding var isPresented: Bool

    @State private var selectedDate = Date()
    @State private var showCorrectionAlert = false
    @State private var correctionExistingDate = ""
    @State private var correctionNewDate = ""

    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.display(20, relativeTo: .title3))

                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)

                Button {
                    handleLog()
                } label: {
                    Text("Log Period Start")
                        .font(.nHeadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
            }
            .padding()
            .navigationTitle("Log Period Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .alert("Update Period Start?", isPresented: $showCorrectionAlert) {
                Button("Update") {
                    cycleLogManager.confirmCorrection()
                    isPresented = false
                }
                Button("Cancel", role: .cancel) {
                    cycleLogManager.cancelCorrection()
                }
            } message: {
                Text("Update your period start from \(correctionExistingDate) to \(correctionNewDate)?")
            }
        }
        .presentationDetents([.large])
    }

    private func handleLog() {
        let result = cycleLogManager.logPeriod(date: selectedDate)
        switch result {
        case .success, .duplicate, .futureDate:
            isPresented = false
        case .correctionNeeded(let existing, let new):
            correctionExistingDate = formatForDisplay(existing)
            correctionNewDate = formatForDisplay(new)
            showCorrectionAlert = true
        }
    }

    private func formatForDisplay(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        guard let date = f.date(from: dateStr) else { return dateStr }
        return displayFormatter.string(from: date)
    }
}
```

**Step 2: Verify build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Components/LogPeriodSheet.swift
git commit -m "feat: add shared LogPeriodSheet component with correction alert"
```

---

### Task 3: Wire `CycleLogManager` into `ContentView` via environment

**Files:**
- Modify: `NamahWellness/App/ContentView.swift`

**Step 1: Add CycleLogManager state, pass via .environment(), add auto-prediction and cleanup**

Replace the full ContentView:

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    let authService: AuthService
    let syncService: SyncService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var cycleLogs: [CycleLog]
    @Query private var phases: [Phase]

    @State private var cycleService = CycleService()
    @State private var cycleLogManager: CycleLogManager?
    @State private var selectedTab = 0
    @State private var hasInitialSync = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabView(selection: $selectedTab) {
                    TodayView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "sun.max")
                            Text("Today")
                        }
                        .tag(0)

                    MyCycleView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "circle.dotted.circle")
                            Text("My Cycle")
                        }
                        .tag(1)

                    PlanView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "list.bullet.rectangle")
                            Text("Plan")
                        }
                        .tag(2)

                    LearnView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "book")
                            Text("Learn")
                        }
                        .tag(3)
                }
                .environment(syncService)
                .environment(authService)
                .environment(cycleLogManager)
                .onAppear {
                    syncService.configure(modelContext: modelContext)
                    if cycleLogManager == nil {
                        let manager = CycleLogManager(
                            modelContext: modelContext,
                            syncService: syncService,
                            authService: authService
                        )
                        manager.cleanupDuplicates()
                        cycleLogManager = manager
                    }
                    recalculate()
                    if !hasInitialSync {
                        hasInitialSync = true
                        Task { await syncService.sync(); recalculate() }
                    }
                }
                .onChange(of: cycleLogSnapshot) { recalculate() }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        cycleLogManager?.checkAndAutoLog(
                            stats: cycleService.cycleStats
                        )
                        Task { await syncService.sync(); recalculate() }
                    }
                }
            } else {
                LoginView(authService: authService)
            }
        }
    }

    private var cycleLogSnapshot: [String] {
        cycleLogs.map { "\($0.id)|\($0.periodStartDate)|\($0.periodEndDate ?? "")|\($0.phaseOverride ?? "")" }
    }

    private func recalculate() {
        cycleService.recalculate(logs: cycleLogs, phases: phases)
    }
}
```

Key changes from original:
- Added `@State private var cycleLogManager: CycleLogManager?`
- Added `.environment(cycleLogManager)` — passes optional `CycleLogManager?` to all child views
- On appear: creates manager and runs `cleanupDuplicates()` once
- On foreground: calls `checkAndAutoLog(stats:)` (no `logs` param — fetches internally)
- `TodayView` and `MyCycleView` init signatures unchanged here (they read from environment)

**Important:** `.environment(cycleLogManager)` passes an optional. Child views access it via `@Environment(CycleLogManager.self) private var cycleLogManager: CycleLogManager?` — this is the standard pattern for optional environment objects in iOS 17+.

**Step 2: Verify build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (TodayView/MyCycleView signatures unchanged)

**Step 3: Commit**

```bash
git add NamahWellness/App/ContentView.swift
git commit -m "feat: wire CycleLogManager via environment with cleanup and auto-prediction"
```

---

### Task 4: Update `TodayView` to use shared components

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift`

**Step 1: Replace inline period logging with shared components**

Changes:
1. Add environment: `@Environment(CycleLogManager.self) private var cycleLogManager: CycleLogManager?`
2. Remove: `@State private var newPeriodDate = Date()` (keep `@State private var showLogPeriod = false`)
3. Remove: the entire `private var logPeriodSheet` computed property (lines 625-654)
4. Remove: the entire `private func logPeriod()` function (lines 656-668)
5. Replace `.sheet(isPresented: $showLogPeriod)` content (line 131-133) with:

```swift
.sheet(isPresented: $showLogPeriod) {
    if let manager = cycleLogManager {
        LogPeriodSheet(
            cycleLogManager: manager,
            isPresented: $showLogPeriod
        )
    }
}
```

6. Keep the `logCycleCTA` button that sets `showLogPeriod = true` — it already works.

**Step 2: Verify build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift
git commit -m "refactor: use shared LogPeriodSheet in TodayView via environment"
```

---

### Task 5: Update `ProfileView` to use shared components

**Files:**
- Modify: `NamahWellness/Views/Profile/ProfileView.swift`

**Step 1: Replace inline period logging with shared components**

Changes:
1. Add environment: `@Environment(CycleLogManager.self) private var cycleLogManager: CycleLogManager?`
2. Remove: `@State private var newPeriodDate = Date()` (keep `@State private var showLogSheet = false`)
3. Remove: the entire `private var logPeriodSheet` computed property (lines 524-553)
4. Remove: the entire `private func logPeriod()` function (lines 555-570)
5. Replace `.sheet(isPresented: $showLogSheet)` content (line 78-80) with:

```swift
.sheet(isPresented: $showLogSheet) {
    if let manager = cycleLogManager {
        LogPeriodSheet(
            cycleLogManager: manager,
            isPresented: $showLogSheet
        )
    }
}
```

No changes needed to callers — `ProfileView` no longer needs `cycleLogManager` as a parameter since it reads from environment.

**Step 2: Verify build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Profile/ProfileView.swift
git commit -m "refactor: use shared LogPeriodSheet in ProfileView via environment"
```

---

### Task 6: Clean up `MyCycleView`

**Files:**
- Modify: `NamahWellness/Views/MyCycle/MyCycleView.swift`

**Step 1: Remove log period and override phase functionality**

Remove these state properties:
- `@State private var showLogSheet = false`
- `@State private var newPeriodDate = Date()`
- `@State private var showOverrideSheet = false`
- `@State private var showNoCycleAlert = false`

Remove these views/functions:
- The "Log Period Start" + "Override Phase" button `VStack` (section 7, around lines 112-146)
- `private var logPeriodSheet` computed property (lines 550-579)
- `private var overrideSheet` computed property (lines 583-623)
- `private func logPeriod()` (lines 665-680)
- `private func setOverride(_ slug:)` (lines 682-694)
- `private func clearOverride()` (lines 696-702)

Remove these sheet/alert modifiers:
- `.sheet(isPresented: $showLogSheet) { logPeriodSheet }`
- `.sheet(isPresented: $showOverrideSheet) { overrideSheet }`
- `.alert("No Period Logged", isPresented: $showNoCycleAlert) { ... }`

Keep: calendar, stats, period history, hormones link, edit end date sheet, delete confirmation alert, `deleteLogs()`.

**Step 2: Verify build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/MyCycle/MyCycleView.swift
git commit -m "refactor: remove log period and override phase from MyCycleView"
```

---

### Task 7: Verify full build and manual test

**Step 1: Clean build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' clean build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 2: Manual verification checklist**

Open in Xcode and test on simulator:
- [ ] TodayView: "Log Period Start" CTA appears when no cycle data
- [ ] TodayView: logging a period updates the view immediately
- [ ] TodayView: future dates are not selectable in the date picker
- [ ] TodayView: logging a date within 15 days of existing shows correction alert with closest date
- [ ] TodayView: confirming correction updates the existing entry (not creates a new one)
- [ ] ProfileView: "Log Period Start" button opens sheet, same validation works
- [ ] ProfileView: cycle log list shows clean data (no duplicates after cleanup)
- [ ] MyCycleView: no "Log Period Start" or "Override Phase" buttons
- [ ] MyCycleView: calendar, stats, history still work
- [ ] App foreground: auto-prediction runs silently (test by setting up a cycle that's overdue)
- [ ] Existing duplicate data cleaned up on first launch after update
