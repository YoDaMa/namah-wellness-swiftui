# Unified Habit Tracking System — Design Spec

## Goal

Transform the app from a passive reference guide into an active personal planning system. Users commit to a plan (meals, workouts, supplements, habits), track completion daily, and see unified progress. The system feels like ONE thing, not four separate features.

## Architecture

**Backend**: Separate structured models for meals (ingredients, macros, SA notes) and workouts (sessions, exercises, focus). Supplements/medications enhanced on the existing `userSupplements` table. The existing `UserPlanItem` model is **renamed to `Habit`** — it already has all required fields (title, duration, recurrence, phaseSlug) and supports categories for custom meals, custom workouts, groceries, and now generic habits. All related types are renamed accordingly.

**Frontend**: `PlanAggregatorService` is a **computation engine** (like `CycleService`) — it receives pre-fetched data and returns unified plan items. Views still hold `@Query` properties but delegate all logic to the service. This follows the established pattern where `CycleService` receives `cycleLogs` and computes phase info.

**Pattern**: Copy-on-write for defaults — template meals/workouts are immutable. "Editing" a default creates a custom `Habit` record and hides the original via `UserItemHidden`. "Reset to Default" reverses both.

### Rename Summary

| Old Name | New Name | Scope |
|----------|----------|-------|
| `UserPlanItem` | `Habit` | iOS @Model class |
| `PlanItemLog` | `HabitLog` | iOS @Model class |
| `PlanItemCategory` | `HabitCategory` | Swift enum |
| `PlanItemRecurrence` | `HabitRecurrence` | Swift enum |
| `AddPlanItemSheet` | `AddHabitSheet` | SwiftUI view |
| `userPlanItems` | `habits` | Backend table + sync tableMap key |
| `planItemLogs` | `habitLogs` | Backend table + sync tableMap key |

**Backend migration**: Rename tables via Drizzle schema. Since the iOS app sends table names in `SyncChange` payloads (e.g., the old name `"userPlanItems"`), the backend sync endpoint must accept BOTH old and new table names during a transition period. Recommended: backend `tableMap` includes aliases that map `"userPlanItems"` → `habits` table and `"planItemLogs"` → `habitLogs` table.

```
BACKEND (structured per type)              FRONTEND (unified experience)
──────────────────────────                 ──────────────────────────────
┌─────────────────────┐
│ Meal (seed data)    │─→ MealCompletion     ┌──────────────────────────┐
│ ingredients, recipe │                      │                          │
│ macros, SA notes    │                      │   PlanAggregatorService  │
├─────────────────────┤                      │   (@Observable)          │
│ Workout (seed data) │─→ WorkoutCompletion  │   (computation engine)   │
│ sessions, exercises │                      │                          │
│ sets, links, focus  │                      │   Receives: model arrays │
├─────────────────────┤                      │   Returns: unified items │
│ UserSupplement      │─→ SupplementLog      │                          │
│ + medications       │                      │   ├─ itemsForDate()      │
├─────────────────────┤                      │   ├─ completionRate()    │
│ Habit        │─→ HabitLog        │   ├─ currentStreak       │
│ (.habit category)   │   (EXISTING, wire up)│   └─ isCompleted()       │
│ (.meal custom)      │                      │                          │
│ (.workout custom)   │                      └──────────┬───────────────┘
└─────────────────────┘                                 │
                                              ┌─────────┴─────────┐
                                              ▼                   ▼
                                         TodayView           PlanView
                                         (timeline)      (NOURISH/MOVE/
                                                          SUPPS/HABITS)
```

### Existing infrastructure reused (renamed)

| Old Name | New Name | Status | Role in new system |
|----------|----------|--------|-------------------|
| `UserPlanItem` | `Habit` | Existing, rename | All custom items + generic habits with category `.habit` + reminder fields |
| `PlanItemLog` | `HabitLog` | Existing, unused, rename | Wire up for all custom item completions |
| `UserItemHidden` | `UserItemHidden` | Existing, no rename | Copy-on-write: hides defaults when user edits |
| `NotificationService` | `NotificationService` | Existing | Extend with per-item reminder scheduling |
| `PlanResolver` | (absorbed) | Existing | Absorb into PlanAggregatorService |
| `AddPlanItemSheet` | `AddHabitSheet` | Existing, rename | Add `.habit` and `.medication` categories |

