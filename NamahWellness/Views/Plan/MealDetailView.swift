import SwiftUI
import SwiftData

struct MealDetailView: View {
    let meal: any MealDisplayable
    let mealId: String
    let phaseSlug: String
    let phaseColor: Color

    @Query private var recipeIngredients: [RecipeIngredient]
    @Query private var groceryChecks: [GroceryCheck]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    init(meal: any MealDisplayable, mealId: String, phaseSlug: String, phaseColor: Color) {
        self.meal = meal
        self.mealId = mealId
        self.phaseSlug = phaseSlug
        self.phaseColor = phaseColor
        _recipeIngredients = Query(
            filter: #Predicate<RecipeIngredient> { $0.mealId == mealId },
            sort: \RecipeIngredient.sortOrder
        )
    }

    private var ingredients: [Ingredient] {
        if !meal.isCustomMeal {
            return recipeIngredients.map { $0.toIngredient() }
        } else if let custom = meal as? Habit {
            return custom.decodedIngredients
        }
        return []
    }

    private var hasRecipe: Bool {
        !ingredients.isEmpty || !meal.steps.isEmpty
    }

    private var checkedIds: Set<String> {
        Set(groceryChecks.filter(\.checked).map(\.groceryItemId))
    }

    private var shareText: String {
        var lines = [meal.title, ""]
        if let mt = meal.displayMealType, let t = meal.displayTime {
            lines.append("\(mt) · \(t)")
        }
        if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
            lines.append("\(p)P · \(c)C · \(f)F")
        }
        if !ingredients.isEmpty {
            lines.append("")
            lines.append("INGREDIENTS")
            for ing in ingredients {
                let qty = ing.displayQuantity
                lines.append(qty.isEmpty ? "• \(ing.name)" : "• \(qty) \(ing.name)")
            }
        }
        if !meal.steps.isEmpty {
            lines.append("")
            lines.append("STEPS")
            for (i, step) in meal.steps.enumerated() {
                lines.append("\(i + 1). \(step)")
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Macros
                if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                    macrosBar(p: p, c: c, f: f)
                }

                // Description
                if let desc = meal.displayDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.prose(14))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }

                // SA Note
                if let note = meal.displaySaNote, !note.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("✦")
                            .foregroundStyle(phaseColor)
                        Text(note)
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    .padding(12)
                    .background(phaseColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Recipe content
                if hasRecipe {
                    if !ingredients.isEmpty {
                        ingredientsSection
                    }
                    if !meal.steps.isEmpty {
                        stepsSection
                    }
                } else {
                    emptyRecipeState
                }
            }
            .padding()
        }
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, .white)
                }
            }
            if hasRecipe {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let mt = meal.displayMealType {
                    Text(mt.uppercased())
                        .font(.nCaption2)
                        .fontWeight(.semibold)
                        .tracking(1.5)
                        .foregroundStyle(phaseColor)
                }
                if let t = meal.displayTime {
                    Text("·").foregroundStyle(.tertiary)
                    Text(t.uppercased())
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                if meal.isCustomMeal {
                    Text("CUSTOM")
                        .font(.sans(7))
                        .fontWeight(.bold)
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(phaseColor)
                        .clipShape(Capsule())
                }
            }

            Text(meal.title)
                .font(.display(22))
                .foregroundStyle(.primary)

            if let cal = meal.displayCalories {
                Text(cal)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Macros Bar

    private func macrosBar(p: Int, c: Int, f: Int) -> some View {
        HStack(spacing: 16) {
            macroItem("Protein", value: "\(p)g", color: phaseColor)
            macroItem("Carbs", value: "\(c)g", color: phaseColor.opacity(0.7))
            macroItem("Fat", value: "\(f)g", color: phaseColor.opacity(0.5))
        }
        .padding(14)
        .background(phaseColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func macroItem(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.nSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.nCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ingredients (checkable, synced with GroceryListView)

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INGREDIENTS")
                .font(.nCaption2)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                if !meal.isCustomMeal {
                    // Template meals — use RecipeIngredient IDs for check state
                    ForEach(recipeIngredients, id: \.id) { ing in
                        let isChecked = checkedIds.contains(ing.id)
                        Button { toggleIngredientCheck(ing) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.sans(16))
                                    .foregroundStyle(isChecked ? phaseColor : Color(uiColor: .tertiaryLabel))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ing.name)
                                        .font(.sans(14))
                                        .foregroundStyle(isChecked ? .secondary : .primary)
                                        .strikethrough(isChecked)

                                    let qty = [ing.quantity, ing.unit].compactMap { $0 }.joined(separator: " ")
                                    if !qty.isEmpty {
                                        Text(qty)
                                            .font(.nCaption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Custom meals — display-only (no RecipeIngredient IDs to check)
                    ForEach(ingredients) { ing in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(phaseColor.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            HStack(spacing: 0) {
                                if !ing.displayQuantity.isEmpty {
                                    Text(ing.displayQuantity)
                                        .fontWeight(.medium)
                                    Text(" ")
                                }
                                Text(ing.name)
                            }
                            .font(.sans(14))
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }

    private func toggleIngredientCheck(_ ingredient: RecipeIngredient) {
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

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STEPS")
                .font(.nCaption2)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(meal.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.nCaption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(phaseColor)
                            .clipShape(Circle())

                        Text(step)
                            .font(.sans(14))
                            .foregroundStyle(.primary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyRecipeState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            if meal.isCustomMeal {
                Text("No recipe yet")
                    .font(.nSubheadline)
                    .foregroundStyle(.secondary)
                Text("Add ingredients and steps to this meal")
                    .font(.nCaption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Recipe coming soon")
                    .font(.nSubheadline)
                    .foregroundStyle(.secondary)
                Text("Full recipe with ingredients and steps will be available shortly")
                    .font(.nCaption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

}
