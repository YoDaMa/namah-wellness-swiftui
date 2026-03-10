# Supplements Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the broken "Add" button in Plan's browse supplements sheet and the non-presenting "Log Extra Supplement" sheet in Today view.

**Architecture:** Extract both supplement sheets (`BrowseSupplementsSheet`, `LogSupplementSheet`) into standalone `View` structs with their own `@Query` properties so they directly observe SwiftData changes. Move Today's supplement sheet modifier from the inline Button to the NavigationStack level (matching the pattern used by all other sheets in TodayView). Add missing sync call to Plan's `toggleTaken`. Clean up dead `SupplementsView.swift`.

**Tech Stack:** SwiftUI, SwiftData

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `NamahWellness/Views/Plan/BrowseSupplementsSheet.swift` | Create | Standalone browse sheet with own `@Query`, add/search/custom supplement |
| `NamahWellness/Views/Plan/PlanSupplementsView.swift` | Modify | Remove inline browse sheet code, reference `BrowseSupplementsSheet` |
| `NamahWellness/Views/Today/LogSupplementSheet.swift` | Create | Standalone log-extra sheet with own `@Query`, toggle extra/in-plan supplements |
| `NamahWellness/Views/Today/TodayView.swift` | Modify | Remove inline log sheet code, move `.sheet` to NavigationStack level |
| `NamahWellness/Views/Components/AddCustomSupplementView.swift` | Create | Move `AddCustomSupplementView` from dead file, add sync support |
| `NamahWellness/Views/Nutrition/SupplementsView.swift` | Delete | Dead code — never referenced, replaced by `PlanSupplementsView` |

> **Note:** `project.yml` does NOT need editing — XCGen auto-discovers all `.swift` files under `NamahWellness/`. However, `xcodegen generate` must be run before building after adding/deleting files.
>
> **Out of scope:** `coreProtocolSheet` in TodayView (line 279) has the same `.sheet`-on-Button-inside-ScrollView pattern. It should be moved to the NavigationStack level in a follow-up.
>
> **Intentional gap:** Custom `SupplementDefinition` records are not synced to the server (only the `UserSupplement` is synced). This matches existing behavior — definitions are content data pulled via `pullContent`, not pushed.

---

### Task 1: Extract BrowseSupplementsSheet

**Why:** The browse sheet is currently a computed property on `PlanSupplementsView`. When `addToRegimen` inserts a `UserSupplement`, the sheet content doesn't re-render because SwiftUI's sheet presentation doesn't reliably propagate `@Query` changes from a parent view's computed properties into a presented sheet. Extracting into its own struct with `@Query` creates a direct reactive relationship.

**Files:**
- Create: `NamahWellness/Views/Plan/BrowseSupplementsSheet.swift`
- Modify: `NamahWellness/Views/Plan/PlanSupplementsView.swift`

- [ ] **Step 1: Create `BrowseSupplementsSheet.swift`**

```swift
import SwiftUI
import SwiftData

struct BrowseSupplementsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @Query private var definitions: [SupplementDefinition]
    @Query private var userSupplements: [UserSupplement]

    @State private var searchText = ""

    private var filteredDefinitions: [SupplementDefinition] {
        if searchText.isEmpty { return definitions }
        let q = searchText.lowercased()
        return definitions.filter {
            $0.name.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }

    private var activeSupplementIds: Set<String> {
        Set(userSupplements.filter(\.isActive).map(\.supplementId))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AddCustomSupplementView()
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
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func browseRow(_ def: SupplementDefinition) -> some View {
        let inRegimen = activeSupplementIds.contains(def.id)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    if let brand = def.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(def.servingSize) \(def.servingUnit)")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if inRegimen {
                Image(systemName: "checkmark")
                    .foregroundStyle(.phaseF)
            } else {
                Button("Add") { addToRegimen(def) }
                    .font(.nCaption)
                    .fontWeight(.medium)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .controlSize(.small)
            }
        }
    }

    private func addToRegimen(_ def: SupplementDefinition) {
        let sup = UserSupplement(
            supplementId: def.id, dosage: Double(def.servingSize),
            frequency: "daily", timeOfDay: "morning"
        )
        modelContext.insert(sup)
        syncService.queueChange(
            table: "userSupplements", action: "upsert",
            data: [
                "id": AnyCodable(sup.id), "supplementId": AnyCodable(def.id),
                "dosage": AnyCodable(sup.dosage), "frequency": AnyCodable("daily"),
                "timeOfDay": AnyCodable("morning"), "isActive": AnyCodable(true),
            ],
            modelContext: modelContext
        )
    }
}
```

