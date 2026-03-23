import SwiftUI
import SwiftData

// MARK: - NourishView (Bento Grid)

struct NourishView: View {
    let phaseSlug: String
    let cycleService: CycleService
    let customItems: [UserPlanItem]
    let customGrocery: [UserPlanItem]
    let hiddenIds: Set<String>

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query private var phaseNutrients: [PhaseNutrient]
    @Query private var reminders: [PhaseReminder]
    @Query private var groceryItems: [GroceryItem]
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]

    @Query private var recipeIngredients: [RecipeIngredient]

    @State private var showNutrients = false
    @State private var showInsights = false
    @State private var showGroceryList = false
    @State private var showRecipeGroceryList = false

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }
    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    private var nutrientCount: Int {
        guard let id = phase?.id else { return 0 }
        return phaseNutrients.filter { $0.phaseId == id }.count
    }

    private var insightCount: Int {
        guard let id = phase?.id else { return 0 }
        return reminders.filter { $0.phaseId == id }.count
    }

    private var groceryCount: Int {
        guard let p = phase else { return customGrocery.count }
        let templateCount = groceryItems.filter { $0.phaseId == p.id && !hiddenIds.contains($0.id) }.count
        return templateCount + customGrocery.count
    }

    private var hasMeals: Bool {
        guard let p = phase else { return false }
        return allMeals.contains { $0.phaseId == p.id && $0.proteinG != nil }
    }

    private var phaseMealIds: Set<String> {
        guard let p = phase else { return [] }
        return Set(allMeals.filter { $0.phaseId == p.id }.map(\.id))
    }

    private var aggregatedIngredients: [(name: String, quantities: [String])] {
        let phaseIngredients = recipeIngredients.filter { phaseMealIds.contains($0.mealId) }
        var grouped: [String: [String]] = [:]
        for ing in phaseIngredients {
            let key = ing.name.lowercased()
            let qty = [ing.quantity, ing.unit].compactMap { $0 }.joined(separator: " ")
            grouped[key, default: []].append(qty)
        }
        return grouped.keys.sorted().map { key in
            let quantities = grouped[key]!.filter { !$0.isEmpty }
            let displayName = recipeIngredients.first { $0.name.lowercased() == key }?.name ?? key
            return (name: displayName, quantities: quantities)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            bentoGrid

            // Recipe Groceries — full-width tile
            if !aggregatedIngredients.isEmpty {
                Button { showRecipeGroceryList = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "basket")
                            .font(.sans(18))
                            .foregroundStyle(phaseColors.color)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recipe Groceries")
                                .font(.nSubheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("\(aggregatedIngredients.count) unique ingredients from all meals")
                                .font(.nCaption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.nCaption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            // FOR YOU callout
            if let p = phase, !p.saNote.isEmpty {
                SACalloutView(text: p.saNote)
            }
        }
        .sheet(isPresented: $showRecipeGroceryList) {
            RecipeGroceryListView(
                ingredients: aggregatedIngredients,
                phaseSlug: phaseSlug,
                phaseColor: phaseColors.color
            )
        }
        .sheet(isPresented: $showNutrients) {
            NutrientSheetView(phaseSlug: phaseSlug)
        }
        .sheet(isPresented: $showInsights) {
            InsightsSheetView(phaseSlug: phaseSlug)
        }
        .sheet(isPresented: $showGroceryList) {
            GroceryListView(phaseSlug: phaseSlug, phaseColor: phaseColors.color)
        }
    }

    // MARK: - Bento Grid (2×2)

    private var bentoGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            // Key Nutrients → sheet
            bentoTile(
                icon: "leaf",
                label: "Key Nutrients",
                preview: nutrientCount > 0 ? "\(nutrientCount) nutrients" : nil,
                color: phaseColors
            ) {
                showNutrients = true
            }

            // Meal Plan → pushed full screen
            NavigationLink {
                MealPlanView(phaseSlug: phaseSlug)
            } label: {
                bentoTileContent(
                    icon: "fork.knife",
                    label: "Meal Plan",
                    preview: hasMeals ? "View meals" : nil,
                    color: phaseColors
                )
            }
            .buttonStyle(.plain)

            // Phase Insights → sheet
            bentoTile(
                icon: "brain.head.profile",
                label: "Phase Insights",
                preview: insightCount > 0 ? "\(insightCount) insights" : nil,
                color: phaseColors
            ) {
                showInsights = true
            }

            // Grocery List → sheet
            bentoTile(
                icon: "bag",
                label: "Grocery List",
                preview: groceryCount > 0 ? "\(groceryCount) items" : nil,
                color: phaseColors
            ) {
                showGroceryList = true
            }
        }
    }

    // MARK: - Bento Tile (button variant)

    private func bentoTile(
        icon: String,
        label: String,
        preview: String?,
        color: PhaseColors,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            bentoTileContent(icon: icon, label: label, preview: preview, color: color)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bento Tile Content

    private func bentoTileContent(
        icon: String,
        label: String,
        preview: String?,
        color: PhaseColors
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.sans(20))
                .foregroundStyle(color.color)

            Spacer(minLength: 0)

            Text(label)
                .font(.nSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            if let preview {
                Text(preview)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(color.soft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
