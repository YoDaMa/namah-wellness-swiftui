import SwiftUI

struct MacroSummaryBar: View {
    let meals: [Meal]
    let completedIds: Set<String>

    private var totalCalories: Int {
        meals.compactMap { meal in
            let num = meal.calories.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            return Int(num)
        }.reduce(0, +)
    }

    private var totalProtein: Int { meals.compactMap(\.proteinG).reduce(0, +) }
    private var totalCarbs: Int { meals.compactMap(\.carbsG).reduce(0, +) }
    private var totalFat: Int { meals.compactMap(\.fatG).reduce(0, +) }

    private var completionPercent: Int {
        guard !meals.isEmpty else { return 0 }
        let done = meals.filter { completedIds.contains($0.id) }.count
        return Int(Double(done) / Double(meals.count) * 100)
    }

    var body: some View {
        HStack(spacing: 16) {
            macroItem(value: "\(totalCalories)", label: "CAL")
            divider
            macroItem(value: "\(totalProtein)g", label: "P", color: .macroProtein)
            divider
            macroItem(value: "\(totalCarbs)g", label: "C", color: .macroCarbs)
            divider
            macroItem(value: "\(totalFat)g", label: "F", color: .macroFat)
            Spacer()
            Text("\(completionPercent)%")
                .font(.bodyMedium(11))
                .foregroundStyle(.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.warm)
    }

    private func macroItem(value: String, label: String, color: Color = .ink) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.bodyMedium(11))
                .foregroundStyle(color)
            Text(label)
                .font(.bodyMedium(8))
                .foregroundStyle(.muted)
                .textCase(.uppercase)
                .tracking(1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 1, height: 14)
    }
}