- [ ] **Step 2: Update `PlanSupplementsView.swift` — remove inline browse sheet**

Remove the following from `PlanSupplementsView.swift`:
- The `browseSheet` computed property (lines 179–210)
- The `filteredDefinitions` computed property (lines 212–218)
- The `activeSupplementIds` computed property (lines 220–222)
- The `browseRow` function (lines 224–256)
- The `addToRegimen` function (lines 269–284)

Update the `.sheet` modifier on line 48 from:
```swift
.sheet(isPresented: $showBrowse) { browseSheet }
```
to:
```swift
.sheet(isPresented: $showBrowse) { BrowseSupplementsSheet() }
```

Remove `@State private var searchText = ""` (line 13) — no longer needed here.

- [ ] **Step 3: Add sync to `toggleTaken` in `PlanSupplementsView`**

Replace the existing `toggleTaken` function (lines 260–267) with:

```swift
private func toggleTaken(_ userSup: UserSupplement) {
    if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
        existing.taken.toggle()
        existing.loggedAt = Date()
        syncService.queueChange(table: "supplementLogs", action: "upsert",
                                data: ["id": AnyCodable(existing.id), "userSupplementId": AnyCodable(userSup.id),
                                       "date": AnyCodable(today), "taken": AnyCodable(existing.taken)],
                                modelContext: modelContext)
    } else {
        let log = SupplementLog(userSupplementId: userSup.id, date: today, taken: true)
        modelContext.insert(log)
        syncService.queueChange(table: "supplementLogs", action: "upsert",
                                data: ["id": AnyCodable(log.id), "userSupplementId": AnyCodable(userSup.id),
                                       "date": AnyCodable(today), "taken": AnyCodable(true)],
                                modelContext: modelContext)
    }
}
```

- [ ] **Step 4: Regenerate Xcode project and build**

```bash
xcodegen generate
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add NamahWellness/Views/Plan/BrowseSupplementsSheet.swift NamahWellness/Views/Plan/PlanSupplementsView.swift
git commit -m "fix(supplements): extract BrowseSupplementsSheet for reactive SwiftData updates

Browse sheet was a computed property on PlanSupplementsView, so @Query
changes from addToRegimen didn't propagate into the presented sheet.
Extracting into its own View struct with @Query creates a direct
reactive relationship. Also adds missing sync call to toggleTaken."
```

---

### Task 2: Extract LogSupplementSheet and fix sheet placement in TodayView

**Why:** Two issues: (1) the `.sheet` modifier is attached to a `Button` inside a `ScrollView`, causing it to fail to present — all other TodayView sheets are attached at the `NavigationStack` level; (2) the sheet content is a computed property on `TodayView` with the same stale-rendering issue as the browse sheet.

**Files:**
- Create: `NamahWellness/Views/Today/LogSupplementSheet.swift`
- Modify: `NamahWellness/Views/Today/TodayView.swift`

- [ ] **Step 1: Create `LogSupplementSheet.swift`**

