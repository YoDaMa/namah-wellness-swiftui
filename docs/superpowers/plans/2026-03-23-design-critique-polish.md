# Design Critique Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a design critique action plan that elevates the Today tab from functional to premium — signature phase shapes, phase-aware tab accent, unified action cards, micro-interactions, centralized copy system, and a universal log button.

**Architecture:** All design tokens (spacing, radius, shapes) live in `NamahTheme.swift`. A new `NamahCopy.swift` centralizes motivational copy. View modifications are styling/layout changes to existing files. The universal `+` log button uses `.menu()` in TodayView's nav bar, routing to existing sheets. No new data models required.

**Tech Stack:** SwiftUI (iOS 17+), SwiftData, SF Symbols, Swift `Shape` protocol for phase shapes.

**Key Constraints:**
- NO gradients on phase cards — flat colors only
- Phase shapes in hero card ONLY, not as section dividers
- Each tab keeps its own hero card implementation
- `[+]` then `[gear]` button order on far right
- Use existing sheets for logging (LogSupplementSheet, AddPlanItemSheet)

---

### Task 1: Design Tokens — Spacing & Radius Scales

**Files:**
- Modify: `NamahWellness/Theme/NamahTheme.swift` (append after line 93, before `// MARK: - Typography`)

- [ ] **Step 1: Add spacing and radius scale enums**

Add these after the `PhaseColors` struct (line 93) and before `// MARK: - Typography` (line 95):

```swift
// MARK: - Design Tokens

enum NamahSpacing {
    /// 8pt — compact spacing (within cards, between related elements)
    static let compact: CGFloat = 8
    /// 16pt — standard spacing (between cards, between sections)
    static let standard: CGFloat = 16
    /// 24pt — relaxed spacing (between major sections, visual breathing room)
    static let relaxed: CGFloat = 24
}

enum NamahRadius {
    /// 8pt — small elements (buttons, badges, nutrient pills)
    static let small: CGFloat = 8
    /// 12pt — standard cards (meal cards, supplement rows, progress bar)
    static let medium: CGFloat = 12
    /// 14pt — large containers (hero cards, section backgrounds)
    static let large: CGFloat = 14
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Theme/NamahTheme.swift
git commit -m "feat(design): add spacing and radius design tokens to NamahTheme"
```

---

### Task 2: Phase Signature Shapes

**Files:**
- Create: `NamahWellness/Theme/PhaseShapes.swift`

- [ ] **Step 1: Create phase shape definitions**

Create a new file `NamahWellness/Theme/PhaseShapes.swift` with all four shapes. Each shape is a `Shape` conformance with a simple geometric motif, bottom-right positioned. All shapes should fill roughly 40% of the card height.

```swift
import SwiftUI

// MARK: - Phase Signature Shapes
//
// Each phase has a unique geometric motif rendered as a SwiftUI Shape.
// Used as subtle overlays (10% opacity) inside the PhaseHeroCard.
//
//   Menstrual:  grounded horizontal wave — resting, earthbound
//   Follicular: ascending arc — energy building upward
//   Ovulatory:  peak/triangle — summit energy
//   Luteal:     plateau/gentle descent — winding down

/// Menstrual: a grounded, gently rolling wave along the bottom
struct MenstrualShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height * 0.35
        let y = rect.maxY - h
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: y + h * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: y + h * 0.1),
            control: CGPoint(x: rect.width * 0.25, y: y - h * 0.1)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: y + h * 0.25),
            control: CGPoint(x: rect.width * 0.75, y: y + h * 0.3)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Follicular: an ascending arc from bottom-left to top-right — energy rising
struct FollicularShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startY = rect.maxY
        let endY = rect.height * 0.4
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: startY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: endY),
            control: CGPoint(x: rect.width * 0.6, y: startY * 0.7)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Ovulatory: a peak/triangle shape — summit energy, confidence
struct OvulatoryShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let peakX = rect.width * 0.65
        let peakY = rect.height * 0.3
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.2, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: peakX, y: peakY),
            control: CGPoint(x: rect.width * 0.45, y: rect.height * 0.55)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.6),
            control: CGPoint(x: rect.width * 0.85, y: peakY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Luteal: a plateau with gentle descent — winding down
struct LutealShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let plateauY = rect.height * 0.45
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: plateauY))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: plateauY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.75),
            control: CGPoint(x: rect.width * 0.8, y: plateauY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Phase Shape Lookup

extension PhaseColors {
    /// Returns the signature Shape view for a given phase slug, rendered as an overlay.
    @ViewBuilder
    static func shapeOverlay(for slug: String) -> some View {
        switch slug {
        case "menstrual":  MenstrualShape().fill(.white.opacity(0.10))
        case "follicular": FollicularShape().fill(.white.opacity(0.10))
        case "ovulatory":  OvulatoryShape().fill(.white.opacity(0.10))
        case "luteal":     LutealShape().fill(.white.opacity(0.10))
        default:           EmptyView()
        }
    }
}
```

