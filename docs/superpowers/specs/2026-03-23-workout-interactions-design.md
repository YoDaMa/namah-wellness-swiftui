# Workout Interactions — Design Spec

## Goal

Make workout sessions in the Today tab interactive — tap to view details, long-press to toggle completion — matching the existing meal interaction pattern. Add a WorkoutDetailView sheet with optional inline Core Protocol exercises. Core Protocol card stays at bottom of Today page unchanged.

## Changes

### 1. Workout Row Interactions (TimeBlockSectionView.swift)

Add two new callbacks to `TimeBlockSectionView`:
- `onToggleWorkout: (String) -> Void` — long-press toggles completion
- `onTapWorkout: (WorkoutSessionItem) -> Void` — tap opens detail sheet

Modify `workoutRow()` and `customWorkoutRow()`:
- Add checkbox icon (same `circle` / `checkmark.circle.fill` pattern as meals)
- Add `.onTapGesture` calling `onTapWorkout`
- Add `.onLongPressGesture` calling `onToggleWorkout`
- Apply strikethrough on title when completed
- Gray out checkbox when completed (same as meal pattern)

Add `isCompleted` field to `WorkoutSessionItem` struct.

### 2. WorkoutDetailView (NEW: Views/Today/WorkoutDetailView.swift)

A sheet showing workout session details:
- Header: focus area + time slot (e.g., "STRENGTH · Morning")
- Title (e.g., "Upper Body Push Day")
- Description
- If core exercises exist for today's workout: "CORE PROTOCOL" section listing each exercise with name, sets/reps

Uses same visual patterns as MealDetailView (phase-colored header, section labels with `.namahLabel()`).

### 3. Toggle Workout Completion (TodayView.swift)

- Query `WorkoutCompletion` for today's date
- Add `toggleWorkout(_ sessionId: String)` function following same pattern as `toggleMeal`:
  - If completion exists: delete it
  - If no completion: create `WorkoutCompletion`, insert to SwiftData
  - Sync via SyncService
  - Haptic feedback
- Pass `onToggleWorkout` and `onTapWorkout` callbacks to `TimeBlockSectionView`
- Add `@State` for workout detail sheet presentation
- Track today's workout completion IDs in a computed set (like `todayMealCompletionIds`)

### 4. Core Protocol Card — No Change

The Core Protocol card at the bottom of Today stays exactly where it is. The WorkoutDetailView *also* shows core protocol exercises inline when they exist — two entry points to the same content.

## Files

| File | Action |
|------|--------|
| `Views/Components/TimeBlockSectionView.swift` | Modify — add callbacks, checkbox, gestures to workout rows |
| `Views/Today/TodayView.swift` | Modify — add toggleWorkout, completion queries, detail sheet |
| `Views/Today/WorkoutDetailView.swift` | Create — workout detail sheet |

## Not In Scope

- Changing Core Protocol card position or behavior
- Rest day card changes
- Supplement interaction changes
- Custom workout detail differences (same sheet, adapts to available data)
- Workout completion sync to backend (WorkoutCompletion model already has sync fields; SyncService integration is a separate task)
