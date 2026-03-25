import SwiftUI

/// Presentational meal card body — no Button wrapping.
/// Callers compose interaction (tap gesture, swipe wrapper, etc.)
struct MealCardContent: View {
    let title: String
    let time: String?
    let mealType: String?
    let proteinG: Int?
    let carbsG: Int?
    let fatG: Int?
    let calories: String?
    let subtitle: String?
    let isCompleted: Bool
    let isCustom: Bool
    let phaseColor: Color?

    init(meal: Meal, isCompleted: Bool) {
        self.title = meal.title
        self.time = meal.time
        self.mealType = meal.mealType
        self.proteinG = meal.proteinG
        self.carbsG = meal.carbsG
        self.fatG = meal.fatG
        self.calories = meal.calories
        self.subtitle = nil
        self.isCompleted = isCompleted
        self.isCustom = false
        self.phaseColor = nil
    }

    init(customItem: Habit, isCompleted: Bool, phaseColor: Color) {
        self.title = customItem.title
        self.time = customItem.time
        self.mealType = customItem.mealType
        self.proteinG = customItem.proteinG
        self.carbsG = customItem.carbsG
        self.fatG = customItem.fatG
        self.calories = nil
        self.subtitle = customItem.subtitle
        self.isCompleted = isCompleted
        self.isCustom = true
        self.phaseColor = phaseColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.sans(18))
                .foregroundStyle(isCompleted ? (phaseColor ?? .secondary) : isCustom ? Color(uiColor: .tertiaryLabel) : .primary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let time {
                        Text(time)
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                    if let mealType {
                        if time != nil {
                            Text("·").foregroundStyle(.tertiary)
                        }
                        Text(mealType)
                            .font(.nCaption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(.tertiary)
                    }
                    if isCustom, let color = phaseColor {
                        Text("CUSTOM")
                            .font(.sans(7))
                            .fontWeight(.bold)
                            .tracking(0.5)
                            .foregroundStyle(color)
                    }
                }

                Text(title)
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)

                if let sub = subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let p = proteinG, let c = carbsG, let f = fatG {
                    let base = "\(p)P · \(c)C · \(f)F"
                    let macroText = calories.map { "\(base) · \($0)" } ?? base
                    Text(macroText)
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(isCustom ? (phaseColor ?? Color.secondary).opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isCustom {
                RoundedRectangle(cornerRadius: 12)
                    .stroke((phaseColor ?? Color.secondary).opacity(0.2), lineWidth: 1)
            }
        }
        .sensoryFeedback(.success, trigger: isCompleted)
    }
}
