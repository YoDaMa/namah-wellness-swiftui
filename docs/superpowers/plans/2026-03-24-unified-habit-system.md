# Unified Habit System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the app's disparate tracking features into a unified habit system — rename UserPlanItem→Habit, wire up HabitLog for completions, add PlanAggregatorService, support generic habits/medications/notifications, and add copy-on-write editing for default meals and workouts.

**Architecture:** Backend tables renamed (userPlanItems→habits, planItemLogs→habitLogs) with new columns for reminders and copy-on-write tracking. PlanAggregatorService is a computation engine (like CycleService) that unifies all plan item types. NotificationService extended for per-item reminders. Copy-on-write pattern for editing defaults.

**Tech Stack:** SwiftUI + SwiftData (iOS 17+), SvelteKit + Drizzle ORM + Turso (backend)

**Spec:** `docs/superpowers/specs/2026-03-24-unified-habit-system-design.md`

---

## File Map

### New files
| File | Purpose |
|------|---------|
| `NamahWellness/Models/Habit.swift` | Renamed from UserPlanItem — @Model class with new fields |
| `NamahWellness/Models/HabitLog.swift` | Renamed from PlanItemLog — @Model class |
| `NamahWellness/Services/PlanAggregatorService.swift` | Computation engine for unified plan items |
| `NamahWellness/Views/Plan/HabitsView.swift` | HABITS sub-tab in PlanView |

### Modified files (iOS)
| File | Changes |
|------|---------|
| `NamahWellness/App/NamahWellnessApp.swift` | Update ModelContainer schema refs |
| `NamahWellness/App/ContentView.swift` | Add @Query for Habit/HabitLog, create PlanAggregatorService |
| `NamahWellness/Services/APITypes.swift` | Rename DTOs, add new fields |
| `NamahWellness/Services/SyncService.swift` | Rename model refs in pull/push |
| `NamahWellness/Services/NotificationService.swift` | Add per-item reminder scheduling |
| `NamahWellness/Views/Today/TodayView.swift` | Consume PlanAggregatorService |
| `NamahWellness/Views/Plan/PlanView.swift` | Add HABITS sub-tab |
| `NamahWellness/Views/Plan/AddPlanItemSheet.swift` | Rename to AddHabitSheet, add habit/medication categories |
| `NamahWellness/Views/Plan/MealPlanView.swift` | Copy-on-write edit, reset, completion, 7-day |
| `NamahWellness/Views/Plan/MoveView.swift` | Copy-on-write edit, reset, completion |
| `NamahWellness/Views/Plan/PlanSupplementsView.swift` | Medication category, reminders |

### Modified files (Backend)
| File | Changes |
|------|---------|
| `namah-nutrition-page/src/lib/server/db/schema.ts` | Rename tables, add columns |
| `namah-nutrition-page/src/routes/api/v1/sync/+server.ts` | Update tableMap keys, add aliases |

### Deleted files
| File | Reason |
|------|--------|
| `NamahWellness/Models/UserPlanItem.swift` | Renamed to Habit.swift |
| `NamahWellness/Models/PlanItemLog.swift` | Renamed to HabitLog.swift |
| `NamahWellness/Services/PlanResolver.swift` | Absorbed into PlanAggregatorService (delete AFTER Tasks 7-9 update callers) |

### Key warnings

1. **SwiftData DB reset**: Renaming `@Model` classes triggers SwiftData's migration-failure handler, which resets the local database. This is expected and acceptable — data re-syncs from backend on next launch. Do NOT panic when this happens during testing.
2. **Backend deployment transition**: The backend must return BOTH old and new JSON key names (`userPlanItems` AND `habits`) during the transition period. The iOS app should decode both: `habits ?? userPlanItems ?? []`. This prevents data loss for users who haven't updated the app yet.
3. **`PlanItemCategory` rename scope**: The enum is used by `PlanTemplate`, `UserPlanSelection`, `UserItemHidden`, and `UserItemHiddenDTO` — all of which must be updated alongside the Habit model rename.

