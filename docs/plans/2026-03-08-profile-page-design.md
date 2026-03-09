# Profile Page Design

## Overview

Replace the minimal AccountSettingsView with a full Profile page. Settings at top, then rich historical data: cycle log, symptom patterns, adherence streaks.

## New Data Model

```swift
@Model
final class UserProfile {
    @Attribute(.unique) var id: String
    var name: String
    var dailyReminderEnabled: Bool
    var dailyReminderTime: Date
    var periodReminderEnabled: Bool

    init(id: String = "default", name: String = "",
         dailyReminderEnabled: Bool = false,
         dailyReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20)) ?? Date(),
         periodReminderEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderTime = dailyReminderTime
        self.periodReminderEnabled = periodReminderEnabled
    }
}
```

Singleton pattern — always `id: "default"`. Avatar derived from name initials. Cycle length is computed from CycleService (not user-editable).

## Page Sections (top to bottom)

### 1. Settings Header

- Phase-colored initials circle (~80pt), colored via `NamahTheme.color(for: currentPhase)`
- Editable name TextField, persisted to UserProfile
- Read-only cycle length from `cycleService.cycleStats.avgCycleLength`
- Read-only period length from `cycleService.cycleStats.avgPeriodLength`
- Prominent "Log Period Start" button — opens DatePicker sheet (same behavior as MyCycleView)

### 2. Notifications

- **Daily Digest** — Toggle + DatePicker (time only, `.hourAndMinute`). Schedules a daily local notification via `UNUserNotificationCenter` to remind user to log symptoms/meals.
- **Period Prediction** — Toggle. Schedules a notification X days before predicted period start based on `avgCycleLength` from last CycleLog. Recalculated when a new CycleLog is added.
- Request notification permission on first toggle-on via `UNUserNotificationCenter.requestAuthorization`.

### 3. Cycle Log (History)

- Query all `CycleLog` entries, sorted by `periodStartDate` descending.
- Each card shows:
  - Formatted start date ("Feb 8, 2026")
  - Cycle length (days between this start and next start)
  - Delta vs average: e.g., "+2" (red-ish), "-1" (green-ish), "avg" (gray)
  - Period end date if available
- Empty state: "Log your first period to start tracking."

### 4. Symptom Patterns

- Query all `SymptomLog` entries.
- For each symptom field (mood, energy, cramps, bloating, fatigue, acne, headache, breastTenderness, sleepQuality, anxiety, irritability, libido, appetite):
  - Compute the average intensity per cycle day across all logged cycles
  - Find the cycle day range where average intensity is highest (>= 2.5)
  - Map that day range to a phase name
- Surface the top 4 insights as text cards, e.g.:
  - "Fatigue peaks on days 24–27 (luteal)"
  - "Bloating is most common in your luteal phase"
  - "Your mood is highest during days 8–12 (follicular)"
- Empty state (< 14 symptom logs): "Log symptoms daily to unlock patterns"

### 5. Meal & Workout Streaks

Three rows, each showing:
- Label (Meals / Workouts / Supplements)
- "X of 7" text
- 7-dot indicator: one dot per day of the last 7 days, filled if at least one completion exists for that day

Data sources:
- Meals: `MealCompletion` grouped by date
- Workouts: `WorkoutCompletion` grouped by date
- Supplements: `SupplementLog` (where `taken == true`) grouped by date

No gamification. Just honest dots.

## Navigation

Profile is accessed from the gear menu on all tabs (existing pattern). It pushes onto the NavigationStack via `.navigationDestination`.

## Notification Service

Create a `NotificationService` (stateless enum) with:
- `scheduleDailyReminder(at time: Date)` — repeating daily notification
- `cancelDailyReminder()`
- `schedulePeriodPrediction(lastPeriod: String, avgCycleLength: Int)` — one-shot notification 3 days before predicted start
- `cancelPeriodPrediction()`
- `requestPermissionIfNeeded()` — requests authorization, returns Bool

All use `UNUserNotificationCenter` with unique identifiers for easy cancellation.

## Files to Create/Modify

**Create:**
- `NamahWellness/Models/UserProfile.swift` — new SwiftData model
- `NamahWellness/Services/NotificationService.swift` — local notification scheduling
- `NamahWellness/Views/Profile/ProfileView.swift` — the new profile page

**Modify:**
- `NamahWellness/App/NamahWellnessApp.swift` — add UserProfile to ModelContainer schema
- `NamahWellness/App/ContentView.swift` — seed default UserProfile if needed
- `NamahWellness/Views/MyCycle/AccountSettingsView.swift` — delete (replaced by ProfileView)
- All views referencing `AccountSettingsView()` — point to `ProfileView()`
