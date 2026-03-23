import SwiftUI
import SwiftData

/// Grocery list derived from RecipeIngredients for the current phase.
/// Supports "By Meal" and "By Category" grouping with synchronized check state.
struct GroceryListView: View {
    let phaseSlug: String
    let phaseColor: Color

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @Query private var phases: [Phase]
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query(sort: \RecipeIngredient.sortOrder) private var allIngredients: [RecipeIngredient]
    @Query private var groceryChecks: [GroceryCheck]

    enum GroupMode: String, CaseIterable {
        case byMeal = "By Meal"
        case byCategory = "By Category"
    }

    @State private var groupMode: GroupMode = .byMeal

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }
    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    // Single computed snapshot — everything derived from @Query in one pass
    private var snapshot: GrocerySnapshot {
        let checked = Set(groceryChecks.filter(\.checked).map(\.groceryItemId))
        guard let p = phase else {
            return GrocerySnapshot(mealGroups: [], checkedIds: checked, uniqueCount: 0, checkedUniqueCount: 0)
        }
        let meals = allMeals.filter { $0.phaseId == p.id && $0.proteinG != nil }
        let mealIds = Set(meals.map(\.id))
        let ingredients = allIngredients.filter { mealIds.contains($0.mealId) }
        let byMeal = Dictionary(grouping: ingredients, by: \.mealId)
        let groups = meals.compactMap { meal -> MealGroup? in
            guard let ings = byMeal[meal.id], !ings.isEmpty else { return nil }
            return MealGroup(meal: meal, ingredients: ings)
        }

        let byName = Dictionary(grouping: ingredients, by: { $0.name.lowercased() })
        let uniqueCount = byName.count
        let checkedUniqueCount = byName.values.filter { ings in
            ings.allSatisfy { checked.contains($0.id) }
        }.count

        return GrocerySnapshot(
            mealGroups: groups,
            checkedIds: checked,
            uniqueCount: uniqueCount,
            checkedUniqueCount: checkedUniqueCount
        )
    }

    var body: some View {
        let snap = snapshot
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    headerSection(snap)

                    Picker("Group by", selection: $groupMode) {
                        ForEach(GroupMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    switch groupMode {
                    case .byMeal:
                        byMealContent(snap)
                    case .byCategory:
                        byCategoryContent(snap)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Grocery List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private func headerSection(_ snap: GrocerySnapshot) -> some View {
        let progress = snap.uniqueCount == 0 ? 0.0 : Double(snap.checkedUniqueCount) / Double(snap.uniqueCount)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bag")
                    .font(.sans(16))
                    .foregroundStyle(phaseColor)
                Text(phase?.name ?? "")
                    .font(.nCaption)
                    .fontWeight(.bold)
                    .foregroundStyle(phaseColor)
                Spacer()
                if snap.checkedUniqueCount > 0 {
                    Button("Reset") { resetAll(snap) }
                        .font(.nCaption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(snap.checkedUniqueCount) of \(snap.uniqueCount) items")
                .font(.nCaption)
                .fontWeight(.medium)

            ProgressView(value: progress)
                .tint(phaseColor)
        }
        .padding(16)
        .background(phaseColors.soft)
    }

    // MARK: - By Meal

    private func byMealContent(_ snap: GrocerySnapshot) -> some View {
        ForEach(snap.mealGroups) { group in
            Section {
                ForEach(group.ingredients, id: \.id) { ingredient in
                    ingredientRow(ingredient, checked: snap.checkedIds)
                }
            } header: {
                HStack(spacing: 6) {
                    Text(group.meal.mealType.uppercased())
                        .font(.nCaption2)
                        .fontWeight(.semibold)
                        .tracking(1.5)
                        .foregroundStyle(phaseColor)
                    Text("·").foregroundStyle(.tertiary)
                    Text(group.meal.title)
                        .font(.nCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(phaseColor.opacity(0.06))
            }
        }
    }

    // MARK: - By Category

    private let categories = ["Protein", "Produce", "Pantry / Grains", "Other"]

    private func byCategoryContent(_ snap: GrocerySnapshot) -> some View {
        let allIngs = snap.mealGroups.flatMap(\.ingredients)
        var byCat: [String: [String: [RecipeIngredient]]] = [:]
        for ing in allIngs {
            byCat[ing.category ?? "Other", default: [:]][ing.name.lowercased(), default: []].append(ing)
        }

        return ForEach(categories, id: \.self) { category in
            if let grouped = byCat[category], !grouped.isEmpty {
                let items = grouped.keys.sorted().map { key -> DeduplicatedItem in
                    let ings = grouped[key]!
                    let ids = ings.map(\.id)
                    let qtys = Array(Set(ings.compactMap { i -> String? in
                        let q = [i.quantity, i.unit].compactMap { $0 }.joined(separator: " ")
                        return q.isEmpty ? nil : q
                    })).sorted()
                    return DeduplicatedItem(
                        name: ings.first?.name ?? key,
                        ingredientIds: ids,
                        quantities: qtys,
                        allChecked: ids.allSatisfy { snap.checkedIds.contains($0) }
                    )
                }

                Section {
                    ForEach(items, id: \.name) { item in
                        deduplicatedRow(item)
                    }
                } header: {
                    Text(category.uppercased())
                        .font(.nCaption2)
                        .fontWeight(.semibold)
                        .tracking(2)
                        .foregroundStyle(phaseColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(phaseColor.opacity(0.06))
                }
            }
        }
    }

    // MARK: - Data Types

    private struct GrocerySnapshot {
        let mealGroups: [MealGroup]
        let checkedIds: Set<String>
        let uniqueCount: Int
        let checkedUniqueCount: Int
    }

    private struct DeduplicatedItem {
        let name: String
        let ingredientIds: [String]
        let quantities: [String]
        let allChecked: Bool
    }

    // MARK: - Rows

    private func ingredientRow(_ ingredient: RecipeIngredient, checked: Set<String>) -> some View {
        let isChecked = checked.contains(ingredient.id)
        return Button { toggleIngredient(ingredient) } label: {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(isChecked ? phaseColor : Color(uiColor: .tertiaryLabel))

                VStack(alignment: .leading, spacing: 1) {
                    Text(ingredient.name)
                        .font(.nSubheadline)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                        .strikethrough(isChecked)

                    let qty = [ingredient.quantity, ingredient.unit].compactMap { $0 }.joined(separator: " ")
                    if !qty.isEmpty {
                        Text(qty)
                            .font(.nCaption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func deduplicatedRow(_ item: DeduplicatedItem) -> some View {
        Button { toggleDeduplicatedItem(item) } label: {
            HStack(spacing: 10) {
                Image(systemName: item.allChecked ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(item.allChecked ? phaseColor : Color(uiColor: .tertiaryLabel))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.nSubheadline)
                        .foregroundStyle(item.allChecked ? .secondary : .primary)
                        .strikethrough(item.allChecked)

                    if !item.quantities.isEmpty {
                        Text(item.quantities.joined(separator: ", "))
                            .font(.nCaption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if item.ingredientIds.count > 1 {
                    Text("×\(item.ingredientIds.count)")
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleIngredient(_ ingredient: RecipeIngredient) {
        if let existing = groceryChecks.first(where: { $0.groceryItemId == ingredient.id }) {
            existing.checked.toggle()
            existing.updatedAt = Date()
            syncService.queueChange(
                table: "groceryChecks", action: "upsert",
                data: ["id": existing.id, "groceryItemId": ingredient.id, "checked": existing.checked],
                modelContext: modelContext
            )
        } else {
            let check = GroceryCheck(groceryItemId: ingredient.id, checked: true)
            modelContext.insert(check)
            syncService.queueChange(
                table: "groceryChecks", action: "upsert",
                data: ["id": check.id, "groceryItemId": ingredient.id, "checked": true],
                modelContext: modelContext
            )
        }
    }

    private func toggleDeduplicatedItem(_ item: DeduplicatedItem) {
        let newState = !item.allChecked
        for ingredientId in item.ingredientIds {
            if let existing = groceryChecks.first(where: { $0.groceryItemId == ingredientId }) {
                existing.checked = newState
                existing.updatedAt = Date()
                syncService.queueChange(
                    table: "groceryChecks", action: "upsert",
                    data: ["id": existing.id, "groceryItemId": ingredientId, "checked": newState],
                    modelContext: modelContext
                )
            } else if newState {
                let check = GroceryCheck(groceryItemId: ingredientId, checked: true)
                modelContext.insert(check)
                syncService.queueChange(
                    table: "groceryChecks", action: "upsert",
                    data: ["id": check.id, "groceryItemId": ingredientId, "checked": true],
                    modelContext: modelContext
                )
            }
        }
    }

    private func resetAll(_ snap: GrocerySnapshot) {
        let visibleIds = Set(snap.mealGroups.flatMap { $0.ingredients.map(\.id) })
        for check in groceryChecks where check.checked && visibleIds.contains(check.groceryItemId) {
            check.checked = false
            check.updatedAt = Date()
            syncService.queueChange(
                table: "groceryChecks", action: "upsert",
                data: ["id": check.id, "groceryItemId": check.groceryItemId, "checked": false],
                modelContext: modelContext
            )
        }
    }
}

// Identifiable wrapper for ForEach
private struct MealGroup: Identifiable {
    let meal: Meal
    let ingredients: [RecipeIngredient]
    var id: String { meal.id }
}