---

## 1. PlanAggregatorService

**Purpose**: Computation engine that unifies all plan item types into a single interface. Does NOT own data fetching — receives model arrays from views with `@Query`, computes unified results.

**Pattern**: `@Observable` class following the `CycleService` pattern. Views call a `recalculate()` method passing in their `@Query` results. The service computes and stores unified plan items.

**Interface**:

```
PlanAggregatorService (@Observable)

  // Recalculate method — called by views when @Query data changes
  recalculate(
    meals: [Meal],
    workouts: [Workout],
    workoutSessions: [WorkoutSession],
    supplements: [UserSupplement],
    customItems: [Habit],
    hiddenItems: [UserItemHidden],
    mealCompletions: [MealCompletion],
    workoutCompletions: [WorkoutCompletion],
    supplementLogs: [SupplementLog],
    habitLogs: [HabitLog]
  )

  // Computed results
  mealsForDate(date, phaseSlug, dayInPhase) → [UnifiedPlanItem]
  workoutForDate(date) → [UnifiedPlanItem]
  supplementsForDate(date) → [UnifiedPlanItem]
  habitsForDate(date) → [UnifiedPlanItem]
  allItemsForDate(date, phaseSlug, dayInPhase) → [UnifiedPlanItem]
  completionRate(date) → Double        // 0.0–1.0
  currentStreak() → Int                // Consecutive days with any activity
  isCompleted(itemId, itemType, date) → Bool
```

**UnifiedPlanItem struct** (value type, not protocol — avoids the `isCompleted` coupling problem):

```swift
struct UnifiedPlanItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let time: String?               // "7:00am"
    let category: HabitCategory  // .meal, .workout, .supplement, .medication, .habit, .grocery
    let isCustom: Bool              // true for Habit, false for seed data
    let sourceId: String            // Original model's ID (for completion toggling)
    let sourceType: String          // "meal", "workout", "supplement", "habit"
}
```

**Data flow**:
```
ContentView
  ├── @Query meals, workouts, sessions, supplements, customItems, ...
  ├── .onChange(of: querySnapshots) { planAggregator.recalculate(...) }
  └── .environment(planAggregator)
        │
        ├── TodayView
        │     reads: planAggregator.allItemsForDate(today, ...)
        │     groups by time block, renders cards
        │
        └── PlanView
              reads: planAggregator.mealsForDate/workoutForDate/etc.
              renders sub-tabs
```

**PlanResolver absorption**: The existing `PlanResolver` (stateless enum that resolves template items + custom items - hidden items) is absorbed into PlanAggregatorService. Its logic becomes internal methods.

**File**: `NamahWellness/Services/PlanAggregatorService.swift`

---

## 2. Habits via Habit

**Purpose**: Generic habits (meditation, journaling, mindfulness) are `Habit` records with category `.habit`. No new backend table needed — Habit already has title, duration, recurrence, recurrenceDays, specificDate, phaseSlug, isActive.

**New fields on Habit** (backend + iOS):

| Field | Type | Notes |
|-------|------|-------|
| `reminderEnabled` | boolean | default false |
| `reminderTime` | text | "7:00am" — specific time for notification |

**New HabitCategory cases**:
- `.habit` — meditation, journaling, mindfulness, etc.
- `.medication` — medications (created via supplement flow, see Section 3)

**Completion tracking**: Wire up the existing `HabitLog` model. It already exists in backend schema, sync endpoint, and iOS models — just unused. HabitLog tracks completion of any Habit by `habitId` + `date`.

**Backend schema change**: Add `reminderEnabled` (boolean, default false) and `reminderTime` (text, nullable) columns to `habits` table. Also add `replacesItemId` (text, nullable) for copy-on-write tracking. All additive, no breaking changes.

