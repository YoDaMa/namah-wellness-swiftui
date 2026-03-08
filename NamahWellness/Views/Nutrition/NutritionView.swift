import SwiftUI
import SwiftData

struct NutritionView: View {
    let cycleService: CycleService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query private var meals: [Meal]

    @State private var selectedPhaseSlug: String?
    @State private var activeTab = 0

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

    private var dayGroups: [(day: Int, label: String, calories: String?, meals: [Meal])] {
        let grouped = Dictionary(grouping: phaseMeals) { $0.dayNumber }
        return grouped.keys.sorted().map { day in
            let dayMeals = grouped[day]!
            return (day, dayMeals.first?.dayLabel ?? "Day \(day)", dayMeals.first?.dayCalories, dayMeals)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hormonesCard

                    // Phase selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(phases, id: \.id) { phase in
                                Button {
                                    selectedPhaseSlug = phase.slug
                                } label: {
                                    Text(phase.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .textCase(.uppercase)
                                        .tracking(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .foregroundStyle(currentSlug == phase.slug ? .white : .secondary)
                                        .background(currentSlug == phase.slug ? PhaseColors.forSlug(phase.slug).color : .clear)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(currentSlug == phase.slug ? .clear : Color(uiColor: .separator), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 3-tab picker
                    Picker("Section", selection: $activeTab) {
                        Text("Meals").tag(0)
                        Text("Grocery").tag(1)
                        Text("Supplements").tag(2)
                    }
                    .pickerStyle(.segmented)

                    switch activeTab {
                    case 0: mealsTab
                    case 1: GroceryListView(phaseSlug: currentSlug)
                    case 2: SupplementsView()
                    default: EmptyView()
                    }
                }
                .padding()
            }
            .navigationTitle("Nutrition")
        }
    }

    // MARK: - Hormones Card

    private var hormonesCard: some View {
        NavigationLink {
            HormonesView(cycleService: cycleService)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "flask")
                    .font(.system(size: 20))
                    .foregroundStyle(.phaseO)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hormones")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("Reference curves scaled to your cycle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meals Tab

    @ViewBuilder
    private var mealsTab: some View {
        if let phase = selectedPhase {
            HStack(spacing: 0) {
                macroTarget("P", phase.proteinTarget)
                Divider().frame(height: 20)
                macroTarget("C", phase.carbTarget)
                Divider().frame(height: 20)
                macroTarget("F", phase.fatTarget)
                Divider().frame(height: 20)
                macroTarget("Cal", phase.calorieTarget)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        ForEach(dayGroups, id: \.day) { group in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(group.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(.primary)
                    if let cal = group.calories {
                        Text(cal)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                ForEach(group.meals, id: \.id) { meal in
                    mealRow(meal)
                }
            }
        }
    }

    private func macroTarget(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func mealRow(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(meal.time)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text(meal.mealType.uppercased())
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(meal.calories)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(meal.title)
                .font(.subheadline)
                .fontWeight(.medium)
            if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                HStack(spacing: 6) {
                    MacroPill(label: "\(p)P", color: .macroProtein)
                    MacroPill(label: "\(c)C", color: .macroCarbs)
                    MacroPill(label: "\(f)F", color: .macroFat)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