---

### Task 1: Backend — Rename Tables + Add Columns

**Files:**
- Modify: `../namah-nutrition-page/src/lib/server/db/schema.ts`
- Modify: `../namah-nutrition-page/src/routes/api/v1/sync/+server.ts`

This task renames the backend tables and adds new columns. Must deploy before iOS changes.

- [ ] **Step 1: Rename `userPlanItems` table to `habits` and add new columns**

In `schema.ts`, replace the `userPlanItems` table definition (lines 326-351) with:

```typescript
export const habits = sqliteTable('habits', {
	id: text('id').primaryKey(),
	userId: text('userId')
		.notNull()
		.references(() => user.id),
	category: text('category').notNull(),
	title: text('title').notNull(),
	subtitle: text('subtitle'),
	time: text('time'),
	phaseSlug: text('phaseSlug'),
	recurrence: text('recurrence').notNull(),
	recurrenceDays: text('recurrenceDays'),
	specificDate: text('specificDate'),
	isActive: integer('isActive', { mode: 'boolean' }).notNull().default(true),
	createdAt: integer('createdAt', { mode: 'timestamp' }).notNull(),
	mealType: text('mealType'),
	calories: text('calories'),
	proteinG: integer('proteinG'),
	carbsG: integer('carbsG'),
	fatG: integer('fatG'),
	workoutFocus: text('workoutFocus'),
	duration: text('duration'),
	groceryCategory: text('groceryCategory'),
	ingredientsJSON: text('ingredientsJSON'),
	instructions: text('instructions'),
	// NEW fields
	reminderEnabled: integer('reminderEnabled', { mode: 'boolean' }).notNull().default(false),
	reminderTime: text('reminderTime'),
	replacesItemId: text('replacesItemId')
});
```

- [ ] **Step 2: Rename `planItemLogs` table to `habitLogs`**

Replace the `planItemLogs` table definition (lines 363-374) with:

```typescript
export const habitLogs = sqliteTable('habitLogs', {
	id: text('id').primaryKey(),
	userId: text('userId')
		.notNull()
		.references(() => user.id),
	habitId: text('habitId')
		.notNull()
		.references(() => habits.id),
	date: text('date').notNull(),
	completed: integer('completed', { mode: 'boolean' }).notNull().default(false),
	completedAt: integer('completedAt', { mode: 'timestamp' }).notNull()
});
```

- [ ] **Step 3: Add medication columns to `userSupplements`**

Add these columns to the `userSupplements` table (after line 278):

```typescript
	category: text('supplementCategory').notNull().default('supplement'), // 'supplement' | 'medication'
	title: text('supplementTitle'), // Custom display name for generic entries
	reminderEnabled: integer('supplementReminderEnabled', { mode: 'boolean' }).notNull().default(false),
	reminderTime: text('supplementReminderTime'),
```

Make `supplementId` nullable — remove `.notNull()` from the supplementId field (line 272):

```typescript
	supplementId: text('supplementId')
		.references(() => supplementDefinitions.id),  // removed .notNull()
```

- [ ] **Step 4: Update all imports throughout the backend that reference old table names**

Search for `userPlanItems` and `planItemLogs` in all backend files and update to `habits` and `habitLogs`. Key files:
- `schema.ts` — the table definitions (done above)
- `sync/+server.ts` — the tableMap and getUserState
- Any other route files that import these tables

- [ ] **Step 5: Update sync endpoint tableMap and getUserState**

In `sync/+server.ts`, update the imports and tableMap:

```typescript
// Update imports to use new names
import {
	// ... existing imports ...
	habits,        // was: userPlanItems
	habitLogs,     // was: planItemLogs
	// ... rest ...
} from '$lib/server/db/schema';

// Update tableMap entries
const tableMap = {
	// ... existing entries ...
	habits: { table: habits, idCol: habits.id, userCol: habits.userId },
	habitLogs: { table: habitLogs, idCol: habitLogs.id, userCol: habitLogs.userId },
	// Backward compatibility aliases (iOS may send old names during transition)
	userPlanItems: { table: habits, idCol: habits.id, userCol: habits.userId },
	planItemLogs: { table: habitLogs, idCol: habitLogs.id, userCol: habitLogs.userId },
	// ... rest unchanged ...
};

// Update timestampDefaults
const timestampDefaults: Partial<Record<TableName, string[]>> = {
	// ... existing entries ...
	habits: ['createdAt'],       // was: userPlanItems
	habitLogs: ['completedAt'],  // was: planItemLogs
	// ... rest unchanged ...
};
```

Update `getUserState` to use new table names:

```typescript
// In getUserState(), replace:
//   userPlanItems → habits
//   planItemLogs → habitLogs
// in both the db.select() calls and the return object keys
```

**CRITICAL**: The response JSON must return BOTH old and new key names during the transition to prevent data loss for users on the old iOS app:

```typescript
return {
    // New names (for updated iOS app)
    habits: allHabits,
    habitLogs: allHabitLogs,
    // Old names (backward compat — remove after all users update)
    userPlanItems: allHabits,
    planItemLogs: allHabitLogs,
    // ... rest unchanged ...
};
```

On the iOS side, `UserDataResponse` should decode both:
```swift
habits = try c.decodeIfPresent([HabitDTO].self, forKey: .habits)
    ?? c.decodeIfPresent([HabitDTO].self, forKey: .userPlanItems)
    ?? []
```

- [ ] **Step 6: Run Drizzle migration**

```bash
cd ../namah-nutrition-page
npx drizzle-kit generate
npm run db:push
```

SQLite supports `ALTER TABLE ... RENAME TO ...` (since 3.25.0). The preferred migration path:

```sql
-- Rename tables
ALTER TABLE userPlanItems RENAME TO habits;
ALTER TABLE planItemLogs RENAME TO habitLogs;

-- Add new columns to habits
ALTER TABLE habits ADD COLUMN reminderEnabled INTEGER NOT NULL DEFAULT 0;
ALTER TABLE habits ADD COLUMN reminderTime TEXT;
ALTER TABLE habits ADD COLUMN replacesItemId TEXT;

-- Rename FK column in habitLogs
-- SQLite 3.25+ supports: ALTER TABLE habitLogs RENAME COLUMN planItemId TO habitId;
ALTER TABLE habitLogs RENAME COLUMN planItemId TO habitId;
```

Check what Drizzle generates with `npx drizzle-kit generate`. If it generates DROP+CREATE instead of RENAME, use the manual SQL above instead — data loss from DROP is unacceptable.

- [ ] **Step 7: Build and verify**

```bash
cd ../namah-nutrition-page
npm run build
```

- [ ] **Step 8: Commit and deploy**

```bash
cd ../namah-nutrition-page
git add -A
git commit -m "feat: rename userPlanItems→habits, planItemLogs→habitLogs, add reminder/medication columns"
git push
```

---

### Task 2: iOS — Rename Models (Habit, HabitLog, HabitCategory)

**Files:**
- Create: `NamahWellness/Models/Habit.swift` (from UserPlanItem.swift)
- Create: `NamahWellness/Models/HabitLog.swift` (from PlanItemLog.swift)
- Delete: `NamahWellness/Models/UserPlanItem.swift`
- Delete: `NamahWellness/Models/PlanItemLog.swift`
- Modify: `NamahWellness/App/NamahWellnessApp.swift`

- [ ] **Step 1: Create `Habit.swift` — renamed UserPlanItem with new fields**

Create `NamahWellness/Models/Habit.swift` with the full renamed model. Key changes from UserPlanItem:
- Class name: `UserPlanItem` → `Habit`
- Enum: `PlanItemCategory` → `HabitCategory` — add `.habit` and `.medication` cases
- Enum: `PlanItemRecurrence` → `HabitRecurrence`
- New fields: `reminderEnabled: Bool`, `reminderTime: String?`, `replacesItemId: String?`
- Add computed property `hasReminder: Bool` for convenience

