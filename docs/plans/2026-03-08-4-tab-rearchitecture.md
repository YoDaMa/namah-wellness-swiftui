# 4-Tab Re-architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Re-architect from 3 tabs (Today, Nutrition, My Cycle) to 4 tabs (Today, My Cycle, Plan, Learn) with full view rewrites.

**Architecture:** Full rewrite of all tab views. ContentView gets a 4th tab. TodayView shows all daily actions inline (no segmented picker). PlanView consolidates meal plans, workouts, grocery, and supplement management. LearnView provides evergreen educational content. MyCycleView gains a hormones card link.

**Tech Stack:** SwiftUI, SwiftData, iOS 17.0+, XCGen

**Build command:** `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

---

### Task 1: Update ContentView to 4 tabs

**Files:**
- Modify: `NamahWellness/App/ContentView.swift`

**Step 1: Rewrite ContentView with 4 tabs**

Replace the entire body of `ContentView.swift` with:

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CycleLog.createdAt, order: .reverse) private var cycleLogs: [CycleLog]
    @Query private var phases: [Phase]

    @State private var cycleService = CycleService()
    @State private var selectedTab = 0

    var body: some View {
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
        .onAppear { seedIfNeeded(); recalculate() }
        .onChange(of: cycleLogs.count) { recalculate() }
    }

    private func recalculate() {
        cycleService.recalculate(logs: cycleLogs, phases: phases)
    }

    private func seedIfNeeded() {
        guard phases.isEmpty else { return }
        SeedService.seed(into: modelContext)
    }
}
```

**Step 2: Create stub PlanView and LearnView so the project compiles**

Create `NamahWellness/Views/Plan/PlanView.swift`:

```swift
import SwiftUI

struct PlanView: View {
    let cycleService: CycleService

    var body: some View {
        NavigationStack {
            Text("Plan")
                .navigationTitle("Plan")
        }
    }
}
```

Create `NamahWellness/Views/Learn/LearnView.swift`:

```swift
import SwiftUI

struct LearnView: View {
    let cycleService: CycleService

    var body: some View {
        NavigationStack {
            Text("Learn")
                .navigationTitle("Learn")
        }
    }
}
```

**Step 3: Regenerate Xcode project and build**

Run: `xcodegen generate && xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add NamahWellness/App/ContentView.swift NamahWellness/Views/Plan/PlanView.swift NamahWellness/Views/Learn/LearnView.swift
git commit -m "feat: update ContentView to 4-tab layout with stub Plan and Learn views"
```

---

### Task 2: Rewrite TodayView — all sections inline

**Files:**
- Rewrite: `NamahWellness/Views/Today/TodayView.swift`
- Modify: `NamahWellness/Views/Components/PhaseHeroCard.swift` (remove chevron)

**Step 1: Remove the chevron from PhaseHeroCard**

In `NamahWellness/Views/Components/PhaseHeroCard.swift`, remove lines 44-46 (the chevron.right Image and Spacer preceding it in the top row HStack). The top row should just show the circle + phase label without the chevron suggesting it's tappable.

Remove this from the HStack:
```swift
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
```

**Step 2: Rewrite TodayView**

Replace the entire content of `NamahWellness/Views/Today/TodayView.swift` with a new view that shows all sections inline without a segmented picker. The view should:

1. **PhaseHeroCard** — non-tappable (no NavigationLink wrapper). Uses same init as before.
2. **MacroSummaryBar** — same as current.
3. **Meals section** — section header "MEALS", then MealCardView for each today meal with toggle.
4. **Workout section** — section header "WORKOUT", today's workout by day-of-week. Rest day or session list.
5. **Supplements section** — section header "SUPPLEMENTS", active regimen grouped by time slot with checkboxes. Uses same data queries and toggle logic as SupplementsView.
6. **Symptoms section** — section header "SYMPTOMS", reuse SymptomsTabView inline (it stays embedded in this file).

Key data queries (all existing, plus supplement queries):
```swift
@Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
@Query private var mealCompletions: [MealCompletion]
@Query private var workoutCompletions: [WorkoutCompletion]
@Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
@Query private var workoutSessions: [WorkoutSession]
@Query private var phases: [Phase]
@Query private var symptomLogs: [SymptomLog]
@Query private var dailyNotes: [DailyNote]
@Query private var definitions: [SupplementDefinition]
@Query private var nutrients: [SupplementNutrient]
@Query private var userSupplements: [UserSupplement]
@Query private var supplementLogs: [SupplementLog]
```

