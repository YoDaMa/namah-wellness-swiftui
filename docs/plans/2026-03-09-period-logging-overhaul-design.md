# Period Logging Overhaul — Design

## Problem

1. **Duplicate entries**: `modelContext.insert()` without explicit `.save()` means `@Query` doesn't reflect new entries immediately. Rapid taps bypass the duplicate check.
2. **No proximity validation**: Nothing prevents entries within 15 days of each other.
3. **No future date prevention**: Users can log period starts in the future.
4. **TodayView doesn't update**: `CycleService.recalculate()` depends on `@Query` refresh timing after insert.
5. **Code duplication**: `logPeriod()` and the log period sheet are copy-pasted across TodayView, MyCycleView, and ProfileView.
6. **MyCycleView clutter**: "Override Phase" button is confusing; "Log Period Start" is redundant.

## Design

### New: `CycleLogManager` (@Observable class)

Single source of truth for all period logging logic.

**API:**
- `logPeriod(date: Date) -> LogResult` — validates and inserts
- `confirmCorrection()` — replaces nearby entry after user confirms
- `autoLog(date: Date)` — silent insert for auto-prediction (skips confirmation flow)
- `checkAndAutoLog(logs: [CycleLog], stats: CycleStats)` — client-side prediction fallback

**LogResult enum:**
- `.success` — inserted and saved
- `.correctionNeeded(existingDate: String, newDate: String)` — within 15 days, needs confirmation
- `.duplicate` — exact same date exists, silently ignored
- `.futureDate` — rejected

**Validation rules (in order):**
1. Reject if date is after today
2. Reject if exact date match exists
3. If within 15 days of an existing entry → return `.correctionNeeded`
4. Otherwise → insert, explicitly call `modelContext.save()`, queue sync

### New: `LogPeriodSheet` (shared view)

Location: `Views/Components/LogPeriodSheet.swift`

- DatePicker with `...Date()` range (prevents future dates at picker level)
- On submit → calls `manager.logPeriod(date:)`
- Handles `.correctionNeeded` → shows alert: "Update period start from X to Y?" with Confirm/Cancel
- Handles `.success` / `.duplicate` → dismisses

Used by TodayView and ProfileView.

### Edit: ContentView

- Creates `CycleLogManager` as `@State`, passes to child views
- On foreground (`onChange(of: scenePhase)`): calls `manager.checkAndAutoLog()` as prediction fallback

### Edit: TodayView

- Replace inline `logPeriod()` + sheet with `LogPeriodSheet` + `CycleLogManager`
- Remove: `showLogPeriod`, `newPeriodDate`, `logPeriod()`, `logPeriodSheet`

### Edit: ProfileView

- Replace inline `logPeriod()` + sheet with `LogPeriodSheet` + `CycleLogManager`
- Remove: `showLogSheet`, `newPeriodDate`, `logPeriod()`, `logPeriodSheet`

### Edit: MyCycleView

Remove:
- "Log Period Start" button + sheet + `logPeriod()` function
- "Override Phase" button + sheet + `setOverride()` / `clearOverride()` functions
- State: `showLogSheet`, `newPeriodDate`, `showOverrideSheet`, `showNoCycleAlert`

Keep: calendar, stats, period history, hormones link, edit end date, delete log.

### Client-side auto-prediction (fallback)

On app foreground:
1. Get most recent CycleLog
2. Compute `predictedNextStart = lastStart + avgCycleLength`
3. If `predictedNextStart <= today` and no CycleLog exists for that date → `autoLog(predictedNextStart)`

### Backend cron (follow-up, separate repo)

Daily scheduled task in `namah-nutrition-page`:
1. Query each user's most recent CycleLog + avg cycle length
2. If predicted date = today → insert CycleLog row
3. Same proximity validation (no entry within 15 days)

Sequencing: client-side first, backend cron as follow-up.

## Files Changed

| File | Action |
|------|--------|
| `Services/CycleLogManager.swift` | Create |
| `Views/Components/LogPeriodSheet.swift` | Create |
| `ContentView.swift` | Edit |
| `TodayView.swift` | Edit |
| `ProfileView.swift` | Edit |
| `MyCycleView.swift` | Edit |