- [ ] **Step 2: Add to Xcode project**

If using XCGen, the file should be auto-included. Verify by building:

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`

If it fails because the file isn't found, regenerate the project:
```bash
xcodegen generate
```
Then rebuild.

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Theme/PhaseShapes.swift
git commit -m "feat(design): add signature phase shapes — geometric motifs per cycle phase"
```

---

### Task 3: Centralized Copy System

**Files:**
- Create: `NamahWellness/Theme/NamahCopy.swift`

- [ ] **Step 1: Create the copy file**

```swift
import Foundation

/// Centralized motivational copy for the app.
/// All user-facing greeting text, phase one-liners, and motivational strings
/// live here so they can be audited, updated, and eventually localized in one place.
enum NamahCopy {

    // MARK: - Greeting

    /// Returns a time-appropriate greeting and phase-aware subtitle.
    /// Selection is deterministic per calendar day (seeded by date) to avoid
    /// random text flickering on SwiftUI body re-evaluation.
    static func greeting(phase: String?, hour: Int) -> (title: String, subtitle: String?) {
        let timeGreeting: String
        switch hour {
        case 0..<12:  timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default:      timeGreeting = "Good evening"
        }

        guard let phase else {
            return (timeGreeting, nil)
        }

        let subtitles = phaseSubtitles(for: phase, hour: hour)
        let subtitle = stableChoice(from: subtitles)
        return (timeGreeting, subtitle)
    }

    /// Picks a stable element from an array, seeded by the current calendar day.
    /// Same day always returns the same index, avoiding re-render flicker.
    private static func stableChoice(from options: [String]) -> String? {
        guard !options.isEmpty else { return nil }
        let day = Calendar.current.component(.dayOfYear, from: Date())
        return options[day % options.count]
    }

    // MARK: - Phase One-Liners

    /// Returns a motivational one-liner for the current phase.
    static func phaseOneLiner(_ slug: String) -> String? {
        let options: [String]
        switch slug {
        case "menstrual":
            options = [
                "Rest is productive today — honor your body's need to slow down.",
                "Your body is doing important work. Give it space.",
                "Slow mornings, warm meals, early nights. That's the plan.",
                "This is your reset. Everything rebuilds from here."
            ]
        case "follicular":
            options = [
                "Your energy is building — great day for trying something new.",
                "Fresh cycle energy. Your body is ready to move and create.",
                "Rising estrogen, rising ambition. Lean into it.",
                "This is your launchpad phase. Start something."
            ]
        case "ovulatory":
            options = [
                "Peak energy and confidence — make the most of it.",
                "You're at your most magnetic. Show up fully today.",
                "Peak fertility, peak power. Your body is firing on all cylinders.",
                "Everything peaks now — energy, mood, communication. Use it."
            ]
        case "luteal":
            options = [
                "Winding down — focus on comfort foods and gentle movement.",
                "Your body is shifting inward. Cozy meals, shorter workouts.",
                "Progesterone is rising. Warm, grounding choices today.",
                "Nesting energy. Honor the slow-down."
            ]
        default:
            return nil
        }
        return stableChoice(from: options)
    }

    // MARK: - Private Helpers

    private static func phaseSubtitles(for phase: String, hour: Int) -> [String] {
        let isMorning = hour < 12
        let isEvening = hour >= 17

        switch phase {
        case "menstrual":
            if isMorning {
                return [
                    "Ease into it. Your body is resetting.",
                    "A gentle morning sets the tone. No rush.",
                    "Start slow. Warm water, warm food, warm thoughts."
                ]
            } else if isEvening {
                return [
                    "Wind down early tonight. Rest fuels recovery.",
                    "You've honored your body today. Now rest.",
                    "Early to bed. Tomorrow rebuilds from tonight."
                ]
            } else {
                return [
                    "Rest is productive today — honor your body's need to slow down.",
                    "Midday pause. Listen to what your body needs.",
                    "Keep it gentle. You're doing the work just by resting."
                ]
            }

        case "follicular":
            if isMorning {
                return [
                    "Fresh energy this morning. What will you start?",
                    "Your body is primed for something ambitious today.",
                    "Rising estrogen, rising possibility. Go for it."
                ]
            } else if isEvening {
                return [
                    "Good energy today? Channel it into tomorrow's plan.",
                    "Building momentum. Keep the streak going.",
                    "Your body is ramping up. Rest well to fuel it."
                ]
            } else {
                return [
                    "Your energy is building — great day for trying something new.",
                    "Midday and rising. This is your creative window.",
                    "Follicular flow. Try that thing you've been putting off."
                ]
            }

        case "ovulatory":
            if isMorning {
                return [
                    "Peak morning. You're at your most magnetic today.",
                    "Everything is firing — energy, mood, confidence.",
                    "Your body is peaking. Show up big today."
                ]
            } else if isEvening {
                return [
                    "What a day. Peak energy well spent.",
                    "You showed up fully today. Well done.",
                    "Peak phase evenings — socialize, celebrate, connect."
                ]
            } else {
                return [
                    "Peak energy and confidence — make the most of it.",
                    "Ovulatory power hour. This is your time.",
                    "You're radiating. Make that call, send that message."
                ]
            }

        case "luteal":
            if isMorning {
                return [
                    "Gentle morning. Your body is shifting gears.",
                    "Progesterone rising. Warm breakfast, slow start.",
                    "Cozy morning energy. Lean into the quiet."
                ]
            } else if isEvening {
                return [
                    "Nesting time. Comfort food and early wind-down.",
                    "Your body wants rest. Give it what it needs.",
                    "Luteal evenings are for comfort. No guilt."
                ]
            } else {
                return [
                    "Winding down — focus on comfort foods and gentle movement.",
                    "Afternoon in the luteal phase. Keep it light.",
                    "Progesterone is peaking. Shorter workout, richer meal."
                ]
            }

        default:
            return ["Welcome back."]
        }
    }
}
```

