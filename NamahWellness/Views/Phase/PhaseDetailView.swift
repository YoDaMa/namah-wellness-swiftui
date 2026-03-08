import SwiftUI
import SwiftData

struct PhaseDetailView: View {
    let slug: String
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query private var phases: [Phase]
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var groceryItems: [GroceryItem]
    @Query private var groceryChecks: [GroceryCheck]
    @Query private var reminders: [PhaseReminder]
    @Query private var phaseNutrients: [PhaseNutrient]

    @State private var expandedDay: Int? = nil
    @State private var selectedSlug: String

    init(slug: String, cycleService: CycleService) {
        self.slug = slug
        self.cycleService = cycleService
        self._selectedSlug = State(initialValue: slug)
    }

    private var phase: Phase? { phases.first { $0.slug == selectedSlug } }
    private var phaseMeals: [Meal] {
        guard let p = phase else { return [] }
        return allMeals.filter { $0.phaseId == p.id && $0.proteinG != nil }
    }

    private var dayGroups: [(dayNumber: Int, label: String, calories: String?, meals: [Meal])] {
        let days = Array(Set(phaseMeals.map(\.dayNumber))).sorted()
        return days.map { day in
            let dayMeals = phaseMeals.filter { $0.dayNumber == day }
            return (day, dayMeals.first?.dayLabel ?? "Day \(day)", dayMeals.first?.dayCalories, dayMeals)
        }
    }

    private var phaseColor: Color { PhaseColors.forSlug(selectedSlug).color }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                phasePicker
                heroSection

                VStack(alignment: .leading, spacing: 20) {
                    nutrientsBar
                    macroTargets

                    if let p = phase, !p.saNote.isEmpty {
                        saNote(p.saNote)
                    }

                    mealPlan
                    grocerySection
                    remindersSection
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let p = phase {
                Text(p.heroEyebrow.uppercased())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))

                Text(p.heroTitle)
                    .font(.heading(32))
                    .foregroundStyle(.white)

                Text(p.heroSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    Text("EXERCISE")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(p.exerciseIntensity)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .padding(.top, 8)
        .background(phaseColor)
    }

    // MARK: - Phase Picker

    private var phasePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(phases.sorted(by: { $0.dayStart < $1.dayStart }), id: \.id) { p in
                    Button {
                        selectedSlug = p.slug
                    } label: {
                        Text(p.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(selectedSlug == p.slug ? .white : .secondary)
                            .background(selectedSlug == p.slug ? PhaseColors.forSlug(p.slug).color : .clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedSlug == p.slug ? .clear : Color(uiColor: .separator), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Nutrients

    @ViewBuilder
    private var nutrientsBar: some View {
        let phaseNuts = phaseNutrients.filter { $0.phaseId == phase?.id ?? "" }
        if !phaseNuts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("KEY NUTRIENTS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(phaseNuts, id: \.id) { nut in
                            HStack(spacing: 4) {
                                Text(nut.icon).font(.system(size: 12))
                                Text(nut.label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PhaseColors.forSlug(selectedSlug).soft)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Macro Targets

    @ViewBuilder
    private var macroTargets: some View {
        if let p = phase {
            HStack(spacing: 0) {
                macroItem("Calories", p.calorieTarget)
                Divider().frame(height: 30)
                macroItem("Protein", p.proteinTarget)
                Divider().frame(height: 30)
                macroItem("Fat", p.fatTarget)
                Divider().frame(height: 30)
                macroItem("Carbs", p.carbTarget)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func macroItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - SA Note

    private func saNote(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\u{1f1ee}\u{1f1f3}")
                .font(.system(size: 16))
            Text(note)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.spice.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Meal Plan

    private var mealPlan: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEAL PLAN")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            ForEach(dayGroups, id: \.dayNumber) { group in
                daySection(group)
            }
        }
    }

    private func daySection(_ group: (dayNumber: Int, label: String, calories: String?, meals: [Meal])) -> some View {
        let isExpanded = expandedDay == group.dayNumber

        return DisclosureGroup(isExpanded: Binding(
            get: { isExpanded },
            set: { expandedDay = $0 ? group.dayNumber : nil }
        )) {
            VStack(spacing: 0) {
                ForEach(group.meals, id: \.id) { meal in
                    mealRow(meal)
                }
            }
        } label: {
            HStack {
                Text(group.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                if let cal = group.calories {
                    Text(cal)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func mealRow(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meal.time)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("\u{00b7}")
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

            if !meal.mealDescription.isEmpty {
                Text(meal.mealDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let p = meal.proteinG, let c = meal.carbsG, let f = meal.fatG {
                HStack(spacing: 6) {
                    MacroPill(label: "\(p)P", color: .macroProtein)
                    MacroPill(label: "\(c)C", color: .macroCarbs)
                    MacroPill(label: "\(f)F", color: .macroFat)
                }
                .padding(.top, 2)
            }

            if let sa = meal.saNote, !sa.isEmpty {
                Text(sa)
                    .font(.caption2)
                    .foregroundStyle(.spice)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Grocery

    private var grocerySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GROCERY LIST")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            GroceryListView(phaseSlug: selectedSlug)
        }
    }

    // MARK: - Reminders

    @ViewBuilder
    private var remindersSection: some View {
        let phaseReminders = reminders.filter { $0.phaseId == phase?.id ?? "" }
        if !phaseReminders.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("REMINDERS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)

                ForEach(phaseReminders, id: \.id) { reminder in
                    reminderCard(reminder)
                }
            }
        }
    }

    private func reminderCard(_ reminder: PhaseReminder) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(reminder.icon).font(.system(size: 16))

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.text)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let level = reminder.evidenceLevel, !level.isEmpty {
                    Text(evidenceLabel(level))
                        .font(.system(size: 8, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(evidenceColor(level))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(evidenceColor(level).opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func evidenceLabel(_ level: String) -> String {
        switch level {
        case "strong": return "STRONG EVIDENCE"
        case "moderate": return "MODERATE EVIDENCE"
        case "emerging": return "EMERGING RESEARCH"
        case "expert_opinion": return "EXPERT OPINION"
        default: return level.uppercased()
        }
    }

    private func evidenceColor(_ level: String) -> Color {
        switch level {
        case "strong": return .phaseF
        case "moderate": return .phaseO
        case "emerging": return .phaseL
        default: return .secondary
        }
    }
}
