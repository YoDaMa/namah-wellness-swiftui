import SwiftUI

struct MealCardView: View {
    let meal: Meal
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isCompleted ? Color.phaseF : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(meal.time)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        Text(meal.mealType)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.tertiary)
                    }

                    Text(meal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)

                    if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                        HStack(spacing: 6) {
                            MacroPill(label: "\(p)P", color: .macroProtein)
                            MacroPill(label: "\(c)C", color: .macroCarbs)
                            MacroPill(label: "\(f)F", color: .macroFat)
                            Text(meal.calories)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if !meal.mealDescription.isEmpty {
                        Text(meal.mealDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct MacroPill: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