The supplement section should show:
- Progress text: "X of Y taken today"
- Cards grouped by time slot (morning, with_meals, evening, as_needed)
- Each card: checkbox + name + brand/dosage + nutrient pills
- Tap toggles taken status (same logic as SupplementsView.toggleTaken)

Full code for the rewritten TodayView:

```swift
import SwiftUI
import SwiftData

struct TodayView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var mealCompletions: [MealCompletion]
    @Query private var workoutCompletions: [WorkoutCompletion]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var phases: [Phase]
    @Query private var symptomLogs: [SymptomLog]
    @Query private var dailyNotes: [DailyNote]
    @Query private var definitions: [SupplementDefinition]
    @Query private var supplementNutrients: [SupplementNutrient]
    @Query private var userSupplements: [UserSupplement]
    @Query private var supplementLogs: [SupplementLog]

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var todayMealCompletionIds: Set<String> {
        Set(mealCompletions.filter { $0.date == today }.map(\.mealId))
    }

    private var todayMeals: [Meal] {
        guard let phase = cycleService.currentPhase,
              let phaseRecord = phases.first(where: { $0.slug == phase.phaseSlug })
        else { return [] }

        let phaseMeals = allMeals.filter { $0.phaseId == phaseRecord.id && $0.proteinG != nil }
        let dayNumbers = Array(Set(phaseMeals.map(\.dayNumber))).sorted()
        guard !dayNumbers.isEmpty else { return [] }
        let todayDay = dayNumbers[(phase.dayInPhase - 1) % dayNumbers.count]
        return phaseMeals.filter { $0.dayNumber == todayDay }
    }

    private var todayWorkout: (Workout, [WorkoutSession])? {
        let jsDay = Calendar.current.component(.weekday, from: Date())
        let dayOfWeek = jsDay == 1 ? 6 : jsDay - 2
        guard let w = workouts.first(where: { $0.dayOfWeek == dayOfWeek }) else { return nil }
        let sessions = workoutSessions.filter { $0.workoutId == w.id }
        return (w, sessions)
    }

    private var todaySymptomLog: SymptomLog? {
        symptomLogs.first { $0.date == today }
    }

    private var todayNote: DailyNote? {
        dailyNotes.first { $0.date == today }
    }

    private var currentPhaseRecord: Phase? {
        guard let slug = cycleService.currentPhase?.phaseSlug else { return nil }
        return phases.first { $0.slug == slug }
    }

    // Supplements
    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }
    private var todaySupplementLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }
    private let timeSlots = [
        ("morning", "Morning"),
        ("with_meals", "With Meals"),
        ("evening", "Evening"),
        ("as_needed", "As Needed"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Phase hero
                    if let phase = cycleService.currentPhase {
                        PhaseHeroCard(
                            phase: phase,
                            cycleStats: cycleService.cycleStats,
                            heroTitle: currentPhaseRecord?.heroTitle,
                            heroSubtitle: currentPhaseRecord?.heroSubtitle,
                            exerciseIntensity: currentPhaseRecord?.exerciseIntensity
                        )
                    }

                    // Macro summary
                    if !todayMeals.isEmpty {
                        MacroSummaryBar(meals: todayMeals, completedIds: todayMealCompletionIds)
                    }

                    // Meals
                    mealsSection

                    // Workout
                    workoutSection

                    // Supplements
                    supplementsSection

                    // Symptoms
                    SymptomsTabView(
                        todaySymptomLog: todaySymptomLog,
                        todayNote: todayNote,
                        today: today,
                        phaseColor: cycleService.currentPhase.flatMap { PhaseColors.forSlug($0.phaseSlug).color }
                    )
                }
                .padding()
            }
            .navigationTitle("Today")
        }
    }

    // MARK: - Meals Section

    @ViewBuilder
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEALS")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            if todayMeals.isEmpty {
                ContentUnavailableView(
                    "No Meals",
                    systemImage: "fork.knife",
                    description: Text("Log your cycle to see phase-specific meals.")
                )
            } else {
                ForEach(todayMeals, id: \.id) { meal in
                    MealCardView(
                        meal: meal,
                        isCompleted: todayMealCompletionIds.contains(meal.id),
                        onToggle: { toggleMeal(meal) }
                    )
                }
            }
        }
    }

    // MARK: - Workout Section

    @ViewBuilder
    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKOUT")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            if let (workout, sessions) = todayWorkout {
                if workout.isRestDay {
                    ContentUnavailableView(
                        "Rest Day",
                        systemImage: "leaf",
                        description: Text(workout.dayFocus)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(workout.dayLabel)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .textCase(.uppercase)
                                .tracking(2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(workout.dayFocus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(sessions, id: \.id) { session in
                            HStack(alignment: .top, spacing: 12) {
                                Text(session.timeSlot)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 56, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(session.sessionDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                ContentUnavailableView(
                    "No Workout",
                    systemImage: "figure.run",
                    description: Text("No workout data available.")
                )
            }
        }
    }

    // MARK: - Supplements Section

    @ViewBuilder
    private var supplementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPPLEMENTS")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            if activeRegimen.isEmpty {
                ContentUnavailableView(
                    "No Supplements",
                    systemImage: "pill",
                    description: Text("Add supplements in the Plan tab.")
                )
            } else {
                let takenCount = activeRegimen.filter { todaySupplementLogIds.contains($0.id) }.count
                Text("\(takenCount) of \(activeRegimen.count) taken today")
                    .font(.footnote)
                    .fontWeight(.medium)

                ForEach(timeSlots, id: \.0) { slot, label in
                    let slotItems = activeRegimen.filter { $0.timeOfDay == slot }
                    if !slotItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label.uppercased())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .textCase(.uppercase)
                                .tracking(2)
                                .foregroundStyle(.secondary)

                            ForEach(slotItems, id: \.id) { userSup in
                                supplementCard(userSup)
                            }
                        }
                    }
                }
            }
        }
    }

    private func supplementCard(_ userSup: UserSupplement) -> some View {
        let def = definitions.first { $0.id == userSup.supplementId }
        let isTaken = todaySupplementLogIds.contains(userSup.id)
        let supNutrients = supplementNutrients.filter { $0.supplementId == userSup.supplementId }

        return Button { toggleSupplement(userSup) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isTaken ? Color.phaseF : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(def?.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isTaken ? .secondary : .primary)
                        .strikethrough(isTaken)

                    HStack(spacing: 8) {
                        if let brand = def?.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(Int(userSup.dosage)) \(def?.servingUnit ?? "dose")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !supNutrients.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(supNutrients.prefix(3), id: \.id) { n in
                                Text("\(n.nutrientKey): \(formatAmount(n.amount))\(n.unit)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(uiColor: .tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleMeal(_ meal: Meal) {
        if let existing = mealCompletions.first(where: { $0.mealId == meal.id && $0.date == today }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(MealCompletion(mealId: meal.id, date: today))
        }
    }

    private func toggleSupplement(_ userSup: UserSupplement) {
        if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
        } else {
            modelContext.insert(SupplementLog(userSupplementId: userSup.id, date: today, taken: true))
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
    }
}
```

