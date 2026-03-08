import SwiftUI

struct MealCardView: View {
    let meal: Meal
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isCompleted ? .phaseF : .muted.opacity(0.4))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    // Time + type
                    HStack(spacing: 8) {
                        Text(meal.time)
                            .font(.bodyMedium(9))
                            .foregroundStyle(.muted)
                            .textCase(.uppercase)
                            .tracking(1)
                        Text(meal.mealType)
                            .font(.bodyMedium(9))
                            .foregroundStyle(.muted.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1)
                    }

                    // Title
                    Text(meal.title)
                        .font(.bodyMedium(13))
                        .foregroundStyle(isCompleted ? .muted : .ink)
                        .strikethrough(isCompleted)

                    // Macros row
                    if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                        HStack(spacing: 6) {
                            MacroPill(label: "\(p)P", color: .macroProtein)
                            MacroPill(label: "\(c)C", color: .macroCarbs)
                            MacroPill(label: "\(f)F", color: .macroFat)
                            Text(meal.calories)
                                .font(.body(9))
                                .foregroundStyle(.muted.opacity(0.6))
                        }
                    }

                    // Description
                    if !meal.mealDescription.isEmpty {
                        Text(meal.mealDescription)
                            .font(.body(11))
                            .foregroundStyle(.muted)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .stroke(Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MacroPill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.bodyMedium(9))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
    }
}