```swift
import Foundation
import SwiftData

// MARK: - Shared Enums

enum HabitCategory: String, Codable, CaseIterable {
    case meal = "meal"
    case workout = "workout"
    case grocery = "grocery"
    case habit = "habit"
    case medication = "medication"
    case supplement = "supplement"   // For UnifiedPlanItem — supplements aren't Habit records but need a category for display

    var displayName: String {
        switch self {
        case .meal: return "Meal"
        case .workout: return "Workout"
        case .grocery: return "Grocery"
        case .habit: return "Habit"
        case .medication: return "Medication"
        case .supplement: return "Supplement"
        }
    }

    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .workout: return "figure.run"
        case .grocery: return "cart"
        case .habit: return "sparkles"
        case .medication: return "pills"
        case .supplement: return "pill"
        }
    }
}

enum HabitRecurrence: String, Codable, CaseIterable {
    case daily = "daily"
    case weekdays = "weekdays"
    case specificDays = "specific_days"
    case once = "once"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .specificDays: return "Specific Days"
        case .once: return "Once"
        }
    }
}

// MARK: - Habit (formerly UserPlanItem)

@Model
final class Habit {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var categoryRaw: String
    var title: String
    var subtitle: String?
    var time: String?
    var phaseSlug: String?
    var recurrenceRaw: String
    var recurrenceDays: String?
    var specificDate: String?
    var isActive: Bool
    var createdAt: Date

    // Meal-specific
    var mealType: String?
    var calories: String?
    var proteinG: Int?
    var carbsG: Int?
    var fatG: Int?

    // Workout-specific
    var workoutFocus: String?
    var duration: String?

    // Grocery-specific
    var groceryCategory: String?

    // Recipe
    var ingredientsJSON: String?
    var instructions: String?

    // NEW — Reminders
    var reminderEnabled: Bool = false
    var reminderTime: String?

    // NEW — Copy-on-write tracking
    var replacesItemId: String?

    // Computed
    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .habit }
        set { categoryRaw = newValue.rawValue }
    }

    var recurrence: HabitRecurrence {
        get { HabitRecurrence(rawValue: recurrenceRaw) ?? .daily }
        set { recurrenceRaw = newValue.rawValue }
    }

    var recurrenceDayIndices: [Int] {
        guard let days = recurrenceDays else { return [] }
        return days.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    // Copy the appliesOnDate method from the existing UserPlanItem implementation exactly
    func appliesOnDate(_ dateStr: String) -> Bool {
        guard isActive else { return false }
        // ... (copy existing implementation from UserPlanItem.swift lines 96-127)
    }

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        category: HabitCategory,
        title: String,
        subtitle: String? = nil,
        time: String? = nil,
        phaseSlug: String? = nil,
        recurrence: HabitRecurrence = .daily,
        recurrenceDays: String? = nil,
        specificDate: String? = nil,
        isActive: Bool = true,
        mealType: String? = nil,
        calories: String? = nil,
        proteinG: Int? = nil,
        carbsG: Int? = nil,
        fatG: Int? = nil,
        workoutFocus: String? = nil,
        duration: String? = nil,
        groceryCategory: String? = nil,
        ingredientsJSON: String? = nil,
        instructions: String? = nil,
        reminderEnabled: Bool = false,
        reminderTime: String? = nil,
        replacesItemId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.categoryRaw = category.rawValue
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.phaseSlug = phaseSlug
        self.recurrenceRaw = recurrence.rawValue
        self.recurrenceDays = recurrenceDays
        self.specificDate = specificDate
        self.isActive = isActive
        self.createdAt = Date()
        self.mealType = mealType
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.workoutFocus = workoutFocus
        self.duration = duration
        self.groceryCategory = groceryCategory
        self.ingredientsJSON = ingredientsJSON
        self.instructions = instructions
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.replacesItemId = replacesItemId
    }
}
```