- [ ] **Step 2: Regenerate project if needed and build**

```bash
xcodegen generate
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Theme/NamahCopy.swift
git commit -m "feat(design): add centralized copy system with phase×time-of-day variants"
```

---

### Task 4: Phase Hero Card — Shape Overlay + Parallax

**Files:**
- Modify: `NamahWellness/Views/Components/PhaseHeroCard.swift`

- [ ] **Step 1: Add shape overlay and parallax to PhaseHeroCard**

Replace the entire `body` (lines 40–85) with this version that adds the shape overlay with scroll-based parallax:

```swift
    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let parallaxOffset = minY * 0.05 // subtle parallax

            VStack(alignment: .leading, spacing: 10) {
                // Phase dot + label
                HStack {
                    Circle()
                        .fill(phaseColors.color)
                        .frame(width: 10, height: 10)
                    Text(phase.phaseName.uppercased())
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .tracking(2)
                        .foregroundStyle(.secondary)
                }

                // Tagline as large display title
                if let tagline {
                    Text(tagline)
                        .font(.display(26))
                        .foregroundStyle(.primary)
                }

                // Description — first sentence only, never truncated
                if let sentence = firstSentence {
                    Text(sentence)
                        .font(.prose(13, relativeTo: .footnote))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Day info — plain text, no icons
                Text("Day \(phase.dayInPhase) · Cycle day \(phase.cycleDay)/\(cycleStats.avgCycleLength)")
                    .font(.nCaption)
                    .foregroundStyle(.secondary)

                if phase.isOverridden {
                    Text("Manual override active")
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.spice)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    phaseColors.mid

                    PhaseColors.shapeOverlay(for: phase.phaseSlug)
                        .offset(y: parallaxOffset)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: NamahRadius.medium))
        }
        .frame(height: estimatedHeight)
    }

    /// Estimated height for GeometryReader (which needs explicit sizing).
    /// Accounts for padding (32) + dot row (~18) + tagline (~34) + sentence (~20) + day info (~16) + spacing.
    private var estimatedHeight: CGFloat {
        var h: CGFloat = 32 + 18 + 16 // padding + dot row + day info
        h += 10 * 3 // spacing between elements
        if tagline != nil { h += 34 }
        if firstSentence != nil { h += 20 }
        if phase.isOverridden { h += 16 }
        return h
    }
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Views/Components/PhaseHeroCard.swift
git commit -m "feat(design): phase hero card — signature shape overlay with scroll parallax"
```

