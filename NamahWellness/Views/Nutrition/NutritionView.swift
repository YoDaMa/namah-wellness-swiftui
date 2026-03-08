import SwiftUI
import SwiftData

struct NutritionView: View {
    let cycleService: CycleService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query private var meals: [Meal]
    @Query private var completions: [MealCompletion]

    @State private var selectedPhaseSlug: String?

    private var currentSlug: String {
        selectedPhaseSlug ?? cycleService.currentPhase?.phaseSlug ?? "menstrual"
    }

    private var selectedPhase: Phase? {
        phases.first { $0.slug == currentSlug }
    }

    private var phaseMeals: [Meal] {
        guard let phase = selectedPhase else { return [] }
        return meals
            .filter { $0.phaseId == phase.id }
            .sorted { ($0.dayNumber, $0.time) < ($1.dayNumber, $1.time) }
    }

    private var completedIds: Set<String> {
        Set(completions.map(\.mealId))
    }

    private var dayGroups: [(day: Int, label: String, calories: String?, meals: [Meal])] {
        let grouped = Dictionary(grouping: phaseMeals) { $0.dayNumber }
        return grouped.keys.sorted().map { day in
            let dayMeals = grouped[day]!
            return (day: day, label: dayMeals.first?.dayLabel ?? "Day \(day)", calories: dayMeals.first?.dayCalories, meals: dayMeals)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let phase = cycleService.currentPhase {
                        PhaseHeaderView(phase: phase)
                    }

                    Text("Nutrition")
                        .font(.heading(32))
                        .foregroundStyle(.ink)

                    // Phase selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(phases, id: \.id) { phase in
                                Button {
                                    selectedPhaseSlug = phase.slug
                                } label: {
                                    Text(phase.name)
                                        .font(.bodyMedium(10))
                                        .textCase(.uppercase)
                                        .tracking(1.2)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .foregroundStyle(currentSlug == phase.slug ? .white : .muted)
                                        .background(currentSlug == phase.slug ? Color(hex: phaseHex(phase.slug)) : .clear)
                                        .overlay(
                                            Rectangle()
                                                .stroke(currentSlug == phase.slug ? .clear : Color.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Phase info
                    if let phase = selectedPhase {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                macroTarget("P", phase.proteinTarget)
                                macroTarget("C", phase.carbTarget)
                                macroTarget("F", phase.fatTarget)
                                Spacer()
                                Text(phase.calorieTarget + " cal")
                                    .font(.bodyMedium(11))
                                    .foregroundStyle(.ink)
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .overlay(Rectangle().stroke(Color.border, lineWidth: 1))
                    }

                    // Macro summary
                    MacroSummaryBar(meals: phaseMeals, completedIds: completedIds)

                    // Day groups
                    ForEach(dayGroups, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(group.label)
                                    .font(.bodyMedium(9))
                                    .textCase(.uppercase)
                                    .tracking(2)
                                    .foregroundStyle(.ink)
                                if let cal = group.calories {
                                    Text(cal)
                                        .font(.body(9))
                                        .foregroundStyle(.muted)
                                }
                                Spacer()
                            }

                            ForEach(group.meals, id: \.id) { meal in
                                MealCardView(
                                    meal: meal,
                                    isCompleted: completedIds.contains(meal.id),
                                    onToggle: { toggleMeal(meal.id) }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.paper)
        }
    }

    private func macroTarget(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.bodyMedium(8))
                .foregroundStyle(.muted)
                .textCase(.uppercase)
                .tracking(1)
            Text(value)
                .font(.body(11))
                .foregroundStyle(.ink)
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func toggleMeal(_ mealId: String) {
        if let existing = completions.first(where: { $0.mealId == mealId }) {
            modelContext.delete(existing)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            modelContext.insert(MealCompletion(mealId: mealId, date: today))
        }
    }

    private func phaseHex(_ slug: String) -> UInt {
        switch slug {
        case "menstrual": return 0xB85252
        case "follicular": return 0x4A8C6A
        case "ovulatory": return 0xC49A3C
        case "luteal": return 0x7A5C9C
        default: return 0x9A8A7A
        }
    }
}
