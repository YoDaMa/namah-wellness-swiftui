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
    @State private var shareContent = ""

    // MARK: - Derived data (computed once, not per-row)

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }
    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    private var checkedIds: Set<String> {
        Set(groceryChecks.filter(\.checked).map(\.groceryItemId))
    }

    // Pre-grouped meal data to avoid repeated filtering in ForEach
    private var mealGroups: [(meal: Meal, ingredients: [RecipeIngredient])] {
        guard let p = phase else { return [] }
        let meals = allMeals.filter { $0.phaseId == p.id && $0.proteinG != nil }
        let mealIds = Set(meals.map(\.id))
        let ingredients = allIngredients.filter { mealIds.contains($0.mealId) }
        let byMeal = Dictionary(grouping: ingredients, by: \.mealId)
        return meals.compactMap { meal in
            guard let ings = byMeal[meal.id], !ings.isEmpty else { return nil }
            return (meal: meal, ingredients: ings)
        }
    }

    private var allPhaseIngredientIds: Set<String> {
        Set(mealGroups.flatMap { $0.ingredients.map(\.id) })
    }

    private var totalCount: Int { allPhaseIngredientIds.count }

    private var checkedCount: Int {
        allPhaseIngredientIds.intersection(checkedIds).count
    }

    private var progress: Double {
        totalCount == 0 ? 0 : Double(checkedCount) / Double(totalCount)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    headerSection

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
                    Button {
                        shareContent = buildShareText()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .sheet(isPresented: .init(
                        get: { !shareContent.isEmpty },
                        set: { if !$0 { shareContent = "" } }
                    )) {
                        if #available(iOS 16.4, *) {
                            ShareLink(item: shareContent) {
                                Text("Share Grocery List")
                            }
                            .presentationDetents([.medium])
                        }
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

    // MARK: - By Meal (uses pre-grouped data)

    private var byMealContent: some View {
        ForEach(mealGroups, id: \.meal.id) { group in
            Section {
                ForEach(group.ingredients, id: \.id) { ingredient in
                    ingredientRow(ingredient)
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

    // MARK: - By Category (uses pre-grouped data)

    private let categories = ["Protein", "Produce", "Pantry / Grains", "Other"]

    private var categoryGroups: [(category: String, items: [DeduplicatedItem])] {
        let allIngredients = mealGroups.flatMap(\.ingredients)
        var byCat: [String: [String: [RecipeIngredient]]] = [:]
        for ing in allIngredients {
            let cat = ing.category ?? "Other"
            byCat[cat, default: [:]][ing.name.lowercased(), default: []].append(ing)
        }
        return categories.compactMap { cat in
            guard let grouped = byCat[cat], !grouped.isEmpty else { return nil }
            let items = grouped.keys.sorted().map { key -> DeduplicatedItem in
                let ings = grouped[key]!
                let ids = ings.map(\.id)
                let qtys = ings.compactMap { i -> String? in
                    let q = [i.quantity, i.unit].compactMap { $0 }.joined(separator: " ")
                    return q.isEmpty ? nil : q
                }
                return DeduplicatedItem(
                    name: ings.first?.name ?? key,
                    ingredientIds: ids,
                    quantities: Array(Set(qtys)).sorted(),
                    allChecked: ids.allSatisfy { checkedIds.contains($0) }
                )
            }
            return (category: cat, items: items)
        }
    }

    private var byCategoryContent: some View {
        ForEach(categoryGroups, id: \.category) { group in
            Section {
                ForEach(group.items, id: \.name) { item in
                    deduplicatedRow(item)
                }
            } header: {
                Text(group.category.uppercased())
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

    private struct DeduplicatedItem {
        let name: String
        let ingredientIds: [String]
        let quantities: [String]
        let allChecked: Bool
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

    // MARK: - Share (built on demand, not eagerly)

    private func buildShareText() -> String {
        var text = "Grocery List — \(phase?.name ?? "") Phase\n\n"
        for group in mealGroups {
            text += "\(group.meal.mealType): \(group.meal.title)\n"
            for ing in group.ingredients {
                let check = checkedIds.contains(ing.id) ? "✓" : "○"
                let qty = [ing.quantity, ing.unit].compactMap { $0 }.joined(separator: " ")
                text += "  \(check) \(qty.isEmpty ? ing.name : "\(qty) \(ing.name)")\n"
            }
            text += "\n"
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
        let visibleIds = allPhaseIngredientIds
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
