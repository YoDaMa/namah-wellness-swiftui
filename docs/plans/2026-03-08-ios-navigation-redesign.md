# iOS Navigation Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Consolidate 5-tab iOS navigation to 3 mutually exclusive tabs: Today, Nutrition, My Cycle.

**Architecture:** Replace 5-tab TabView with 3-tab TabView. Move calendar + cycle management into MyCycleView. Make Hormones a push destination from Nutrition. Replace PhaseHeaderView with a prominent hero card. Add horizontal phase picker to PhaseDetailView. Extract account settings into a pushed AccountSettingsView.

**Tech Stack:** SwiftUI, SwiftData, @Observable CycleService

**Key files (current):**
- `NamahWellness/App/ContentView.swift` — TabView root (5 tabs)
- `NamahWellness/Views/Today/TodayView.swift` — Today dashboard
- `NamahWellness/Views/Nutrition/NutritionView.swift` — Nutrition (meals/supplements/grocery)
- `NamahWellness/Views/Profile/ProfileView.swift` — Profile (cycle stats/logging/history)
- `NamahWellness/Views/Calendar/CalendarView.swift` — Calendar grid + day details
- `NamahWellness/Views/Phase/PhaseDetailView.swift` — Phase detail
- `NamahWellness/Views/Hormones/HormonesView.swift` — Hormones page
- `NamahWellness/Views/Components/PhaseHeaderView.swift` — Small phase header

---

### Task 1: Create PhaseHeroCard component

Replace the small `PhaseHeaderView` line with a prominent hero card for Today.

**Files:**
- Create: `NamahWellness/Views/Components/PhaseHeroCard.swift`

**Step 1: Create PhaseHeroCard**

```swift
import SwiftUI

struct PhaseHeroCard: View {
    let phase: PhaseInfo
    let cycleStats: CycleStats

    private var phaseColors: PhaseColors {
        PhaseColors.forSlug(phase.phaseSlug)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(phaseColors.color)
                    .frame(width: 10, height: 10)
                Text(phase.phaseName.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Text(phase.phaseName + " Phase")
                .font(.heading(24))
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                Label("Day \(phase.dayInPhase) of phase", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Cycle day \(phase.cycleDay) of \(cycleStats.avgCycleLength)", systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if phase.isOverridden {
                Text("Manual override active")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.spice)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(phaseColors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

**Step 2: Build to verify**

Run: `cd /Users/yosephmaguire/repos/namah-wellness-swiftui && xcodegen generate && xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)"`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Components/PhaseHeroCard.swift
git commit -m "feat: add PhaseHeroCard component for Today hero section"
```

---

### Task 2: Update TodayView — hero card + pass cycleService to PhaseDetail

Replace `PhaseHeaderView` with `PhaseHeroCard` wrapped in a `NavigationLink` to `PhaseDetailView`. Pass the actual `cycleService` instance.

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift`

**Step 1: Replace phase header with hero card**

In `TodayView.body`, replace:
```swift
if let phase = cycleService.currentPhase {
    PhaseHeaderView(phase: phase)
}
```

With:
```swift
if let phase = cycleService.currentPhase {
    NavigationLink {
        PhaseDetailView(slug: phase.phaseSlug, cycleService: cycleService)
    } label: {
        PhaseHeroCard(phase: phase, cycleStats: cycleService.cycleStats)
    }
    .buttonStyle(.plain)
}
```

**Step 2: Build to verify**