- [ ] **Step 2: Create `HabitLog.swift` — renamed PlanItemLog**

Create `NamahWellness/Models/HabitLog.swift`:

```swift
import Foundation
import SwiftData

@Model
final class HabitLog {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var habitId: String        // References Habit.id
    var date: String           // "YYYY-MM-DD"
    var completed: Bool
    var completedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        habitId: String,
        date: String,
        completed: Bool = true,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.habitId = habitId
        self.date = date
        self.completed = completed
        self.completedAt = completedAt
    }
}
```

- [ ] **Step 3: Delete old files**

Delete `NamahWellness/Models/UserPlanItem.swift` and `NamahWellness/Models/PlanItemLog.swift`. Update `project.yml` if file paths are listed there.

- [ ] **Step 4: Update NamahWellnessApp.swift ModelContainer**

Replace `UserPlanItem.self` with `Habit.self` and `PlanItemLog.self` with `HabitLog.self` in the Schema array.

- [ ] **Step 5: Find and replace all references across the codebase**

Search the entire iOS codebase for:
- `UserPlanItem` → `Habit` (class references)
- `PlanItemLog` → `HabitLog` (class references)
- `PlanItemCategory` → `HabitCategory` (enum references)
- `PlanItemRecurrence` → `HabitRecurrence` (enum references)
- `planItemId` → `habitId` (field references in HabitLog)

Key files to update: `TodayView.swift`, `PlanView.swift`, `MealPlanView.swift`, `MoveView.swift`, `PlanSupplementsView.swift`, `AddPlanItemSheet.swift`, `GroceryListView.swift`, `ContentView.swift`, `SyncService.swift`, `APITypes.swift`, `NourishView.swift`, `MealDetailView.swift`, `BrowseSupplementsSheet.swift`, `AddCustomSupplementView.swift`, **`PlanTemplate.swift`**, **`UserPlanSelection.swift`**, **`UserItemHidden.swift`** (these three also use `PlanItemCategory` → `HabitCategory`).

- [ ] **Step 6: Update APITypes.swift DTOs**

Rename `UserPlanItemDTO` → `HabitDTO`, `PlanItemLogDTO` → `HabitLogDTO`. Add new fields:

```swift
struct HabitDTO: Decodable {
    // ... existing fields ...
    let reminderEnabled: Bool?
    let reminderTime: String?
    let replacesItemId: String?

    func toModel() -> Habit {
        let h = Habit(
            id: id, userId: userId,
            category: HabitCategory(rawValue: category) ?? .meal,
            // ... existing field mapping ...
            reminderEnabled: reminderEnabled ?? false,
            reminderTime: reminderTime,
            replacesItemId: replacesItemId
        )
        return h
    }
}

struct HabitLogDTO: Decodable {
    let id: String
    let userId: String
    let habitId: String    // was: planItemId
    let date: String
    let completed: Bool
    // completedAt not decoded (set to Date() on import)

    func toModel() -> HabitLog {
        HabitLog(id: id, userId: userId, habitId: habitId, date: date, completed: completed)
    }
}
```

Update `UserDataResponse` to use new key names:

```swift
struct UserDataResponse: Decodable {
    // ... existing fields ...
    let habits: [HabitDTO]           // was: userPlanItems
    let habitLogs: [HabitLogDTO]     // was: planItemLogs
    // ... rest unchanged ...
}
```

- [ ] **Step 7: Update SyncService.swift**

In `pullUserData()`, update the model deletion and insertion to use `Habit` and `HabitLog`:

```swift
try context.delete(model: Habit.self)      // was: UserPlanItem
try context.delete(model: HabitLog.self)   // was: PlanItemLog

for dto in response.habits { context.insert(dto.toModel()) }        // was: userPlanItems
for dto in response.habitLogs { context.insert(dto.toModel()) }     // was: planItemLogs
```

Update all `queueChange` calls throughout the codebase to use new table names:
- `table: "userPlanItems"` → `table: "habits"`
- `table: "planItemLogs"` → `table: "habitLogs"`

