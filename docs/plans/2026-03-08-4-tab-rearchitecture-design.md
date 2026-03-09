# 4-Tab Re-architecture Design

## Overview

Re-architect from 3 tabs (Today, Nutrition, My Cycle) to 4 tabs (Today, My Cycle, Plan, Learn). Full view rewrite approach — build all 4 tab views from scratch, cherry-picking logic from existing views.

## Tab Structure

```
ContentView (TabView, default tab: 0)
├── TodayView        tag(0)  icon: "sun.max"               "Today"
├── MyCycleView      tag(1)  icon: "circle.dotted.circle"   "My Cycle"
├── PlanView         tag(2)  icon: "list.bullet.rectangle"  "Plan"
└── LearnView        tag(3)  icon: "book"                   "Learn"
```

All tabs receive `cycleService: CycleService`. CycleService lifecycle, seed logic, and recalculate stay in ContentView.

---

## Tab 1: Today

Daily command center. Highest open frequency. Everything actionable that resets daily.

```
TodayView (NavigationStack, ScrollView)
├── PhaseHeroCard (non-tappable status display)
│   └── Phase name, day count, cycle stats, exercise intensity
├── MacroSummaryBar (today's meal progress)
├── Meals section — today's phase-specific meals with completion toggles
├── Workout section — today's workout sessions by day-of-week
├── Supplements section — daily checklist of active regimen, grouped by time slot
└── Symptoms section — symptom grid, flow slider, daily notes
```

Key decisions:
- PhaseHeroCard is non-tappable — pure status display, no NavigationLink
- No segmented Picker — all sections visible in a single scroll with section headers
- Supplement daily checklist added (logic extracted from SupplementsView)
- All logging inline: meal toggle, supplement toggle, symptom entry

---

## Tab 2: My Cycle

Calendar and tracking intelligence layer. Data over time.

```
MyCycleView (NavigationStack, ScrollView)
├── Calendar header (month title + nav buttons)
├── Phase legend row
├── 42-day calendar grid with phase overlays
├── Selected day phase info card
├── Cycle stats bar (avg cycle, avg period, cycle count)
├── Action buttons (Log Period Start, Override Phase)
├── Period History list
├── Hormones card → pushes to HormonesView
└── Toolbar: gear icon → AccountSettingsView
```

Key decisions:
- HormonesView moves here from NutritionView as contextual education anchored to calendar
- Hormones card placed after Period History
- Least changed tab — calendar grid, logging sheets, stats all stay

---

## Tab 3: Plan

Phase-specific nutrition and workout plans. Reference content.

```
PlanView (NavigationStack, ScrollView)
├── Phase picker (horizontal scroll capsules, defaults to current phase)
├── Phase hero section (colored banner: heroTitle, heroSubtitle, exercise intensity)
├── Key nutrients bar (horizontal scroll nutrient pills)
├── Macro targets bar (Calories / Protein / Fat / Carbs)
├── SA note (South Asian dietary note)
├── Meal plan — DisclosureGroup per day with meal rows
├── Grocery — GroceryListView for selected phase
├── Workout schedule (phase-independent)
│   ├── Day selector (Mon-Sun horizontal scroll)
│   ├── Workout header (day label, focus, rest day)
│   ├── Session cards
│   └── Core exercises (disclosure group)
├── Supplements regimen (phase-independent)
│   ├── Active regimen grouped by time slot (view only, no checkboxes)
│   ├── Browse Supplements button → browse sheet
│   └── Create custom supplement flow
└── Phase reminders / evidence-based tips
```

Key decisions:
- Phase picker defaults to currentPhase but allows browsing all 4
- Meal plan, grocery, nutrients, reminders update with phase selection
- Workout schedule and supplements do NOT change with phase selector
- Supplement cards show regimen info but no daily checkboxes (daily logging is Today's job)
- Consolidates PhaseDetailView + NutritionView + ExerciseView + SupplementsView management

---

## Tab 4: Learn

Evergreen educational content. Visited occasionally.

```
LearnView (NavigationStack, ScrollView)
├── Hormones card → pushes to HormonesView
├── Phase education section
│   └── 4 phase cards, each showing:
│       ├── Phase name + color
│       ├── heroTitle + heroSubtitle
│       ├── Key nutrients
│       └── Phase reminders with evidence levels
└── (Future: supplement education)
```

Key decisions:
- HormonesView reused as-is, push destination from both My Cycle and Learn
- Phase cards are read-only summaries — no meal plans or grocery (that's Plan)
- Thinnest tab at launch, designed to grow
- No logging, no toggles — purely informational

---

## File Changes

**New files:**
- `NamahWellness/Views/Plan/PlanView.swift`
- `NamahWellness/Views/Learn/LearnView.swift`

**Rewrite:**
- `NamahWellness/Views/Today/TodayView.swift`
- `NamahWellness/Views/MyCycle/MyCycleView.swift`
- `NamahWellness/App/ContentView.swift`

**Delete:**
- `NamahWellness/Views/Nutrition/NutritionView.swift`
- `NamahWellness/Views/Phase/PhaseDetailView.swift`
- `NamahWellness/Views/Exercise/ExerciseView.swift`

**Unchanged:**
- All Models, Services, Theme
- HormonesView, HormoneChartView
- GroceryListView (embedded in PlanView)
- PhaseHeroCard, PhaseHeaderView, MacroSummaryBar, MealCardView
- AccountSettingsView, AddCustomSupplementView
- SymptomsTabView, SymptomDragCell (stay embedded in TodayView)