Run: `xcodebuild ...` (same as Task 1)
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift
git commit -m "feat: replace phase header with hero card on Today"
```

---

### Task 3: Add horizontal phase picker to PhaseDetailView

Add a row of 4 phase capsules at the top of PhaseDetailView so users can switch between phases.

**Files:**
- Modify: `NamahWellness/Views/Phase/PhaseDetailView.swift`

**Step 1: Add selectedSlug state and phase picker**

Add a `@State` for the selected slug, defaulting to the `slug` prop:

```swift
@State private var selectedSlug: String
```

Add an initializer:
```swift
init(slug: String, cycleService: CycleService) {
    self.slug = slug
    self.cycleService = cycleService
    self._selectedSlug = State(initialValue: slug)
}
```

Change all references from `slug` to `selectedSlug` for the displayed content:
- `private var phase: Phase?` should use `selectedSlug`
- `private var phaseColor: Color` should use `selectedSlug`
- `nutrientsBar` filter should use `selectedSlug`
- `grocerySection` should pass `selectedSlug`

Add phase picker view at the top of the body (inside ScrollView, before heroSection):

```swift
private var phasePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            ForEach(phases.sorted(by: { ($0.dayStart ?? 0) < ($1.dayStart ?? 0) }), id: \.id) { p in
                Button {
                    selectedSlug = p.slug
                } label: {
                    Text(p.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(selectedSlug == p.slug ? .white : .secondary)
                        .background(selectedSlug == p.slug ? PhaseColors.forSlug(p.slug).color : .clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedSlug == p.slug ? .clear : Color(uiColor: .separator), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
```

Insert `phasePicker` at the top of the body ScrollView, before `heroSection`.

**Step 2: Build to verify**

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Phase/PhaseDetailView.swift
git commit -m "feat: add horizontal phase picker to PhaseDetailView"
```

---

### Task 4: Update NutritionView — remove completion tracking, add Hormones card

Nutrition becomes reference-only. Remove meal completion toggles and the `MacroSummaryBar` (which tracks completions). Add a tappable Hormones card at the top that pushes to `HormonesView`. Remove `PhaseHeaderView`.

**Files:**
- Modify: `NamahWellness/Views/Nutrition/NutritionView.swift`

**Step 1: Rewrite NutritionView**

Key changes:
1. Remove `@Query private var completions: [MealCompletion]` and `completedIds`
2. Remove `@Environment(\.modelContext)` and `toggleMeal` function
3. Remove `MacroSummaryBar` from mealsTab
4. Remove `PhaseHeaderView` from body
5. Replace `MealCardView` (which has completion toggle) with a read-only meal display
6. Add Hormones card at the top that pushes to `HormonesView`
7. Change segmented picker to: Meals | Grocery | Supplements

The Hormones card:
```swift
private var hormonesCard: some View {
    NavigationLink {
        HormonesView(cycleService: cycleService)
    } label: {
        HStack(spacing: 12) {
            Image(systemName: "flask")
                .font(.system(size: 20))
                .foregroundStyle(.phaseO)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hormones")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("Reference curves scaled to your cycle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
}
```

For meals tab, replace `MealCardView` with a simpler read-only row (no checkbox, no `onToggle`):
```swift
private func mealRow(_ meal: Meal) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
            Text(meal.time)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text(meal.mealType.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(1)
                .foregroundStyle(.secondary)
            Spacer()
            Text(meal.calories)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        Text(meal.title)
            .font(.subheadline)
            .fontWeight(.medium)
        if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
            HStack(spacing: 6) {
                MacroPill(label: "\(p)P", color: .macroProtein)
                MacroPill(label: "\(c)C", color: .macroCarbs)
                MacroPill(label: "\(f)F", color: .macroFat)
            }
            .padding(.top, 2)
        }
    }
    .padding(12)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

Reorder segmented picker to: Meals | Grocery | Supplements (grocery is more common than supplements).

**Step 2: Remove NavigationStack from HormonesView**

Since HormonesView is now pushed from NutritionView's NavigationStack, it should NOT have its own `NavigationStack`. Remove the `NavigationStack` wrapper in `HormonesView.swift` — keep only the `ScrollView` content with `.navigationTitle("Hormones")`.

**Files:**
- Modify: `NamahWellness/Views/Hormones/HormonesView.swift`

In `HormonesView.body`, change:
```swift
NavigationStack {
    ScrollView {
        ...
    }
    .navigationTitle("Hormones")
}
```
To:
```swift
ScrollView {
    ...
}
.navigationTitle("Hormones")
```

**Step 3: Build to verify**

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add NamahWellness/Views/Nutrition/NutritionView.swift NamahWellness/Views/Hormones/HormonesView.swift
git commit -m "feat: make Nutrition reference-only, add Hormones push destination"
```

---

### Task 5: Create MyCycleView — merge Calendar + Profile cycle management

Create a new `MyCycleView` that combines the calendar grid from `CalendarView` with the cycle management from `ProfileView`. Remove the day detail panel from the calendar (Today owns that). Add a gear icon in the toolbar that pushes to `AccountSettingsView`.

**Files:**
- Create: `NamahWellness/Views/MyCycle/MyCycleView.swift`
- Create: `NamahWellness/Views/MyCycle/AccountSettingsView.swift`

**Step 1: Create AccountSettingsView**

A simple pushed page for account settings:

```swift
import SwiftUI

struct AccountSettingsView: View {
    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Name", value: "User")
                LabeledContent("Email", value: "user@example.com")
            }

            Section {
                HStack {
                    Spacer()
                    Text("Namah Wellness v1.0")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

**Step 2: Create MyCycleView**

This view combines:
1. Calendar grid from CalendarView (phase colors, month nav) — but **no** dayDetailPanel
2. Tapping a day shows only phase info (phase name, day in phase) — not meals/workout/symptoms
3. Cycle stats section from ProfileView
4. Period logging section from ProfileView (button, history list, sheets)
5. Phase override section from ProfileView
6. Toolbar gear icon → pushes AccountSettingsView

The calendar portion: copy the calendar grid, legend, navigation buttons, and `phaseBackground` helper from `CalendarView.swift`. Remove `dayDetailPanel`, `workoutSection`, `mealsSection`, `symptomsSection`. For the selected day, show only a small phase info bar:

```swift
@ViewBuilder
private func dayPhaseInfo(_ day: CalendarDay) -> some View {
    if let phase = day.phase {
        HStack(spacing: 8) {
            Circle()
                .fill(colorForPhase(phase.phaseSlug, isPeak: phase.isPeak))
                .frame(width: 10, height: 10)
            Text(phase.phaseSlug.capitalized)
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Day \(phase.dayInPhase)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if phase.isProjected {
                Text("Projected")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

The cycle management portion: move all the cycle stats, logging, override, and history code from `ProfileView.swift` into `MyCycleView`. This includes `statCard`, `historyRow`, `logPeriodSheet`, `overrideSheet`, `editEndDateSheet`, and all action functions (`logPeriod`, `setOverride`, `clearOverride`, `deleteLogs`, etc.).

Layout order in ScrollView:
1. Calendar header (month title + nav buttons)
2. Legend row
3. Calendar grid
4. Selected day phase info (if any)
5. Cycle stats (HStack of 3 stat cards)
6. Actions section (Log Period button, Override Phase button)
7. Period History list

Add toolbar:
```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        NavigationLink {
            AccountSettingsView()
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(.secondary)
        }
    }
}
```

**Step 3: Build to verify**

Run: `xcodegen generate && xcodebuild ...`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add NamahWellness/Views/MyCycle/MyCycleView.swift NamahWellness/Views/MyCycle/AccountSettingsView.swift
git commit -m "feat: create MyCycleView merging calendar + cycle management"
```

---

### Task 6: Update ContentView — 3-tab TabView

Replace the 5-tab TabView with 3 tabs.

**Files:**
- Modify: `NamahWellness/App/ContentView.swift`

**Step 1: Replace TabView**

```swift
var body: some View {
    TabView(selection: $selectedTab) {
        TodayView(cycleService: cycleService)
            .tabItem {
                Image(systemName: "sun.max")
                Text("Today")
            }
            .tag(0)

        NutritionView(cycleService: cycleService)
            .tabItem {
                Image(systemName: "fork.knife")
                Text("Nutrition")
            }
            .tag(1)

        MyCycleView(cycleService: cycleService)
            .tabItem {
                Image(systemName: "circle.dotted.circle")
                Text("My Cycle")
            }
            .tag(2)
    }
    .onAppear { seedIfNeeded(); recalculate() }
    .onChange(of: cycleLogs.count) { recalculate() }
}
```

**Step 2: Build to verify**

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/App/ContentView.swift
git commit -m "feat: consolidate to 3-tab navigation (Today, Nutrition, My Cycle)"
```

---

### Task 7: Clean up — remove orphaned files and unused code

Remove files that are no longer referenced from the tab structure.

**Files:**
- Delete: `NamahWellness/Views/Profile/ProfileView.swift` (replaced by MyCycleView + AccountSettingsView)
- Delete: `NamahWellness/Views/Calendar/CalendarView.swift` (merged into MyCycleView)
- Modify: `NamahWellness/Views/Components/PhaseHeaderView.swift` — keep for potential reuse in Nutrition, but remove `linkToDetail` navigation (it created a detached CycleService instance)

**Step 1: Delete orphaned files**

```bash
rm NamahWellness/Views/Profile/ProfileView.swift
rm NamahWellness/Views/Calendar/CalendarView.swift
```

**Step 2: Simplify PhaseHeaderView**

Remove the `linkToDetail` functionality since phase navigation now goes through the hero card. Keep it as a simple display-only component that NutritionView or other views can use:

```swift
import SwiftUI

struct PhaseHeaderView: View {
    let phase: PhaseInfo

    private var phaseColors: PhaseColors {
        PhaseColors.forSlug(phase.phaseSlug)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(phaseColors.color)
                .frame(width: 10, height: 10)

            Text("Day \(phase.cycleDay) \u{00b7} \(phase.phaseName) Phase")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
```

**Step 3: Regenerate project and build**

```bash
xcodegen generate
xcodebuild ...
```

Expected: BUILD SUCCEEDED with no references to deleted files

**Step 4: Check for any remaining references to ProfileView or CalendarView**

```bash
grep -r "ProfileView\|CalendarView" NamahWellness/ --include="*.swift"
```

Fix any remaining references.

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: remove ProfileView and CalendarView (merged into MyCycleView)"
```

---

### Task 8: Final build verification and run

**Step 1: Clean build**

```bash
xcodegen generate
xcodebuild clean build -project NamahWellness.xcodeproj -scheme NamahWellness -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED

**Step 2: Run on simulator**

```bash
xcrun simctl install booted build/Debug-iphonesimulator/NamahWellness.app
xcrun simctl launch booted com.namah.wellness
```

Verify:
- 3 tabs visible: Today, Nutrition, My Cycle
- Today shows phase hero card, tapping pushes to PhaseDetailView with phase picker
- Nutrition shows Hormones card at top, 3-segment picker (Meals/Grocery/Supplements), no completion checkmarks
- My Cycle shows calendar + cycle stats + period logging + gear icon for settings

**Step 3: Commit any final fixes**

```bash
git add -A
git commit -m "chore: final build verification for 3-tab navigation"
```
