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
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query(sort: \RecipeIngredient.sortOrder) private var recipeIngredients: [RecipeIngredient]

    @State private var showNutrients = false
    @State private var showInsights = false
    @State private var showGroceryList = false

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
        guard let p = phase else { return 0 }
        let mealIds = Set(allMeals.filter { $0.phaseId == p.id }.map(\.id))
        return recipeIngredients.filter { mealIds.contains($0.mealId) }.count
    }

    private var hasMeals: Bool {
        guard let p = phase else { return false }
        return allMeals.contains { $0.phaseId == p.id && $0.proteinG != nil }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            bentoGrid

            // FOR YOU callout
            if let p = phase, !p.saNote.isEmpty {
                SACalloutView(text: p.saNote)
            }
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