```swift
import SwiftUI
import SwiftData

struct LogSupplementSheet: View {
    let phaseColor: Color

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @Query private var definitions: [SupplementDefinition]
    @Query private var userSupplements: [UserSupplement]
    @Query private var supplementLogs: [SupplementLog]

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }

    private var todayLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }

    var body: some View {
        NavigationStack {
            List {
                let activeIds = Set(activeRegimen.map(\.supplementId))
                let extraDefs = definitions.filter { !activeIds.contains($0.id) }

                if !extraDefs.isEmpty {
                    Section("Available Supplements") {
                        ForEach(extraDefs, id: \.id) { def in
                            let isLogged = todayLogIds.contains("extra-\(def.id)")
                            Button {
                                toggleExtraSupplement(def)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(def.name)
                                            .font(.nSubheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        if let brand = def.brand, !brand.isEmpty {
                                            Text(brand)
                                                .font(.nCaption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: isLogged ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isLogged ? phaseColor : Color(uiColor: .tertiaryLabel))
                                }
                            }
                        }
                    }
                }

                if !activeRegimen.isEmpty {
                    Section("In Your Plan") {
                        ForEach(activeRegimen, id: \.id) { userSup in
                            let def = definitions.first { $0.id == userSup.supplementId }
                            let isTaken = todayLogIds.contains(userSup.id)
                            Button {
                                toggleSupplement(userSup)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(def?.name ?? "Unknown")
                                            .font(.nSubheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text("\(Int(userSup.dosage)) \(def?.servingUnit ?? "dose")")
                                            .font(.nCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isTaken ? phaseColor : Color(uiColor: .tertiaryLabel))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleSupplement(_ userSup: UserSupplement) {
        if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": AnyCodable(existing.id), "userSupplementId": AnyCodable(userSup.id),
                                           "date": AnyCodable(today), "taken": AnyCodable(existing.taken)],
                                    modelContext: modelContext)
        } else {
            let log = SupplementLog(userSupplementId: userSup.id, date: today, taken: true)
            modelContext.insert(log)
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": AnyCodable(log.id), "userSupplementId": AnyCodable(userSup.id),
                                           "date": AnyCodable(today), "taken": AnyCodable(true)],
                                    modelContext: modelContext)
        }
    }

    private func toggleExtraSupplement(_ def: SupplementDefinition) {
        let extraId = "extra-\(def.id)"
        if let existing = supplementLogs.first(where: { $0.userSupplementId == extraId && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": AnyCodable(existing.id), "userSupplementId": AnyCodable(extraId),
                                           "date": AnyCodable(today), "taken": AnyCodable(existing.taken)],
                                    modelContext: modelContext)
        } else {
            let log = SupplementLog(userSupplementId: extraId, date: today, taken: true)
            modelContext.insert(log)
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": AnyCodable(log.id), "userSupplementId": AnyCodable(extraId),
                                           "date": AnyCodable(today), "taken": AnyCodable(true)],
                                    modelContext: modelContext)
        }
    }
}
```

- [ ] **Step 2: Update `TodayView.swift` — remove inline sheet, move `.sheet` modifier**

**Remove from TodayView:**
- The `logSupplementSheet` computed property (search for `private var logSupplementSheet: some View`)
- The `toggleSupplement` function (search for `private func toggleSupplement`)
- The `toggleExtraSupplement` function (search for `private func toggleExtraSupplement`)

**Move the `.sheet` modifier** from `supplementsSection` (attached to the "Log Extra Supplement" Button) to the NavigationStack level (after the `.sheet(isPresented: $showSymptoms)` block, which ends around line 167, before `.toolbar`):

In `supplementsSection`, change the "Log Extra Supplement" button from:
```swift
Button {
    showLogSupplement = true
} label: { ... }
.buttonStyle(.plain)
.sheet(isPresented: $showLogSupplement) {
    logSupplementSheet
}
```
to:
```swift
Button {
    showLogSupplement = true
} label: { ... }
.buttonStyle(.plain)
```

Then add at the NavigationStack level (after the `.sheet(isPresented: $showSymptoms)` block that ends around line 167, before `.toolbar`):
```swift
.sheet(isPresented: $showLogSupplement) {
    LogSupplementSheet(phaseColor: phaseColor)
}
```

- [ ] **Step 3: Regenerate Xcode project and build**

```bash
xcodegen generate
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Views/Today/LogSupplementSheet.swift NamahWellness/Views/Today/TodayView.swift
git commit -m "fix(today): extract LogSupplementSheet and move .sheet to NavigationStack level

Sheet was attached to a Button inside ScrollView, causing it to fail
to present. Moved to NavigationStack level matching all other TodayView
sheets. Extracted into own View struct for reactive @Query updates."
```

---

### Task 3: Move AddCustomSupplementView and delete dead code

**Why:** `SupplementsView.swift` is dead code (never referenced from any view), but it contains `AddCustomSupplementView` which IS used by `BrowseSupplementsSheet`. Move it to its own file, add sync support, then delete the dead file.

