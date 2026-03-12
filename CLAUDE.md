# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a SwiftUI iOS app using **XCGen** to generate the Xcode project from `project.yml`.

```bash
# Regenerate Xcode project after changing project.yml
xcodegen generate

# Build from command line
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run in Xcode
open NamahWellness.xcodeproj
```

- **Deployment target**: iOS 17.0
- **Swift version**: 5.0
- **No external dependencies** — pure SwiftUI + SwiftData
- **Test target**: `NamahWellnessTests` (unit tests for TimeParser, TimeBlockService)

## Architecture

**Pattern**: SwiftUI views + SwiftData models + Observable services (no formal ViewModels)

### Data Flow

```
NamahWellnessApp (ModelContainer with 21 model types, AppDelegate for notifications)
  └── ContentView (4-tab TabView, default: Today)
        ├── @State CycleService — recalculated on appear/change
        ├── @Query CycleLogs, Phases, etc. — SwiftData auto-refresh
        └── Views read CycleService + @Query results
```

1. `CycleService` (@Observable) is the central state coordinator — computes current phase, cycle day, phase ranges from CycleLog history
2. `CalendarService` (stateless enum) generates 42-day calendar grids with phase data
3. `SeedService` populates initial data on first launch when `phases.isEmpty`
4. All persistence uses SwiftData `@Model` classes via `@Query` and `modelContext`

### Key Services

| Service | Type | Purpose |
|---------|------|---------|
| `CycleService` | @Observable class | Cycle state: current phase, cycle day, stats, phase ranges |
| `CalendarService` | Stateless enum | Calendar grid generation with phase overlays |
| `SeedService` | Enum | First-launch database seeding (~509 lines) |
| `HormoneData` | Static enum | Hardcoded 28-point hormone curves (E2, P4, LH, FSH) |
| `TimeBlockService` | @Observable class | Computes time blocks (Morning/Midday/Afternoon/Evening) from DailySchedule |
| `TimeParser` | Stateless enum | Shared time string parsing ("7:00am" → minutes since midnight) |

### Navigation Structure

```
ContentView (TabView, default: Today)
├── TodayView — time-block daily coach (Morning / Midday / Afternoon / Evening)
│   └── PhaseHeroCard, TimeBlockProgressBar (streak + completion)
│   └── TimeBlockSectionView × 4 — each block groups meals, supplements, workout sessions
│   └── Current block highlighted with "NOW" badge, completed blocks show checkmarks
│   └── Sheets: PhaseDetail, Symptoms check-in, LogPeriod, LogSupplement, CoreProtocol
├── MyCycleView → HormonesView, AccountSettingsView
│   └── Calendar grid, cycle logging, period history, stats
├── PlanView — phase-specific reference content
│   └── Phase picker, hero, meal plan, grocery, workout schedule, supplements regimen
│   └── Sheets: browse supplements, add custom supplement
└── LearnView → HormonesView
    └── Hormones card, phase education cards
```

Views use `NavigationStack` + `NavigationLink` for push navigation and `.sheet()` for modals.

## Domain Model

Namah is a **menstrual cycle phase-based wellness app** (nutrition, fitness, symptom tracking) for South Asian women.

**Core concept**: Everything is organized around 4 menstrual cycle phases (Menstrual, Follicular, Ovulatory, Luteal). Each phase has specific meals, workouts, supplements, grocery lists, and hormone profiles.

**Key computed values in CycleService**:
- `cycleDay` — 1-based days since last period start
- `currentPhase` — determined from cycle day + phase day ranges
- `avgCycleLength` / `avgPeriodLength` — rolling average of last 3 cycles (defaults: 28/5)
- `isPeak` — ovulatory days 2-3 (fertility window)

## Related Repositories

- **Backend & webapp**: Located at `../namah-nutrition-page/` (the `namah-nutrition-page` repository). Refer to this repo for backend API code, database schema, and web frontend when working on backend tasks or database-related work.

## Conventions

- **Theme**: Use `NamahTheme` for all colors (phase-specific), typography, and label styles
- **Phase colors**: Access via `NamahTheme.color(for: phase)` — each phase has a distinct color
- **Models**: All SwiftData `@Model` classes live in `NamahWellness/Models/`
- **Views**: Organized by feature in `NamahWellness/Views/{Feature}/`
- **Components**: Reusable view components in `NamahWellness/Views/Components/`
- Portrait orientation only (iPhone)