---

## 3. Medications & Supplements Enhancement

**Purpose**: Extend the existing supplement system to handle medications. Users can create generic entries ("Morning Meds") without specifying a supplement definition, and set per-item push notification reminders.

**Schema changes to `userSupplements`**:

| New Column | Type | Notes |
|------------|------|-------|
| category | text NOT NULL | "supplement" (default) or "medication" |
| title | text | Custom display name (for generic entries without supplementId) |
| reminderEnabled | boolean NOT NULL | default false |
| reminderTime | text | "8:00am" — specific time for notification |

**Behavior changes**:
- `supplementId` becomes optional (nullable) — generic medications don't need a SupplementDefinition
- When `supplementId` is nil, `title` is required (display name)
- When `supplementId` is set, title falls back to `SupplementDefinition.name`

**Migration impact**:
- **Backend**: `supplementId` has `.notNull().references(() => supplementDefinitions.id)`. Making it nullable requires dropping the NOT NULL constraint. Drizzle `db:push` handles this for SQLite. Existing rows all have `supplementId` set, so no data issue.
- **iOS**: Changing `supplementId` from `String` to `String?` on the SwiftData `@Model` triggers a schema migration. The app's existing migration-failure handler (`NamahWellnessApp.swift`) resets the database and re-syncs, so users will not lose data — but will see a brief reload on first launch after update. This is acceptable.

**UI changes**:
- SUPPLEMENTS sub-tab in PlanView renamed to "SUPPS & MEDS"
- "Add Medication" option alongside "Add Supplement"
- Medication entries show pill icon; supplements show capsule icon
- Each item shows a reminder toggle with time picker

---

## 4. Per-Item Push Notifications

**Purpose**: Any habit, medication, or supplement with `reminderEnabled = true` gets a push notification at its scheduled time.

**Implementation**: Extend the existing `NotificationService` (not a new utility) — it already has quiet hours handling, category registration, and action handling in AppDelegate.

**New methods on NotificationService**:

```swift
func scheduleItemReminder(identifier: String, title: String, time: String,
                          recurrence: HabitRecurrence, recurrenceDays: String?)
func cancelItemReminder(identifier: String)
func rescheduleAllItemReminders(habits: [Habit], supplements: [UserSupplement])
```

**Notification identifiers**: `"habit-{id}"`, `"supplement-{id}"`

**Trigger**: `UNCalendarNotificationTrigger` with repeating flag:
- `daily` → repeats every day at reminderTime
- `weekdays` → 5 separate triggers (Mon-Fri)
- `specificDays` → one trigger per specified day
- `once` → single non-repeating trigger

**Lifecycle**:
- On item create/edit: schedule or reschedule
- On item delete or `isActive = false`: cancel
- On toggle `reminderEnabled`: schedule or cancel
- On app launch: `rescheduleAllItemReminders()` to sync with current state

**Content**: `"Time for {item.title}"` — uses the existing notification category for habit reminders.

**Notification scheduling uses local SwiftData** — not dependent on network/sync state.

---

## 5. Workout Planner Enhancement

**Purpose**: Make the MOVE sub-tab an interactive weekly workout planner with copy-on-write editing.

**Copy-on-write "Edit" flow**:
1. User long-presses default workout session → context menu includes "Edit"
2. Opens AddHabitSheet pre-filled with session data (title, time, focus, duration)
3. On save: creates `Habit` (workout, `replacesItemId` = session ID) + creates `UserItemHidden` (itemId = session ID)
4. Both in one `modelContext.save()` (atomic)

**"Reset to Default" flow**:
1. Custom items with `replacesItemId` set show "Reset to Default" in context menu
2. Deletes the `Habit` + deletes the matching `UserItemHidden`
3. Original default reappears

**Completion inline**:
- Each workout card shows a completion checkbox
- Tapping toggles `WorkoutCompletion` for that date (day-level completion, matching existing model)
- Custom workout items use `HabitLog` for completion

---

## 6. Meal Planner Enhancement