**Files:**
- Create: `NamahWellness/Views/Components/AddCustomSupplementView.swift`
- Delete: `NamahWellness/Views/Nutrition/SupplementsView.swift`

- [ ] **Step 1: Create `AddCustomSupplementView.swift` in Components**

Move the existing `AddCustomSupplementView` struct (from `SupplementsView.swift` lines 256–322) into its own file. Add sync support for the new definition and user supplement:

```swift
import SwiftUI
import SwiftData

struct AddCustomSupplementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @State private var name = ""
    @State private var brand = ""
    @State private var category = "Vitamins"
    @State private var servingSize = "1"
    @State private var servingUnit = "capsule"
    @State private var addToRegimen = true

    private let categories = ["Vitamins", "Minerals", "Omega / Fatty Acids", "Herbal", "Probiotics", "Amino Acids", "Other"]
    private let units = ["capsule", "tablet", "softgel", "scoop", "ml", "drops"]

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                TextField("Brand (optional)", text: $brand)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0) }
                }
            }

            Section("Serving") {
                TextField("Size", text: $servingSize)
                    .keyboardType(.numberPad)
                Picker("Unit", selection: $servingUnit) {
                    ForEach(units, id: \.self) { Text($0) }
                }
            }

            Section {
                Toggle("Add to my regimen", isOn: $addToRegimen)
            }
        }
        .navigationTitle("New Supplement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.isEmpty)
            }
        }
    }

    private func save() {
        let def = SupplementDefinition(
            name: name, brand: brand.isEmpty ? nil : brand,
            category: category, servingSize: Int(servingSize) ?? 1,
            servingUnit: servingUnit, isCustom: true
        )
        modelContext.insert(def)

        if addToRegimen {
            let sup = UserSupplement(
                supplementId: def.id, dosage: Double(Int(servingSize) ?? 1),
                frequency: "daily", timeOfDay: "morning"
            )
            modelContext.insert(sup)
            syncService.queueChange(
                table: "userSupplements", action: "upsert",
                data: [
                    "id": AnyCodable(sup.id), "supplementId": AnyCodable(def.id),
                    "dosage": AnyCodable(sup.dosage), "frequency": AnyCodable("daily"),
                    "timeOfDay": AnyCodable("morning"), "isActive": AnyCodable(true),
                ],
                modelContext: modelContext
            )
        }
        dismiss()
    }
}
```

Note: The old version wrapped itself in a `NavigationStack`. Since `BrowseSupplementsSheet` pushes to this view via `NavigationLink` inside its own `NavigationStack`, the wrapping `NavigationStack` is removed to avoid double navigation bars.

- [ ] **Step 2: Delete `NamahWellness/Views/Nutrition/SupplementsView.swift`**

```bash
git rm NamahWellness/Views/Nutrition/SupplementsView.swift
```

- [ ] **Step 3: Regenerate Xcode project and build**

```bash
xcodegen generate
xcodebuild -project NamahWellness.xcodeproj -scheme NamahWellness -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add NamahWellness/Views/Components/AddCustomSupplementView.swift
git commit -m "refactor: move AddCustomSupplementView to Components, delete dead SupplementsView

SupplementsView was never referenced — PlanSupplementsView replaced it.
AddCustomSupplementView is used by BrowseSupplementsSheet so it gets
its own file. Added sync support for custom supplement creation."
```

---

## Summary of Changes

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| Plan "Add" button does nothing | Browse sheet is a computed property — `@Query` changes don't propagate into presented sheet | Extract `BrowseSupplementsSheet` with own `@Query` |
| Today "Log Extra Supplement" doesn't open | `.sheet` attached to Button inside ScrollView | Move `.sheet` to NavigationStack level |
| Today log sheet may not update live | Same computed-property issue as browse sheet | Extract `LogSupplementSheet` with own `@Query` |
| Plan `toggleTaken` doesn't sync | Missing `syncService.queueChange` call | Add sync call matching TodayView pattern |
| Custom supplement not synced | `AddCustomSupplementView` missing sync calls | Add sync to `save()` |
| Dead code | `SupplementsView.swift` never used | Delete, move `AddCustomSupplementView` out |
