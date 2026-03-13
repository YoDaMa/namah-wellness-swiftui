import SwiftUI
import SwiftData

struct MealPlanView: View {
    let phaseSlug: String

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var userPlanItems: [UserPlanItem]
    @Query private var userItemsHidden: [UserItemHidden]

    @State private var selectedDay: Int = 1
    @State private var showAddMeal = false
    @State private var replaceMealType: String?
    @State private var replaceMealTime: String?

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }
    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    private var hiddenIds: Set<String> {
        Set(userItemsHidden.map(\.itemId))
    }

    private var customMeals: [UserPlanItem] {
        userPlanItems.filter { $0.category == .meal && $0.isActive }
    }

    private var phaseMeals: [Meal] {
        guard let p = phase else { return [] }
        return allMeals.filter { $0.phaseId == p.id && $0.proteinG != nil && !hiddenIds.contains($0.id) }
    }

    private var dayGroups: [(dayNumber: Int, label: String, calories: String?, meals: [Meal])] {
        var dict: [Int: [Meal]] = [:]
        for meal in phaseMeals { dict[meal.dayNumber, default: []].append(meal) }
        return dict.keys.sorted().map { day in
            let meals = dict[day]!
            return (day, meals.first?.dayLabel ?? "Day \(day)", meals.first?.dayCalories, meals)
        }
    }

    private var selectedDayGroup: (dayNumber: Int, label: String, calories: String?, meals: [Meal])? {
        dayGroups.first { $0.dayNumber == selectedDay } ?? dayGroups.first
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }

    private var todayStr: String {
        dateFormatter.string(from: Date())
    }

    private var customMealsForToday: [UserPlanItem] {
        customMeals.filter { $0.appliesOnDate(todayStr) }
    }

    private func macroSummary(for group: (dayNumber: Int, label: String, calories: String?, meals: [Meal])) -> String {
        let totalP = group.meals.compactMap(\.proteinG).reduce(0, +)
        let totalC = group.meals.compactMap(\.carbsG).reduce(0, +)
        let totalF = group.meals.compactMap(\.fatG).reduce(0, +)
        let cal = group.calories ?? ""
        if totalP == 0 && totalC == 0 && totalF == 0 { return cal }
        return "\(cal.isEmpty ? "" : "\(cal) · ")\(totalP)g P · \(totalF)g F · \(totalC)g C"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dayNavigator

                if let group = selectedDayGroup {
                    let summary = macroSummary(for: group)
                    if !summary.isEmpty {
                        Text(summary)
                            .font(.nCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(group.meals, id: \.id) { meal in
                        mealCard(meal)
                            .contextMenu {
                                Button(role: .destructive) {
                                    hideItem(meal.id, type: .meal)
                                } label: {
                                    Label("Hide This Meal", systemImage: "eye.slash")
                                }
                                Button {
                                    replaceMealType = meal.mealType
                                    replaceMealTime = meal.time
                                    showAddMeal = true
                                } label: {
                                    Label("Replace with My Own", systemImage: "arrow.triangle.swap")
                                }
                            }
                    }

                    // Custom meals for today
                    ForEach(customMealsForToday, id: \.id) { item in
                        customMealCard(item)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Meal Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if dayGroups.first(where: { $0.dayNumber == selectedDay }) == nil {
                selectedDay = dayGroups.first?.dayNumber ?? 1
            }
        }
        .sheet(isPresented: $showAddMeal) {
            AddPlanItemSheet(
                defaultCategory: .meal,
                phaseSlug: phaseSlug,
                replacingMealType: replaceMealType,
                replacingTime: replaceMealTime
            )
        }
    }

    // MARK: - Day Navigator

    private var dayNavigator: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(dayGroups, id: \.dayNumber) { group in
                    let isSelected = (selectedDayGroup?.dayNumber ?? selectedDay) == group.dayNumber

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDay = group.dayNumber
                        }
                    } label: {
                        Text(group.label)
                            .font(.nCaption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .background(isSelected ? phaseColors.color : Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Meal Card

    private func mealCard(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(meal.time)
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(meal.mealType.uppercased())
                    .font(.sans(8))
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }

            Text(meal.title)
                .font(.nSubheadline)
                .fontWeight(.semibold)

            if !meal.mealDescription.isEmpty {
                Text(meal.mealDescription)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                Text("\(p)P · \(c)C · \(f)F")
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
            }

            if let sa = meal.saNote, !sa.isEmpty {
                SACalloutView(text: sa)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Custom Meal Card

    private func customMealCard(_ item: UserPlanItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let time = item.time {
                    Text(time)
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                if let mt = item.mealType {
                    Text(mt.uppercased())
                        .font(.sans(8))
                        .fontWeight(.medium)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                Text("CUSTOM")
                    .font(.sans(8))
                    .fontWeight(.bold)
                    .tracking(1)
                    .foregroundStyle(phaseColors.color)
            }

            Text(item.title)
                .font(.nSubheadline)
                .fontWeight(.semibold)

            if let sub = item.subtitle, !sub.isEmpty {
                Text(sub)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let p = item.proteinG, let c = item.carbsG, let f = item.fatG {
                Text("\(p)P · \(c)C · \(f)F")
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(phaseColors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(phaseColors.color.opacity(0.3), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                item.isActive = false
                syncService.queueChange(
                    table: "userPlanItems", action: "upsert",
                    data: ["id": item.id, "isActive": false], modelContext: modelContext
                )
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    // MARK: - Hide Item

    private func hideItem(_ itemId: String, type: PlanItemCategory) {
        let hidden = UserItemHidden(itemId: itemId, itemType: type)
        modelContext.insert(hidden)
        syncService.queueChange(
            table: "userItemsHidden", action: "upsert",
            data: ["id": hidden.id, "itemId": itemId], modelContext: modelContext
        )
    }
}