**Purpose**: Phase-based meal planner with up to 7 days of meals per phase, copy-on-write editing.

**Phase-based with up to 7 days**:
- Current seed data has 3-5 days per phase
- Users can add custom meals for days 1-7
- Day navigator expands to show all days with content
- Empty days show "Add meals for Day N" prompt

**Copy-on-write**: Same pattern as workouts — long-press → Edit → AddHabitSheet pre-filled → save creates custom + hides original. `replacesItemId` links back.

**Completion inline**: Each meal card shows checkbox. Default meals use `MealCompletion`. Custom meals use `HabitLog`.

---

## 7. Plan Tab — HABITS Sub-Tab (NEW)

**Purpose**: 4th sub-tab in PlanView for managing generic habits.

**Layout**: List of user's habits (Habits with category `.habit`) grouped by time of day (Morning / Afternoon / Evening / Anytime).

**Each habit card shows**:
- Title, duration (if set), recurrence summary ("Daily" / "Mon, Wed, Fri")
- Reminder toggle with time
- Today's completion state (checkbox)
- Context menu: Edit, Delete

**Add button**: "Add Habit" opens AddHabitSheet with `.habit` category pre-selected.

---

## 8. Today Timeline Integration

**Purpose**: All habit types appear in TodayView's time-block timeline.

**Changes**:
- TodayView consumes `PlanAggregatorService` for computing what to display
- Calls `allItemsForDate(today, currentPhase, dayInPhase)` for unified list
- Items grouped by time block (Morning / Midday / Afternoon / Evening)
- Each renders with type-appropriate card (meals, workouts, supplements, habits)
- Completion toggle on all items
- Progress bar uses `completionRate()`, streak uses `currentStreak()`

**TodayView simplification**: `@Query` properties remain in the view (SwiftData requirement), but all computation logic moves to PlanAggregatorService. TodayView passes query results via `recalculate()` and reads unified results. Logic-heavy code (~800+ lines of computation) moves out; presentation code stays.

---

## 9. AddHabitSheet Enhancement

**Current categories**: Meal, Workout, Grocery

**New categories**: Habit, Medication

**Habit fields** (creates Habit with category `.habit`):
- Title (required)
- Duration (optional)
- Notes (optional, stored in `subtitle`)
- Time (optional)
- Recurrence (daily/weekdays/specificDays/once)
- Phase filter (optional)
- Reminder toggle + time

**Medication fields** (creates UserSupplement with category "medication"):
- Title (required, e.g., "Morning Meds" or specific name)
- Time (required)
- Recurrence (daily/weekdays/specificDays/once)
- Reminder toggle + time
- Notes (optional)

Note: Medication creation flow differs from habit — it creates a `UserSupplement` (not Habit) because medications share the supplement tracking infrastructure (SupplementLog, dosage, etc.).

---

## 10. Backend Changes Summary

### Modified tables
- `habits` — add `reminderEnabled` (boolean, default false), `reminderTime` (text), `replacesItemId` (text). All nullable/defaulted, purely additive.
- `userSupplements` — add `category` (text, default "supplement"), `title` (text), `reminderEnabled` (boolean, default false), `reminderTime` (text). Make `supplementId` nullable (breaking change — see Section 3 migration notes).

### Sync endpoint changes
- Add `reminderEnabled`, `reminderTime`, `replacesItemId` handling for `habits` in sync
- Add `category`, `title`, `reminderEnabled`, `reminderTime` handling for `userSupplements` in sync
- No new tables in `tableMap` — habits use existing `habits` and `habitLogs`

### Migration
- Drizzle schema update + `npm run db:push`
- `habits` changes are purely additive (new nullable columns)
- `userSupplements.supplementId` nullable change requires constraint modification — see Section 3

---

## 11. iOS Model & DTO Changes Summary

### New files
- `NamahWellness/Services/PlanAggregatorService.swift` — computation engine
- `NamahWellness/Views/Plan/HabitsView.swift` — HABITS sub-tab

