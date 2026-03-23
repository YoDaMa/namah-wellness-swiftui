import SwiftUI
import SwiftData

/// Grocery list derived from RecipeIngredients for the current phase.
/// Supports "By Meal" and "By Category" grouping with synchronized check state.
///
/// Data flow:
///   RecipeIngredient (per-meal) → grouped by meal or category
///   GroceryCheck (groceryItemId = RecipeIngredient.id) → shared check state
///   Checking in GroceryListView ↔ checking in MealDetailView (same GroceryCheck)
///
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

    private var phaseMeals: [Meal] {
        guard let p = phase else { return [] }
        return allMeals.filter { $0.phaseId == p.id && $0.proteinG != nil }
    }

    private var phaseMealIds: Set<String> {
        Set(phaseMeals.map(\.id))
    }

    private var phaseIngredients: [RecipeIngredient] {
        allIngredients.filter { phaseMealIds.contains($0.mealId) }
    }

    private var checkedIds: Set<String> {
        Set(groceryChecks.filter(\.checked).map(\.groceryItemId))
    }

    private var totalCount: Int { phaseIngredients.count }
    private var checkedCount: Int { phaseIngredients.filter { checkedIds.contains($0.id) }.count }
    private var progress: Double { totalCount == 0 ? 0 : Double(checkedCount) / Double(totalCount) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    headerSection

                    // Group mode picker
                    Picker("Group by", selection: $groupMode) {
                        ForEach(GroupMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Content
                    switch groupMode {
                    case .byMeal:
                        byMealContent
                    case .byCategory:
                        byCategoryContent
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
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bag")
                    .font(.sans(16))
                    .foregroundStyle(phaseColor)
                Text(phase?.name ?? "")
                    .font(.nCaption)
                    .fontWeight(.bold)
                    .foregroundStyle(phaseColor)
                Spacer()
                if checkedCount > 0 {
                    Button("Reset") { resetAll() }
                        .font(.nCaption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("\(checkedCount) of \(totalCount) items")
                    .font(.nCaption)
                    .fontWeight(.medium)
                Spacer()
            }

            ProgressView(value: progress)
                .tint(phaseColor)
        }
        .padding(16)
        .background(phaseColors.soft)
    }

    // MARK: - By Meal

    private var byMealContent: some View {
        ForEach(phaseMeals, id: \.id) { meal in
            let mealIngredients = phaseIngredients.filter { $0.mealId == meal.id }
            if !mealIngredients.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // Meal title header
                    HStack(spacing: 6) {
                        Text(meal.mealType.uppercased())
                            .font(.nCaption2)
                            .fontWeight(.semibold)
                            .tracking(1.5)
                            .foregroundStyle(phaseColor)
                        Text("·").foregroundStyle(.tertiary)
                        Text(meal.title)
                            .font(.nCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(phaseColor.opacity(0.06))

                    // Ingredients
                    ForEach(mealIngredients, id: \.id) { ingredient in
                        ingredientRow(ingredient)
                    }
                }
            }
        }
    }

    // MARK: - By Category

    private let categories = ["Protein", "Produce", "Pantry / Grains", "Other"]

    private var byCategoryContent: some View {
        ForEach(categories, id: \.self) { category in
            let catIngredients = deduplicatedIngredients(for: category)
            if !catIngredients.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(category.uppercased())
                        .font(.nCaption2)
                        .fontWeight(.semibold)
                        .tracking(2)
                        .foregroundStyle(phaseColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(phaseColor.opacity(0.06))

                    ForEach(catIngredients, id: \.name) { item in
                        deduplicatedRow(item)
                    }
                }
            }
        }
    }

    // MARK: - Deduplication for Category View

    private struct DeduplicatedItem {
        let name: String
        let ingredientIds: [String]
        let quantities: [String]
        let allChecked: Bool
    }

    private func deduplicatedIngredients(for category: String) -> [DeduplicatedItem] {
        let matching = phaseIngredients.filter { ($0.category ?? "Other") == category }
        var grouped: [String: [RecipeIngredient]] = [:]
        for ing in matching {
            grouped[ing.name.lowercased(), default: []].append(ing)
        }
        return grouped.keys.sorted().map { key in
            let items = grouped[key]!
            let ids = items.map(\.id)
            let qtys = items.compactMap { ing -> String? in
                let q = [ing.quantity, ing.unit].compactMap { $0 }.joined(separator: " ")
                return q.isEmpty ? nil : q
            }
            let allChecked = ids.allSatisfy { checkedIds.contains($0) }
            let displayName = items.first?.name ?? key
            return DeduplicatedItem(name: displayName, ingredientIds: ids, quantities: qtys, allChecked: allChecked)
        }
    }

    // MARK: - Rows

    private func ingredientRow(_ ingredient: RecipeIngredient) -> some View {
        let isChecked = checkedIds.contains(ingredient.id)
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
                        let summary = Array(Set(item.quantities)).sorted().joined(separator: ", ")
                        Text(summary)
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

    // MARK: - Share

    private var shareText: String {
        var text = "Grocery List — \(phase?.name ?? "") Phase\n\n"
        for meal in phaseMeals {
            let mealIngredients = phaseIngredients.filter { $0.mealId == meal.id }
            if !mealIngredients.isEmpty {
                text += "\(meal.mealType): \(meal.title)\n"
                for ing in mealIngredients {
                    let check = checkedIds.contains(ing.id) ? "✓" : "○"
                    let qty = [ing.quantity, ing.unit].compactMap { $0 }.joined(separator: " ")
                    text += "  \(check) \(qty.isEmpty ? ing.name : "\(qty) \(ing.name)")\n"
                }
                text += "\n"
            }
        }
        return text
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

    private func resetAll() {
        let visibleIds = Set(phaseIngredients.map(\.id))
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
