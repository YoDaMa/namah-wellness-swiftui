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
        HStack(spacing: 0) {
            summaryItem("\(totalCalories)", "CAL")
            Divider().frame(height: 24)
            summaryItem("\(totalProtein)g", "PROTEIN")
            Divider().frame(height: 24)
            summaryItem("\(totalCarbs)g", "CARBS")
            Divider().frame(height: 24)
            summaryItem("\(totalFat)g", "FAT")
            Divider().frame(height: 24)
            summaryItem("\(completionPercent)%", "DONE")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.nFootnote)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Text(label)
                .font(.sans(8)).fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