SymptomsTabView and SymptomDragCell stay as they are in the same file (lines 206-450 of the current file). Copy them unchanged below the TodayView struct.

**Step 3: Build**

Run: `xcodegen generate && xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift NamahWellness/Views/Components/PhaseHeroCard.swift
git commit -m "feat(today): rewrite TodayView with inline sections and supplement checklist"
```

---

### Task 3: Rewrite MyCycleView — add hormones card

**Files:**
- Rewrite: `NamahWellness/Views/MyCycle/MyCycleView.swift`

**Step 1: Add hormones navigation card to MyCycleView**

The MyCycleView is mostly unchanged. The key additions:

1. Wrap the entire view body in a `NavigationStack` (it currently is not — it uses `.navigationTitle` expecting to be inside one from a parent, but as a tab it needs its own).
2. Add a hormones card after the Period History section, before the closing of the VStack. Use the same card style as NutritionView's `hormonesCard`:

```swift
// After Period History section, add:
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
```

3. Wrap the body in NavigationStack and move `.navigationTitle("My Cycle")` and `.toolbar` inside it.

The full structure should be:
```swift
NavigationStack {
    ScrollView {
        VStack(...) {
            // ... all existing content ...
            // + hormones card at the end
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .navigationTitle("My Cycle")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { ... }
    .sheet(...) // all sheets
    .alert(...)
}
```

