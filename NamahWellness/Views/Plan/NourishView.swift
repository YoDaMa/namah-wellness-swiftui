import SwiftUI
import SwiftData

// MARK: - NourishView (Bento Grid)

struct NourishView: View {
    let phaseSlug: String
    let cycleService: CycleService
    let customItems: [Habit]
    let customGrocery: [Habit]
    let hiddenIds: Set<String>

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query(sort: \RecipeIngredient.sortOrder) private var recipeIngredients: [RecipeIngredient]
    @Query private var userSupplements: [UserSupplement]
    @Query private var medications: [Habit]

    @State private var showGroceryList = false

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }
    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    private var groceryCount: Int {
        guard let p = phase else { return 0 }
        let mealIds = Set(allMeals.filter { $0.phaseId == p.id }.map(\.id))
        let names = Set(recipeIngredients.filter { mealIds.contains($0.mealId) }.map { $0.name.lowercased() })
        return names.count
    }

    private var hasMeals: Bool {
        guard let p = phase else { return false }
        return allMeals.contains { $0.phaseId == p.id && $0.proteinG != nil }
    }

    private var activeSupplementCount: Int {
        userSupplements.filter { $0.isActive && !$0.isMedication }.count
    }

    private var activeMedicationCount: Int {
        medications.filter { $0.category == .medication && $0.isActive }.count
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
        .sheet(isPresented: $showGroceryList) {
            GroceryListView(phaseSlug: phaseSlug, phaseColor: phaseColors.color)
        }
    }

    // MARK: - Bento Grid (2×2)

    private var bentoGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            // Meal Plan
            NavigationLink {
                MealPlanView(phaseSlug: phaseSlug)
            } label: {
                BentoTile(
                    icon: "fork.knife",
                    label: "Meal Plan",
                    preview: hasMeals ? "View meals" : "Get started",
                    accentColor: phaseColors.color
                )
            }
            .buttonStyle(BentoButtonStyle())

            // Grocery List
            Button { showGroceryList = true } label: {
                BentoTile(
                    icon: "bag.fill",
                    label: "Grocery List",
                    preview: groceryCount > 0 ? "\(groceryCount) items" : "View list",
                    accentColor: phaseColors.color
                )
            }
            .buttonStyle(BentoButtonStyle())

            // Supplements
            NavigationLink {
                PlanSupplementsView()
            } label: {
                BentoTile(
                    icon: "pill.fill",
                    label: "Supplements",
                    preview: activeSupplementCount > 0 ? "\(activeSupplementCount) active" : "Browse library",
                    accentColor: phaseColors.color
                )
            }
            .buttonStyle(BentoButtonStyle())

            // Medications
            NavigationLink {
                MedicationsView(phaseSlug: phaseSlug)
            } label: {
                BentoTile(
                    icon: "pills.fill",
                    label: "Medications",
                    preview: activeMedicationCount > 0 ? "\(activeMedicationCount) active" : "Add meds",
                    accentColor: phaseColors.color
                )
            }
            .buttonStyle(BentoButtonStyle())
        }
    }
}

// MARK: - Bento Tile

private struct BentoTile: View {
    let icon: String
    let label: String
    let preview: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon badge
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor)
                )

            Spacer(minLength: 16)

            // Label + chevron
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.nSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                HStack(spacing: 0) {
                    Text(preview)
                        .font(.nCaption2)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .shadow(color: .black.opacity(0.02), radius: 2, y: 1)
    }
}

// MARK: - Bento Button Style

private struct BentoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