---

### Task 5: Core Protocol Card — Unify with Check-In Styling

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift` (lines 549-573, the `coreProtocolCard`)

- [ ] **Step 1: Restyle Core Protocol card to match Evening check-in**

The check-in card uses: phase color background at 8% opacity, phase color stroke at 15% opacity, chevron, two-line layout. Apply the same treatment to `coreProtocolCard`. Replace lines 549-574:

```swift
    private var coreProtocolCard: some View {
        Button { showCoreProtocol = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.core.training")
                    .font(.sans(18))
                    .foregroundStyle(phaseColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Core Protocol")
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("\(coreExercises.count) exercises · phase-matched intensity")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.nCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(phaseColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: NamahRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: NamahRadius.medium)
                    .stroke(phaseColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift
git commit -m "feat(design): unify Core Protocol card with check-in styling — phase bg, chevron"
```

---

### Task 6: Universal Log Button + Remove Orphan

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift`

- [ ] **Step 1: Add @State for new sheets**

Add after line 35 (`@State private var showLogSupplement = false`):

```swift
    @State private var showLogMeal = false
    @State private var showLogWorkout = false
```

- [ ] **Step 2: Add + button to toolbar**

Replace the toolbar section (lines 324-331) with:

```swift
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            Button {
                                showLogMeal = true
                            } label: {
                                Label("Add Meal", systemImage: "fork.knife")
                            }
                            Button {
                                showLogSupplement = true
                            } label: {
                                Label("Log Supplement", systemImage: "pill.fill")
                            }
                            Button {
                                showLogWorkout = true
                            } label: {
                                Label("Add Workout", systemImage: "figure.run")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                        }

                        Button { showProfile = true } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
```

- [ ] **Step 3: Add sheet presentations for new log options**

Add after the existing `.sheet(isPresented: $showLogSupplement)` block (after line 400):

```swift
            .sheet(isPresented: $showLogMeal) {
                NavigationStack {
                    AddPlanItemSheet(
                        defaultCategory: .meal,
                        phaseSlug: cycleService.currentPhase?.phaseSlug ?? "menstrual"
                    )
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLogWorkout) {
                NavigationStack {
                    AddPlanItemSheet(
                        defaultCategory: .workout,
                        phaseSlug: cycleService.currentPhase?.phaseSlug ?? "menstrual"
                    )
                }
                .presentationDragIndicator(.visible)
            }
```

- [ ] **Step 4: Remove the orphaned "Log Extra Supplement" button**

Delete lines 643-660 (the `Button` block containing "Log Extra Supplement"). Do NOT delete line 661 — that is the closing `}` of the surrounding `VStack`.

```swift
            // DELETE LINES 643-660 ONLY (the Button, not the VStack closing brace):
            Button {
                showLogSupplement = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.sans(16))
                        .foregroundStyle(phaseColor)
                    Text("Log Extra Supplement")
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift
git commit -m "feat(design): universal + log button in nav bar, remove orphaned supplement button"
```

---

### Task 7: Wire NamahCopy into TodayView

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift`

- [ ] **Step 1: Replace inline greeting with NamahCopy**

Replace the `timeGreeting` computed property (lines 235-242) with:

```swift
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let phase = cycleService.currentPhase?.phaseSlug
        return NamahCopy.greeting(phase: phase, hour: hour).title
    }
```

Replace `phaseOneLiner` (lines 244-253) with:

```swift
    private var phaseOneLiner: String? {
        guard let phase = cycleService.currentPhase else { return nil }
        let hour = Calendar.current.component(.hour, from: Date())
        return NamahCopy.greeting(phase: phase.phaseSlug, hour: hour).subtitle
    }
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift
git commit -m "feat(design): wire NamahCopy into TodayView — centralized greeting + one-liners"
```

---

### Task 8: Section Spacing + Active Block Styling

**Files:**
- Modify: `NamahWellness/Views/Today/TodayView.swift` (LazyVStack spacing)
- Modify: `NamahWellness/Views/Components/TimeBlockSectionView.swift` (block header)

- [ ] **Step 1: Increase inter-section spacing in TodayView**

In TodayView.swift, change the LazyVStack spacing from 16 to 24 (line 260):

```swift
// Change:
LazyVStack(alignment: .leading, spacing: 16) {
// To:
LazyVStack(alignment: .leading, spacing: NamahSpacing.relaxed) {
```

- [ ] **Step 2: Ensure inactive block headers use .secondary consistently**

In `TimeBlockSectionView.swift`, the block header (lines 150-183) already correctly uses `isCurrent ? phaseColor : .secondary` for icon and label. Verify this is consistent. No change needed if already correct.

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Views/Today/TodayView.swift NamahWellness/Views/Components/TimeBlockSectionView.swift
git commit -m "feat(design): increase section spacing to 24pt, verify active block styling"
```

---

### Task 9: Macro Line Visual Weight

**Files:**
- Modify: `NamahWellness/Views/Components/MealCardContent.swift` (lines 99-101)

- [ ] **Step 1: Reduce macro line visual weight**

Change the macro text styling from `nCaption` + `.secondary` to `nCaption2` + `.tertiary`:

```swift
// Change (lines 99-101):
                    Text(macroText)
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
// To:
                    Text(macroText)
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Views/Components/MealCardContent.swift
git commit -m "feat(design): reduce macro line visual weight — nCaption2, tertiary color"
```

---

### Task 10: Phase-Aware Tab Bar Accent

**Files:**
- Modify: `NamahWellness/App/ContentView.swift`

- [ ] **Step 1: Add phase-aware tint to TabView**

Add a computed property for the current phase color and apply `.tint()` to the TabView. After line 52 (the closing of `TabView`), add `.tint()`:

```swift
                }
                .tint(currentPhaseColor)  // ← add this line
                .environment(syncService)
```

Add a computed property to ContentView (before the `body`):

```swift
    private var currentPhaseColor: Color {
        guard let slug = cycleService.currentPhase?.phaseSlug else { return .primary }
        return PhaseColors.forSlug(slug).color
    }
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/App/ContentView.swift
git commit -m "feat(design): phase-aware tab bar accent — tint shifts with cycle phase"
```

---

### Task 11: Micro-Interactions — Completion Bounce

**Files:**
- Modify: `NamahWellness/Views/Components/TimeBlockSectionView.swift`
- Modify: `NamahWellness/Views/Components/MealCardContent.swift`

- [ ] **Step 1: Add completion bounce to MealCardContent**

Add a `@State` for bounce animation and apply it to the checkbox icon. At the top of MealCardContent (after line 16), add:

Note: MealCardContent is a presentational component without internal state for completion. The bounce needs to happen at the call site. Instead, add `.sensoryFeedback(.success, trigger: isCompleted)` to MealCardContent's body.

After the `.overlay` block at the end of MealCardContent body (line 115), add:

```swift
        .sensoryFeedback(.success, trigger: isCompleted)
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Views/Components/MealCardContent.swift NamahWellness/Views/Components/TimeBlockSectionView.swift
git commit -m "feat(design): completion haptic feedback on meal card toggle"
```

---

### Task 12: Progress Bar Momentum + Section Fade-In

**Files:**
- Modify: `NamahWellness/Views/Components/TimeBlockProgressBar.swift` (line 59)
- Modify: `NamahWellness/Views/Today/TodayView.swift` (time block sections)

- [ ] **Step 1: Increase progress bar overshoot**

Change the dampingFraction on line 59 of TimeBlockProgressBar.swift:

```swift
// Change:
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
// To:
.animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
```

- [ ] **Step 2: Add section fade-in on appear**

Note: `.transition()` only fires on conditional insertion/removal, not on `ForEach` items that are always present. Instead, use an opacity animation driven by `.onAppear`. Wrap the `TimeBlockSectionView` call site (around line 427-455 in TodayView.swift) — add `.opacity` and `.onAppear` to each section:

After `.padding(.horizontal)` and the existing `.animation(...)` line, add:

```swift
            .opacity(appearedBlocks.contains(block.kind) ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.08)) {
                    appearedBlocks.insert(block.kind)
                }
            }
```

Also add a `@State` property at the top of TodayView (near the other `@State` vars):

```swift
    @State private var appearedBlocks: Set<TimeBlockKind> = []
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Views/Components/TimeBlockProgressBar.swift NamahWellness/Views/Today/TodayView.swift
git commit -m "feat(design): progress bar momentum + section fade-in transitions"
```

---

### Task 13: Typography Audit — Letter-Spacing

**Files:**
- Modify: `NamahWellness/Theme/NamahTheme.swift` (NamahLabelStyle, line 145)

- [ ] **Step 1: Verify and adjust letter-spacing**

The current `.tracking(2)` on NamahLabelStyle corresponds to 2pt tracking. At 11px (nCaption2) font size, 0.12-0.15em = 1.32-1.65pt. The current 2pt is slightly high. Reduce to 1.5:

```swift
// Change (line 145 in NamahLabelStyle):
            .tracking(2)
// To:
            .tracking(1.5)
```

Also verify `fontWeight` is `.medium` (line 143) — it is. No change needed there.

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add NamahWellness/Theme/NamahTheme.swift
git commit -m "feat(design): refine label letter-spacing to 1.5pt (0.14em at 11px)"
```

---

## Summary

| Task | Files | What |
|------|-------|------|
| 1 | NamahTheme.swift | Spacing + radius design tokens |
| 2 | PhaseShapes.swift (new) | 4 phase signature shapes |
| 3 | NamahCopy.swift (new) | Centralized copy system |
| 4 | PhaseHeroCard.swift | Shape overlay + scroll parallax |
| 5 | TodayView.swift | Core Protocol card unification |
| 6 | TodayView.swift | Universal + log button, remove orphan |
| 7 | TodayView.swift | Wire NamahCopy for greetings |
| 8 | TodayView.swift + TimeBlockSectionView.swift | Section spacing + active block |
| 9 | MealCardContent.swift | Macro line visual weight |
| 10 | ContentView.swift | Phase-aware tab bar tint |
| 11 | MealCardContent.swift + TimeBlockSectionView.swift | Completion haptic |
| 12 | TimeBlockProgressBar.swift + TodayView.swift | Progress momentum + fade-in |
| 13 | NamahTheme.swift | Letter-spacing refinement |