- [ ] **Step 8: Build and verify**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: rename UserPlanItem→Habit, PlanItemLog→HabitLog, add reminder and copy-on-write fields"
```

---

### Task 3: PlanAggregatorService

**Files:**
- Create: `NamahWellness/Services/PlanAggregatorService.swift`
- Delete: `NamahWellness/Services/PlanResolver.swift`
- Modify: `NamahWellness/App/ContentView.swift`

- [ ] **Step 1: Create PlanAggregatorService**

Create `NamahWellness/Services/PlanAggregatorService.swift`. This is a computation engine following the CycleService pattern. It receives model arrays via `recalculate()` and exposes computed results.

Key contents:
- `UnifiedPlanItem` struct with: id, title, subtitle, time, category (HabitCategory), isCustom, sourceId, sourceType
- `recalculate(...)` method accepting all model arrays
- `mealsForDate(date:phaseSlug:dayInPhase:)` — resolves template meals + custom meals, filters hidden, sorts by time
- `workoutForDate(date:)` — resolves template sessions + custom workouts for day of week
- `supplementsForDate(date:)` — active supplements for the date
- `habitsForDate(date:)` — Habit records with category `.habit` that apply on date
- `allItemsForDate(...)` — combines all of the above, sorted by time
- `completionRate(date:)` — completed items / total items
- `currentStreak()` — consecutive days with any completion
- `isCompleted(itemId:sourceType:date:)` — checks appropriate completion model

Absorb `PlanResolver`'s resolve logic: the template + custom - hidden merge pattern. The existing `PlanResolver.resolveMeals/resolveWorkouts/resolveGrocery` methods become private methods inside PlanAggregatorService.

- [ ] **Step 2: Wire into ContentView**

In ContentView, add `@Query` for Habit and HabitLog. Create PlanAggregatorService as `@State`, call `recalculate()` in `onChange` handlers, and inject via `.environment()`.

Add to ContentView's properties:
```swift
@Query private var habits: [Habit]
@Query private var habitLogs: [HabitLog]
@State private var planAggregator = PlanAggregatorService()
```

In the `onAppear` / `onChange` blocks, call:
```swift
planAggregator.recalculate(
    meals: meals, workouts: workouts, workoutSessions: workoutSessions,
    supplements: supplements, customItems: habits, hiddenItems: hiddenItems,
    mealCompletions: mealCompletions, workoutCompletions: workoutCompletions,
    supplementLogs: supplementLogs, habitLogs: habitLogs
)
```

Add `.environment(planAggregator)` to the TabView.

Note: ContentView will need additional @Query properties for the models that TodayView currently queries directly. Move them up incrementally — this is a refactor that may span Tasks 3 and later.

- [ ] **Step 3: Keep PlanResolver.swift as a thin wrapper (delete later)**

Do NOT delete PlanResolver yet — its callers (MealPlanView, MoveView, NourishView, GroceryListView) are not updated until Tasks 7-9. Instead, update PlanResolver's methods to delegate to PlanAggregatorService internally. Delete PlanResolver after Tasks 7-9 are complete. Add a `// TODO: delete after Task 9` comment.

