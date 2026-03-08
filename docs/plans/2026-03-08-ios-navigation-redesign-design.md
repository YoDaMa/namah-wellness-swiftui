# iOS Navigation Redesign

## Goal

Consolidate the iOS app from 5 tabs to 3 tabs with mutually exclusive content — no page should duplicate what another shows.

## Tab Structure

| Tab | Label | SF Symbol | Purpose |
|-----|-------|-----------|---------|
| 0 | Today | `sun.max` | Daily tracking & doing |
| 1 | Nutrition | `fork.knife` | Planning & reference |
| 2 | My Cycle | `circle.dotted.circle` | Cycle awareness & history |

Standard `TabView` with Liquid Glass.

## Tab 0: Today

All daily tracking lives here and nowhere else.

### Layout (top to bottom)

1. **Phase hero card** — prominent card with phase color accent, phase name, "Day X of Phase", "Cycle Day Y of Z", phase one-liner. Tappable — pushes to Phase Detail.
2. **Macro summary bar** — calories, protein, carbs, fat from today's meals.
3. **Segmented picker**: Meals | Workout | Symptoms
   - **Meals**: Today's phase-specific meals with completion checkmarks
   - **Workout**: Today's workout sessions or rest day state
   - **Symptoms**: Symptom grid (SF Symbol icons, tap to cycle 0-5), flow intensity buttons, daily notes text editor

### Push Destination: Phase Detail

Accessed by tapping the phase hero card. Shows:
- **Horizontal phase picker** at top — 4 capsules (Menstrual, Follicular, Ovulatory, Luteal) colored by phase. Current phase pre-selected. Tap any to switch.
- Phase hero section, key nutrients, macro targets, SA note, expandable meal plan (DisclosureGroup per day), grocery list, reminders with evidence badges.

## Tab 1: Nutrition

Planning and reference content. No daily tracking, no completion checkmarks.

### Layout (top to bottom)

1. **Hormones card** — a tappable card/banner that pushes to the full Hormones detail page.
2. **Segmented picker**: Meals | Grocery | Supplements
   - **Meals**: Phase selector (horizontal capsules), full multi-day meal plans per phase with macro breakdowns. Browse/reference only.
   - **Grocery**: Phase-specific grocery checklist with category grouping and progress bar.
   - **Supplements**: Active regimen grouped by time of day, toggle taken, browse library sheet, add custom supplement sheet.

### Push Destination: Hormones

Full hormones reference page:
- Legend toggles for 4 hormones (E2, P4, LH, FSH)
- Canvas-based interactive chart with hover/drag
- Day detail panel with hormone values
- Expandable hormone info cards (DisclosureGroup)

## Tab 2: My Cycle

Cycle management, history, and calendar visualization.

### Layout (top to bottom, scrollable)

1. **Cycle calendar grid** — phase-colored days, month navigation (prev/next week + Today button). Tapping a day shows phase info only (no meals/workouts/symptoms).
2. **Cycle stats** — avg cycle length, avg period length, number of cycles tracked.
3. **Period logging** — "Log Period" button (opens date picker sheet), period history list with swipe-to-delete and cycle length calculations.
4. **Phase override** — manual override controls.

### Toolbar: Gear Icon → Account Settings (push)

Pushed detail page with: name, email, password management.

## What Gets Removed

- **CalendarView** as a tab — merged into My Cycle
- **CalendarView day detail panel** (meals/workout/symptoms) — Today owns daily content
- **ExerciseView** as standalone — workout lives only in Today's Workout segment
- **ProfileView** as a tab — split into My Cycle (tab) and Account Settings (push)
- **HormonesView** as a tab — becomes push destination from Nutrition
- **Nutrition "today's meals"** duplication — Nutrition is reference only

## Navigation Map

```
TabView (3 tabs)
+-- Today (sun.max)
|   +-- Phase hero card (tap -> Phase Detail)
|   +-- Macro summary bar
|   +-- Segmented: Meals | Workout | Symptoms
|
+-- Nutrition (fork.knife)
|   +-- Hormones card (tap -> HormonesView push)
|   +-- Segmented: Meals | Grocery | Supplements
|
+-- My Cycle (circle.dotted.circle)
    +-- Toolbar: gear icon -> Account Settings (push)
    +-- Cycle calendar grid
    +-- Cycle stats
    +-- Period logging + history
    +-- Phase override controls

Push Destinations:
+-- Phase Detail (from Today hero)
|   +-- Horizontal phase picker (4 phases, switch inline)
+-- Hormones (from Nutrition card)
|   +-- Chart, day values, hormone info cards
+-- Account Settings (from My Cycle gear)
    +-- Name, email, password
```

## Mutual Exclusivity

| Content | Lives In | Nowhere Else |
|---------|----------|-------------|
| Daily meal tracking | Today | |
| Daily workout tracking | Today | |
| Symptom logging | Today | |
| Phase meal plan reference | Nutrition | |
| Grocery lists | Nutrition | |
| Supplements | Nutrition | |
| Hormone reference | Nutrition -> Hormones | |
| Cycle calendar | My Cycle | |
| Period logging/overrides | My Cycle | |
| Account settings | My Cycle -> Settings | |
