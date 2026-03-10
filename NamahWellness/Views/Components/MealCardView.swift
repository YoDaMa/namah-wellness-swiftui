import SwiftUI

struct MealCardView: View {
    let meal: Meal
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(meal.time)
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        Text(meal.mealType)
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.tertiary)
                    }

                    Text(meal.title)
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)

                    if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                        Text("\(p)P · \(c)C · \(f)F · \(meal.calories)")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
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