Keep RoundedCornersShape at the bottom of the file — it's used by the calendar grid.

**Step 2: Build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/MyCycle/MyCycleView.swift
git commit -m "feat(my-cycle): add hormones navigation card"
```

---

### Task 4: Build PlanView — meals, grocery, workouts, supplements

**Files:**
- Rewrite: `NamahWellness/Views/Plan/PlanView.swift`

**Step 1: Write PlanView**

This is the largest new view. It consolidates content from PhaseDetailView, NutritionView, ExerciseView, and SupplementsView's management UI.

```swift
import SwiftUI
import SwiftData

struct PlanView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var groceryItems: [GroceryItem]
    @Query private var reminders: [PhaseReminder]
    @Query private var phaseNutrients: [PhaseNutrient]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var exercises: [CoreExercise]
    @Query private var definitions: [SupplementDefinition]
    @Query private var supplementNutrients: [SupplementNutrient]
    @Query private var userSupplements: [UserSupplement]

    @State private var selectedPhaseSlug: String?
    @State private var expandedDay: Int? = nil
    @State private var selectedDayOfWeek: Int?
    @State private var showCoreExercises = false
    @State private var showBrowse = false
    @State private var showAddCustom = false
    @State private var searchText = ""

    private var currentSlug: String {
        selectedPhaseSlug ?? cycleService.currentPhase?.phaseSlug ?? "menstrual"
    }

    private var selectedPhase: Phase? {
        phases.first { $0.slug == currentSlug }
    }

    private var phaseMeals: [Meal] {
        guard let phase = selectedPhase else { return [] }
        return allMeals.filter { $0.phaseId == phase.id && $0.proteinG != nil }
    }

    private var dayGroups: [(dayNumber: Int, label: String, calories: String?, meals: [Meal])] {
        let days = Array(Set(phaseMeals.map(\.dayNumber))).sorted()
        return days.map { day in
            let dayMeals = phaseMeals.filter { $0.dayNumber == day }
            return (day, dayMeals.first?.dayLabel ?? "Day \(day)", dayMeals.first?.dayCalories, dayMeals)
        }
    }

    private var phaseColor: Color { PhaseColors.forSlug(currentSlug).color }

    // Workout
    private var todayDow: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }
    private var currentDow: Int { selectedDayOfWeek ?? todayDow }
    private var currentWorkout: Workout? { workouts.first { $0.dayOfWeek == currentDow } }
    private var currentSessions: [WorkoutSession] {
        guard let workout = currentWorkout else { return [] }
        return workoutSessions.filter { $0.workoutId == workout.id }
    }

    // Supplements
    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }
    private let supplementTimeSlots = [
        ("morning", "Morning"),
        ("with_meals", "With Meals"),
        ("evening", "Evening"),
        ("as_needed", "As Needed"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Phase picker
                    phasePicker

                    // Phase hero
                    heroSection

                    // Key nutrients
                    nutrientsBar

                    // Macro targets
                    macroTargets

                    // SA note
                    if let p = selectedPhase, !p.saNote.isEmpty {
                        saNote(p.saNote)
                    }

                    // Meal plan
                    mealPlanSection

                    // Grocery
                    grocerySection

                    // Divider between phase-specific and phase-independent content
                    Divider()
                        .padding(.vertical, 4)

                    // Workout schedule
                    workoutSection

                    // Supplements regimen
                    supplementsSection

                    // Phase reminders
                    remindersSection
                }
                .padding()
            }
            .navigationTitle("Plan")
            .sheet(isPresented: $showBrowse) { browseSheet }
            .sheet(isPresented: $showAddCustom) { AddCustomSupplementView() }
        }
    }

    // MARK: - Phase Picker

    private var phasePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(phases.sorted(by: { $0.dayStart < $1.dayStart }), id: \.id) { phase in
                    Button {
                        selectedPhaseSlug = phase.slug
                    } label: {
                        Text(phase.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(currentSlug == phase.slug ? .white : .secondary)
                            .background(currentSlug == phase.slug ? PhaseColors.forSlug(phase.slug).color : .clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(currentSlug == phase.slug ? .clear : Color(uiColor: .separator), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let p = selectedPhase {
                Text(p.heroEyebrow.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))

                Text(p.heroTitle)
                    .font(.heading(32))
                    .foregroundStyle(.white)

                Text(p.heroSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    Text("EXERCISE")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(p.exerciseIntensity)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .padding(.top, 8)
        .background(phaseColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Nutrients

    @ViewBuilder
    private var nutrientsBar: some View {
        let phaseNuts = phaseNutrients.filter { $0.phaseId == selectedPhase?.id ?? "" }
        if !phaseNuts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("KEY NUTRIENTS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(phaseNuts, id: \.id) { nut in
                            HStack(spacing: 4) {
                                Text(nut.icon).font(.system(size: 12))
                                Text(nut.label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PhaseColors.forSlug(currentSlug).soft)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Macro Targets

    @ViewBuilder
    private var macroTargets: some View {
        if let p = selectedPhase {
            HStack(spacing: 0) {
                macroItem("Calories", p.calorieTarget)
                Divider().frame(height: 30)
                macroItem("Protein", p.proteinTarget)
                Divider().frame(height: 30)
                macroItem("Fat", p.fatTarget)
                Divider().frame(height: 30)
                macroItem("Carbs", p.carbTarget)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func macroItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - SA Note

    private func saNote(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\u{1f1ee}\u{1f1f3}")
                .font(.system(size: 16))
            Text(note)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.spice.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Meal Plan

    private var mealPlanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEAL PLAN")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            ForEach(dayGroups, id: \.dayNumber) { group in
                daySection(group)
            }
        }
    }

    private func daySection(_ group: (dayNumber: Int, label: String, calories: String?, meals: [Meal])) -> some View {
        let isExpanded = expandedDay == group.dayNumber

        return DisclosureGroup(isExpanded: Binding(
            get: { isExpanded },
            set: { expandedDay = $0 ? group.dayNumber : nil }
        )) {
            VStack(spacing: 0) {
                ForEach(group.meals, id: \.id) { meal in
                    mealRow(meal)
                }
            }
        } label: {
            HStack {
                Text(group.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                if let cal = group.calories {
                    Text(cal)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func mealRow(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meal.time)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("\u{00b7}")
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

            if !meal.mealDescription.isEmpty {
                Text(meal.mealDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                HStack(spacing: 6) {
                    MacroPill(label: "\(p)P", color: .macroProtein)
                    MacroPill(label: "\(c)C", color: .macroCarbs)
                    MacroPill(label: "\(f)F", color: .macroFat)
                }
                .padding(.top, 2)
            }

            if let sa = meal.saNote, !sa.isEmpty {
                Text(sa)
                    .font(.caption2)
                    .foregroundStyle(.spice)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Grocery

    private var grocerySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GROCERY LIST")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            GroceryListView(phaseSlug: currentSlug)
        }
    }

    // MARK: - Workout Schedule

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKOUT SCHEDULE")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            // Day selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(workouts, id: \.id) { workout in
                        Button {
                            selectedDayOfWeek = workout.dayOfWeek
                        } label: {
                            VStack(spacing: 2) {
                                Text(String(workout.dayLabel.prefix(3)))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .textCase(.uppercase)
                                if workout.dayOfWeek == todayDow {
                                    Circle()
                                        .fill(Color.spice)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .foregroundStyle(currentDow == workout.dayOfWeek ? .white : .secondary)
                            .background(currentDow == workout.dayOfWeek ? Color.primary : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(currentDow == workout.dayOfWeek ? .clear : Color(uiColor: .separator), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Current day detail
            if let workout = currentWorkout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.dayLabel)
                        .font(.title3)
                        .fontDesign(.serif)
                    Text(workout.dayFocus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if workout.isRestDay {
                        Text("REST DAY")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(2)
                            .foregroundStyle(.spice)
                            .padding(.top, 2)
                    }
                }

                if !currentWorkout!.isRestDay {
                    ForEach(currentSessions, id: \.id) { session in
                        sessionCard(session)
                    }
                }
            }

            // Core exercises
            if !exercises.isEmpty {
                DisclosureGroup(isExpanded: $showCoreExercises) {
                    ForEach(exercises, id: \.id) { exercise in
                        exerciseCard(exercise)
                    }
                } label: {
                    Text("Daily Core Protocol")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func sessionCard(_ session: WorkoutSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.timeSlot)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text(session.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if !session.sessionDescription.isEmpty {
                    Text(session.sessionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func exerciseCard(_ exercise: CoreExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(exercise.sets)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(exercise.exerciseDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Supplements Regimen

    private var supplementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPPLEMENTS")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            if activeRegimen.isEmpty {
                ContentUnavailableView(
                    "No Supplements",
                    systemImage: "pill",
                    description: Text("Browse the library to add supplements to your regimen.")
                )
            } else {
                ForEach(supplementTimeSlots, id: \.0) { slot, label in
                    let slotItems = activeRegimen.filter { $0.timeOfDay == slot }
                    if !slotItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label.uppercased())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .textCase(.uppercase)
                                .tracking(2)
                                .foregroundStyle(.secondary)

                            ForEach(slotItems, id: \.id) { userSup in
                                regimenCard(userSup)
                            }
                        }
                    }
                }
            }

            Button { showBrowse = true } label: {
                Label("Browse Supplements", systemImage: "plus.magnifyingglass")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func regimenCard(_ userSup: UserSupplement) -> some View {
        let def = definitions.first { $0.id == userSup.supplementId }
        let supNuts = supplementNutrients.filter { $0.supplementId == userSup.supplementId }

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(def?.name ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if let brand = def?.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(Int(userSup.dosage)) \(def?.servingUnit ?? "dose")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !supNuts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(supNuts.prefix(3), id: \.id) { n in
                            Text("\(n.nutrientKey): \(formatAmount(n.amount))\(n.unit)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            Button { removeFromRegimen(userSup) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Phase Reminders

    @ViewBuilder
    private var remindersSection: some View {
        let phaseReminders = reminders.filter { $0.phaseId == selectedPhase?.id ?? "" }
        if !phaseReminders.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("REMINDERS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)

                ForEach(phaseReminders, id: \.id) { reminder in
                    reminderCard(reminder)
                }
            }
        }
    }

    private func reminderCard(_ reminder: PhaseReminder) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(reminder.icon).font(.system(size: 16))

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let level = reminder.evidenceLevel, !level.isEmpty {
                    Text(evidenceLabel(level))
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(evidenceColor(level))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(evidenceColor(level).opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Browse Sheet

    private var browseSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showBrowse = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAddCustom = true
                        }
                    } label: {
                        Label("Create Custom Supplement", systemImage: "plus")
                    }
                }

                let filtered = filteredDefinitions
                let cats = Array(Set(filtered.map(\.category))).sorted()

                ForEach(cats, id: \.self) { cat in
                    Section(cat) {
                        ForEach(filtered.filter { $0.category == cat }, id: \.id) { def in
                            browseRow(def)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search supplements")
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showBrowse = false }
                }
            }
        }
    }

    private var filteredDefinitions: [SupplementDefinition] {
        if searchText.isEmpty { return definitions }
        let q = searchText.lowercased()
        return definitions.filter {
            $0.name.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }

    private func browseRow(_ def: SupplementDefinition) -> some View {
        let inRegimen = userSupplements.contains { $0.supplementId == def.id && $0.isActive }

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    if let brand = def.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(def.servingSize) \(def.servingUnit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if inRegimen {
                Image(systemName: "checkmark")
                    .foregroundStyle(.phaseF)
            } else {
                Button("Add") { addToRegimen(def) }
                    .font(.caption)
                    .fontWeight(.medium)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    private func addToRegimen(_ def: SupplementDefinition) {
        modelContext.insert(UserSupplement(
            supplementId: def.id, dosage: Double(def.servingSize),
            frequency: "daily", timeOfDay: "morning"
        ))
    }

    private func removeFromRegimen(_ userSup: UserSupplement) { userSup.isActive = false }

    private func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
    }

    private func evidenceLabel(_ level: String) -> String {
        switch level {
        case "strong": return "STRONG EVIDENCE"
        case "moderate": return "MODERATE EVIDENCE"
        case "emerging": return "EMERGING RESEARCH"
        case "expert_opinion": return "EXPERT OPINION"
        default: return level.uppercased()
        }
    }

    private func evidenceColor(_ level: String) -> Color {
        switch level {
        case "strong": return .phaseF
        case "moderate": return .phaseO
        case "emerging": return .phaseL
        default: return .secondary
        }
    }
}
```

**Step 2: Build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Plan/PlanView.swift
git commit -m "feat(plan): build PlanView with meals, grocery, workouts, supplements"
```

---

### Task 5: Build LearnView — educational content

**Files:**
- Rewrite: `NamahWellness/Views/Learn/LearnView.swift`

**Step 1: Write LearnView**

```swift
import SwiftUI
import SwiftData

struct LearnView: View {
    let cycleService: CycleService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query private var phaseNutrients: [PhaseNutrient]
    @Query private var reminders: [PhaseReminder]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hormones card
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

                    // Phase education
                    Text("PHASE GUIDE")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(.secondary)

                    ForEach(phases, id: \.id) { phase in
                        phaseEducationCard(phase)
                    }
                }
                .padding()
            }
            .navigationTitle("Learn")
        }
    }

    private func phaseEducationCard(_ phase: Phase) -> some View {
        let colors = PhaseColors.forSlug(phase.slug)
        let nutrients = phaseNutrients.filter { $0.phaseId == phase.id }
        let phaseReminders = reminders.filter { $0.phaseId == phase.id }

        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(colors.color)
                    .frame(width: 10, height: 10)
                Text(phase.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Days \(phase.dayStart)–\(phase.dayEnd)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Title and subtitle
            Text(phase.heroTitle)
                .font(.headingMedium(20))
                .foregroundStyle(.primary)

            Text(phase.heroSubtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Key nutrients
            if !nutrients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(nutrients, id: \.id) { nut in
                            HStack(spacing: 4) {
                                Text(nut.icon).font(.system(size: 12))
                                Text(nut.label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colors.soft)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Reminders
            if !phaseReminders.isEmpty {
                ForEach(phaseReminders, id: \.id) { reminder in
                    HStack(alignment: .top, spacing: 8) {
                        Text(reminder.icon).font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(reminder.text)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let level = reminder.evidenceLevel, !level.isEmpty {
                                Text(evidenceLabel(level))
                                    .font(.system(size: 8, weight: .medium))
                                    .tracking(0.5)
                                    .foregroundStyle(evidenceColor(level))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(evidenceColor(level).opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(colors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func evidenceLabel(_ level: String) -> String {
        switch level {
        case "strong": return "STRONG EVIDENCE"
        case "moderate": return "MODERATE EVIDENCE"
        case "emerging": return "EMERGING RESEARCH"
        case "expert_opinion": return "EXPERT OPINION"
        default: return level.uppercased()
        }
    }

    private func evidenceColor(_ level: String) -> Color {
        switch level {
        case "strong": return .phaseF
        case "moderate": return .phaseO
        case "emerging": return .phaseL
        default: return .secondary
        }
    }
}
```

**Step 2: Build**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add NamahWellness/Views/Learn/LearnView.swift
git commit -m "feat(learn): build LearnView with hormones and phase education"
```

---

### Task 6: Delete obsolete views and clean up

**Files:**
- Delete: `NamahWellness/Views/Nutrition/NutritionView.swift`
- Delete: `NamahWellness/Views/Phase/PhaseDetailView.swift`
- Delete: `NamahWellness/Views/Exercise/ExerciseView.swift`

**Step 1: Verify no remaining references to deleted views**

Search the codebase for references to `NutritionView`, `PhaseDetailView`, and `ExerciseView`. After Tasks 1-5, none of these should be referenced anywhere. If any references remain, remove them.

Likely references to check:
- `ContentView.swift` — should already be updated (Task 1)
- `TodayView.swift` — the old NavigationLink to PhaseDetailView should already be removed (Task 2)

**Step 2: Delete the files**

```bash
rm NamahWellness/Views/Nutrition/NutritionView.swift
rm NamahWellness/Views/Phase/PhaseDetailView.swift
rm NamahWellness/Views/Exercise/ExerciseView.swift
```

**Step 3: Regenerate Xcode project and build**

Run: `xcodegen generate && xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: delete NutritionView, PhaseDetailView, ExerciseView — absorbed into Plan and Today"
```

---

### Task 7: Update CLAUDE.md with new tab structure

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update the navigation structure section in CLAUDE.md**

Replace the Navigation Structure section to reflect the new 4-tab layout:

```markdown
### Navigation Structure

\```
ContentView (TabView, default: Today)
├── TodayView → (no push destinations, all inline)
├── MyCycleView → HormonesView; AccountSettingsView
├── PlanView → (browse supplements sheet, add custom supplement sheet)
└── LearnView → HormonesView
\```
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md navigation structure for 4-tab layout"
```
