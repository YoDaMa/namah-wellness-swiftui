import SwiftUI
import SwiftData

struct PlanView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var reminders: [PhaseReminder]
    @Query private var phaseNutrients: [PhaseNutrient]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var exercises: [CoreExercise]
    @Query private var definitions: [SupplementDefinition]
    @Query private var supplementNutrients: [SupplementNutrient]
    @Query private var userSupplements: [UserSupplement]

    @State private var selectedPhaseSlug: String?
    @State private var expandedDay: Int? = nil
    @State private var selectedDayOfWeek: Int?
    @State private var showCoreExercises = false
    @State private var showBrowse = false
    @State private var showAddCustom = false
    @State private var searchText = ""
    @State private var showProfile = false

    private var currentSlug: String {
        selectedPhaseSlug ?? cycleService.currentPhase?.phaseSlug ?? "menstrual"
    }

    private var selectedPhase: Phase? {
        phases.first { $0.slug == currentSlug }
    }

    private var phaseMeals: [Meal] {
        guard let phase = selectedPhase else { return [] }
        return allMeals.filter { $0.phaseId == phase.id && $0.proteinG != nil }
    }

    private var dayGroups: [(dayNumber: Int, label: String, calories: String?, meals: [Meal])] {
        let days = Array(Set(phaseMeals.map(\.dayNumber))).sorted()
        return days.map { day in
            let dayMeals = phaseMeals.filter { $0.dayNumber == day }
            return (day, dayMeals.first?.dayLabel ?? "Day \(day)", dayMeals.first?.dayCalories, dayMeals)
        }
    }

    private var phaseColor: Color { PhaseColors.forSlug(currentSlug).color }

    // Workout
    private var todayDow: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }
    private var currentDow: Int { selectedDayOfWeek ?? todayDow }
    private var currentWorkout: Workout? { workouts.first { $0.dayOfWeek == currentDow } }
    private var currentSessions: [WorkoutSession] {
        guard let workout = currentWorkout else { return [] }
        return workoutSessions.filter { $0.workoutId == workout.id }
    }

    // Supplements
    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }
    private let supplementTimeSlots = [
        ("morning", "Morning"),
        ("with_meals", "With Meals"),
        ("evening", "Evening"),
        ("as_needed", "As Needed"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    phasePicker
                    heroSection
                    nutrientsBar
                    macroTargets

                    if let p = selectedPhase, !p.saNote.isEmpty {
                        saNote(p.saNote)
                    }

                    mealPlanSection
                    grocerySection

                    Divider()
                        .padding(.vertical, 4)

                    workoutSection
                    supplementsSection
                    remindersSection
                }
                .padding()
            }
            .navigationTitle("Plan")
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView(cycleService: cycleService)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showBrowse) { browseSheet }
            .sheet(isPresented: $showAddCustom) { AddCustomSupplementView() }
        }
    }

    // MARK: - Phase Picker

    private var phasePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(phases.sorted(by: { $0.dayStart < $1.dayStart }), id: \.id) { phase in
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
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let p = selectedPhase {
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Nutrients

    @ViewBuilder
    private var nutrientsBar: some View {
        let phaseNuts = phaseNutrients.filter { $0.phaseId == selectedPhase?.id ?? "" }
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
                                phaseIcon(nut.icon)
                                Text(nut.label)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PhaseColors.forSlug(currentSlug).soft)
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
        if let p = selectedPhase {
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
            Image(systemName: "leaf.fill")
                .font(.system(size: 16))
                .foregroundStyle(.spice)
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

    private var mealPlanSection: some View {
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

            GroceryListView(phaseSlug: currentSlug)
        }
    }

    // MARK: - Workout Schedule

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKOUT SCHEDULE")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(workouts, id: \.id) { workout in
                        Button {
                            selectedDayOfWeek = workout.dayOfWeek
                        } label: {
                            VStack(spacing: 2) {
                                Text(String(workout.dayLabel.prefix(3)))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .textCase(.uppercase)
                                if workout.dayOfWeek == todayDow {
                                    Circle()
                                        .fill(Color.spice)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .foregroundStyle(currentDow == workout.dayOfWeek ? .white : .secondary)
                            .background(currentDow == workout.dayOfWeek ? Color.primary : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(currentDow == workout.dayOfWeek ? .clear : Color(uiColor: .separator), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let workout = currentWorkout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.dayLabel)
                        .font(.title3)
                        .fontDesign(.serif)
                    Text(workout.dayFocus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if workout.isRestDay {
                        Text("REST DAY")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(2)
                            .foregroundStyle(.spice)
                            .padding(.top, 2)
                    }
                }

                if !workout.isRestDay {
                    ForEach(currentSessions, id: \.id) { session in
                        sessionCard(session)
                    }
                }
            }

            if !exercises.isEmpty {
                DisclosureGroup(isExpanded: $showCoreExercises) {
                    ForEach(exercises, id: \.id) { exercise in
                        exerciseCard(exercise)
                    }
                } label: {
                    Text("Daily Core Protocol")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func sessionCard(_ session: WorkoutSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.timeSlot)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text(session.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if !session.sessionDescription.isEmpty {
                    Text(session.sessionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func exerciseCard(_ exercise: CoreExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(exercise.sets)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(exercise.exerciseDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Supplements Regimen

    private var supplementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUPPLEMENTS")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            if activeRegimen.isEmpty {
                ContentUnavailableView(
                    "No Supplements",
                    systemImage: "pill",
                    description: Text("Browse the library to add supplements to your regimen.")
                )
            } else {
                ForEach(supplementTimeSlots, id: \.0) { slot, label in
                    let slotItems = activeRegimen.filter { $0.timeOfDay == slot }
                    if !slotItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label.uppercased())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .textCase(.uppercase)
                                .tracking(2)
                                .foregroundStyle(.secondary)

                            ForEach(slotItems, id: \.id) { userSup in
                                regimenCard(userSup)
                            }
                        }
                    }
                }
            }

            Button { showBrowse = true } label: {
                Label("Browse Supplements", systemImage: "plus.magnifyingglass")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func regimenCard(_ userSup: UserSupplement) -> some View {
        let def = definitions.first { $0.id == userSup.supplementId }
        let supNuts = supplementNutrients.filter { $0.supplementId == userSup.supplementId }

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(def?.name ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if let brand = def?.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(Int(userSup.dosage)) \(def?.servingUnit ?? "dose")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !supNuts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(supNuts.prefix(3), id: \.id) { n in
                            Text("\(n.nutrientKey): \(formatAmount(n.amount))\(n.unit)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            Button { removeFromRegimen(userSup) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Phase Reminders

    @ViewBuilder
    private var remindersSection: some View {
        let phaseReminders = reminders.filter { $0.phaseId == selectedPhase?.id ?? "" }
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

    @ViewBuilder
    private func phaseIcon(_ name: String) -> some View {
        if UIImage(systemName: name) != nil {
            Image(systemName: name)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
        } else {
            Text(name)
                .frame(width: 24, alignment: .center)
        }
    }

    private func reminderCard(_ reminder: PhaseReminder) -> some View {
        HStack(alignment: .top, spacing: 10) {
            phaseIcon(reminder.icon)

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

    // MARK: - Browse Sheet

    private var browseSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showBrowse = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAddCustom = true
                        }
                    } label: {
                        Label("Create Custom Supplement", systemImage: "plus")
                    }
                }

                let filtered = filteredDefinitions
                let cats = Array(Set(filtered.map(\.category))).sorted()

                ForEach(cats, id: \.self) { cat in
                    Section(cat) {
                        ForEach(filtered.filter { $0.category == cat }, id: \.id) { def in
                            browseRow(def)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search supplements")
            .navigationTitle("Supplements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showBrowse = false }
                }
            }
        }
    }

    private var filteredDefinitions: [SupplementDefinition] {
        if searchText.isEmpty { return definitions }
        let q = searchText.lowercased()
        return definitions.filter {
            $0.name.lowercased().contains(q) || $0.category.lowercased().contains(q)
        }
    }

    private func browseRow(_ def: SupplementDefinition) -> some View {
        let inRegimen = userSupplements.contains { $0.supplementId == def.id && $0.isActive }

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    if let brand = def.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(def.servingSize) \(def.servingUnit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if inRegimen {
                Image(systemName: "checkmark")
                    .foregroundStyle(.phaseF)
            } else {
                Button("Add") { addToRegimen(def) }
                    .font(.caption)
                    .fontWeight(.medium)
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    private func addToRegimen(_ def: SupplementDefinition) {
        modelContext.insert(UserSupplement(
            supplementId: def.id, dosage: Double(def.servingSize),
            frequency: "daily", timeOfDay: "morning"
        ))
    }

    private func removeFromRegimen(_ userSup: UserSupplement) { userSup.isActive = false }

    private func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
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