Also add `groceriesForPhase(phaseSlug:)` method to PlanAggregatorService — PlanResolver has `resolveGrocery()` which GroceryListView depends on.

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add PlanAggregatorService, absorb PlanResolver"
```

---

### Task 4: HABITS Sub-Tab + AddHabitSheet Update

**Files:**
- Create: `NamahWellness/Views/Plan/HabitsView.swift`
- Rename: `AddPlanItemSheet.swift` → `AddHabitSheet.swift`
- Modify: `NamahWellness/Views/Plan/PlanView.swift`

- [ ] **Step 1: Create HabitsView**

New sub-tab showing user's habits (Habit records with category `.habit`). Group by time of day (Morning / Afternoon / Evening / Anytime based on `time` field). Each card shows: title, duration, recurrence summary, reminder toggle, today's completion checkbox. Context menu: Edit, Delete.

- [ ] **Step 2: Rename AddPlanItemSheet → AddHabitSheet**

Rename the file and the struct. Add `.habit` and `.medication` category options. Habit fields: title, duration, notes (→subtitle), time, recurrence, phase filter, reminder toggle + time. Medication fields: title, time, recurrence, reminder toggle + time, notes.

When category is `.medication`, the sheet creates a `UserSupplement` (not a Habit) with `category: "medication"`, `title`, `reminderEnabled`, `reminderTime`. This is the one exception to the "everything is a Habit" rule.

- [ ] **Step 3: Update PlanView — add HABITS sub-tab**

Add `.habits` case to PlanTab enum. Add HabitsView as the 4th tab content. Update the segmented control/tab bar.

- [ ] **Step 4: Build and verify**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add HABITS sub-tab, rename AddPlanItemSheet to AddHabitSheet"
```

---

### Task 5: Medications & Supplements Enhancement

**Files:**
- Modify: `NamahWellness/Models/Supplement.swift` (or wherever UserSupplement is defined)
- Modify: `NamahWellness/Views/Plan/PlanSupplementsView.swift`
- Modify: `NamahWellness/Services/APITypes.swift`

- [ ] **Step 1: Update UserSupplement model**

Add new fields: `category: String` (default "supplement"), `title: String?`, `reminderEnabled: Bool` (default false), `reminderTime: String?`. Make `supplementId` optional (`String?`).

- [ ] **Step 2: Update UserSupplementDTO**

Add new fields to the DTO and `toModel()` mapping.

- [ ] **Step 3: Update PlanSupplementsView**

Rename display to "SUPPS & MEDS". Group items by category. Add "Add Medication" button. Show medication entries with pill icon. Add reminder toggle with time picker per item.

- [ ] **Step 4: Build and verify**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: medication support in supplements, per-item reminder UI"
```

---

### Task 6: Per-Item Push Notifications

**Files:**
- Modify: `NamahWellness/Services/NotificationService.swift`

- [ ] **Step 1: Add per-item reminder methods**

Add to NotificationService:

Note: `NotificationService` is a stateless `enum` with all `static` methods. New methods must also be `static`.

```swift
static func scheduleHabitReminder(
    identifier: String,
    title: String,
    time: String,
    recurrence: HabitRecurrence,
    recurrenceDays: String?
)

static func cancelHabitReminder(identifier: String)

static func rescheduleAllHabitReminders(
    habits: [Habit],
    supplements: [UserSupplement]
)
```

Notification identifiers: `"habit-{id}"`, `"supplement-{id}"`.

Use `UNCalendarNotificationTrigger` with repeating based on recurrence type. For `specificDays`, create one trigger per day of week.

- [ ] **Step 2: Call rescheduleAll on app launch**

In NamahWellnessApp or ContentView's initial sync completion, call `rescheduleAllHabitReminders`.

- [ ] **Step 3: Schedule/cancel on item create/edit/delete**

In AddHabitSheet save handler and in any edit/delete handler, schedule or cancel the notification.

- [ ] **Step 4: Build and verify**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: per-item push notification reminders for habits and supplements"
```

---

### Task 7: Copy-on-Write — Edit Defaults + Reset to Default

**Files:**
- Modify: `NamahWellness/Views/Plan/MoveView.swift`
- Modify: `NamahWellness/Views/Plan/MealPlanView.swift`

- [ ] **Step 1: Add "Edit" to workout session context menu (MoveView)**

On long-press of a default workout session, add "Edit" option. This opens AddHabitSheet pre-filled with the session's data (title, timeSlot, description → subtitle). On save:
1. Create a `Habit` with category `.workout`, `replacesItemId` = session ID
2. Create a `UserItemHidden` with `itemId` = session ID, `itemType` = "workout"
3. Both in one `modelContext.save()` call
4. Queue sync changes for both