### Renamed files
- `UserPlanItem.swift` → `Habit.swift` — rename class, add `reminderEnabled`, `reminderTime`, `replacesItemId` fields; add `.habit` and `.medication` to `HabitCategory`
- `PlanItemLog.swift` → `HabitLog.swift` — rename class
- `AddPlanItemSheet.swift` → `AddHabitSheet.swift` — rename view, add Habit and Medication categories

### Modified files
- `UserSupplement model` — add `category`, `title`, `reminderEnabled`, `reminderTime`; make `supplementId` optional
- `APITypes.swift` — update HabitDTO and UserSupplementDTO with new fields
- `SyncService.swift` — ensure new fields sync correctly
- `NotificationService.swift` — add per-item reminder scheduling methods
- `NamahWellnessApp.swift` — no new models in ModelContainer (using existing ones)
- `ContentView.swift` — create PlanAggregatorService, pass @Query results, inject via environment
- `TodayView.swift` — consume PlanAggregatorService for computation, keep @Query for data
- `PlanView.swift` — add HABITS sub-tab, update PlanTab enum
- `MoveView.swift` — add copy-on-write edit, reset to default, inline completion
- `MealPlanView.swift` — add copy-on-write edit, reset to default, inline completion, 7-day expansion
- `PlanSupplementsView.swift` — rename to "Supps & Meds", support medication category, reminder UI

---

## NOT in scope
- AI-powered meal suggestions
- Weekly review/summary view
- Workout progressive overload tracking
- Recipe builder UI (ingredientsJSON field exists for later)
- Meal prep day indicator
- Phase transition notifications
- Actionable notification responses (mark done from lock screen)
- Habit stacking / habit chain visualization
- Per-session workout completion (stays day-level for now)

---

## Data Flow: Copy-on-Write

```
USER LONG-PRESSES DEFAULT → "EDIT"
         │
         ▼
┌─────────────────────────┐
│ AddHabitSheet opens   │
│ pre-filled with default  │
│ data (title, time, etc.) │
└───────────┬─────────────┘
            │ user modifies + saves
            ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│ Create Habit      │     │ Create UserItemHidden    │
│  - copied + modified data│     │  - itemId = default's ID │
│  - replacesItemId = ID   │     │  - itemType = meal/workout│
│  - same recurrence/day   │     │                          │
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                               │
            └──────── modelContext.save() ───┘  (atomic)
                          │
                          ▼
              User sees custom version
              Default hidden but preserved

USER LONG-PRESSES CUSTOM → "RESET TO DEFAULT"
         │
         ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│ Delete Habit      │     │ Delete UserItemHidden    │
│  (find by id)            │     │  (find by replacesItemId)│
└───────────┬─────────────┘     └───────────┬─────────────┘
            │                               │
            └──────── modelContext.save() ───┘  (atomic)
                          │
                          ▼
              Original default reappears
```

---

## Data Flow: Per-Item Notification

```
USER TOGGLES REMINDER ON FOR HABIT
         │
         ▼
┌─────────────────────────┐
│ habit.reminderEnabled │
│  = true                  │
│ habit.reminderTime    │
│  = "7:00am"              │
└───────────┬─────────────┘
            │
            ▼
┌───────────────────────────────────────────┐
│ NotificationService.scheduleItemReminder( │
│   identifier: "habit-{id}",           │
│   title: "Time for Morning Meditation",  │
│   time: "7:00am",                        │
│   recurrence: .specificDays,             │
│   recurrenceDays: "0,2,6"               │
│ )                                         │
└───────────┬───────────────────────────────┘
            │
            ▼
┌───────────────────────────────────────────┐
│ UNUserNotificationCenter                  │
│  → UNCalendarNotificationTrigger          │
│    (weekday: Mon, hour: 7, repeats: yes)  │
│  → UNCalendarNotificationTrigger          │
│    (weekday: Wed, hour: 7, repeats: yes)  │
│  → UNCalendarNotificationTrigger          │
│    (weekday: Sun, hour: 7, repeats: yes)  │
└───────────────────────────────────────────┘
```