- [ ] **Step 2: Add "Reset to Default" to custom workout context menu**

For custom Habit items that have `replacesItemId` set, show "Reset to Default" in context menu. On tap:
1. Find the `UserItemHidden` by matching `itemId == habit.replacesItemId`
2. Delete both the Habit and the UserItemHidden
3. Queue sync delete changes for both
4. One `modelContext.save()` call

- [ ] **Step 3: Add "Edit" to meal context menu (MealPlanView)**

Same pattern as workouts. Pre-fill with meal data (title, time, mealType, macros, saNote → subtitle).

- [ ] **Step 4: Add "Reset to Default" to custom meal context menu**

Same pattern as workouts.

- [ ] **Step 5: Build and verify**

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: copy-on-write editing and reset-to-default for meals and workouts"
```

---

### Task 8: Meal Planner — 7-Day Expansion + Inline Completion

**Files:**
- Modify: `NamahWellness/Views/Plan/MealPlanView.swift`

- [ ] **Step 1: Expand day navigator to 7 days**

Update the day navigator strip to show days 1-7 (not just days that have seed data). Days without content show as lighter/empty. Tapping an empty day shows "Add meals for Day N" prompt.

- [ ] **Step 2: Add inline completion checkboxes**

Each meal card gets a checkbox. Tapping toggles `MealCompletion` for today's date. Custom meals toggle `HabitLog` instead. Show completed items with checkmark overlay + reduced opacity.

- [ ] **Step 3: Build and verify**

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: 7-day meal planner with inline completion"
```

---

### Task 9: Workout Planner — Inline Completion

**Files:**
- Modify: `NamahWellness/Views/Plan/MoveView.swift`

- [ ] **Step 1: Add inline completion checkboxes**

Each workout session card gets a checkbox. Tapping toggles `WorkoutCompletion` for today's date. Custom workouts toggle `HabitLog` instead.

- [ ] **Step 2: Build and verify**

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: inline workout completion in MoveView"
```

---

### Task 10: Today Timeline — Unified Habits Display

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift`

- [ ] **Step 1: Consume PlanAggregatorService**

Add `@Environment(PlanAggregatorService.self) private var planAggregator`.

Replace inline meal/workout computation with calls to `planAggregator.mealsForDate()`, `workoutForDate()`, etc. Keep existing `@Query` properties but delegate computation to the service.

- [ ] **Step 2: Display generic habits in timeline**

Add habits (category `.habit`) to the time-block sections. Render with: SF Symbol icon (sparkles), title, duration if set, completion checkbox.

- [ ] **Step 3: Display medications in timeline**

Add medications (from UserSupplement with category "medication") alongside existing supplement entries. Show with pill icon.

- [ ] **Step 4: Update progress bar and streak**

Replace inline progress/streak calculation with `planAggregator.completionRate(today)` and `planAggregator.currentStreak()`.

- [ ] **Step 5: Build and verify**

```bash
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: unified habit display in TodayView timeline"
```

---

### Task 11: End-to-End Verification

- [ ] **Step 1: Verify backend deployment**

Confirm the backend changes from Task 1 are live at `namah.yosephmaguire.com`.

- [ ] **Step 2: Test habit creation round-trip**

1. Create a new generic habit (e.g., "Morning Meditation, 10 min, daily")
2. Pull to refresh
3. Check Turso DB: `SELECT * FROM habits WHERE category = 'habit'`
4. Verify it appears in Today timeline

- [ ] **Step 3: Test copy-on-write**

1. Long-press a default workout → Edit → modify title → save
2. Verify original is hidden, custom shows
3. Long-press custom → Reset to Default
4. Verify original reappears

- [ ] **Step 4: Test medication with reminder**

1. Add a medication via SUPPS & MEDS tab
2. Enable reminder at specific time
3. Verify notification is scheduled (check pending notifications count)

- [ ] **Step 5: Test sync between web and iOS**

1. Create a habit on iOS → pull to refresh → verify in Turso
2. Verify web app can see the data
