import SwiftUI
import SwiftData

struct TodayView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var mealCompletions: [MealCompletion]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var phases: [Phase]
    @Query private var symptomLogs: [SymptomLog]
    @Query private var dailyNotes: [DailyNote]
    @Query private var definitions: [SupplementDefinition]
    @Query private var supplementNutrients: [SupplementNutrient]
    @Query private var userSupplements: [UserSupplement]
    @Query private var supplementLogs: [SupplementLog]

    @State private var showProfile = false

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var todayMealCompletionIds: Set<String> {
        Set(mealCompletions.filter { $0.date == today }.map(\.mealId))
    }

    private var todayMeals: [Meal] {
        guard let phase = cycleService.currentPhase,
              let phaseRecord = phases.first(where: { $0.slug == phase.phaseSlug })
        else { return [] }

        let phaseMeals = allMeals.filter { $0.phaseId == phaseRecord.id && $0.proteinG != nil }
        let dayNumbers = Array(Set(phaseMeals.map(\.dayNumber))).sorted()
        guard !dayNumbers.isEmpty else { return [] }
        let todayDay = dayNumbers[(phase.dayInPhase - 1) % dayNumbers.count]
        return phaseMeals.filter { $0.dayNumber == todayDay }
    }

    private var todayWorkout: (Workout, [WorkoutSession])? {
        let jsDay = Calendar.current.component(.weekday, from: Date())
        let dayOfWeek = jsDay == 1 ? 6 : jsDay - 2
        guard let w = workouts.first(where: { $0.dayOfWeek == dayOfWeek }) else { return nil }
        let sessions = workoutSessions.filter { $0.workoutId == w.id }
        return (w, sessions)
    }

    private var todaySymptomLog: SymptomLog? {
        symptomLogs.first { $0.date == today }
    }

    private var todayNote: DailyNote? {
        dailyNotes.first { $0.date == today }
    }

    private var currentPhaseRecord: Phase? {
        guard let slug = cycleService.currentPhase?.phaseSlug else { return nil }
        return phases.first { $0.slug == slug }
    }

    // Supplements
    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }
    private var todaySupplementLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }
    private let timeSlots = [
        ("morning", "Morning"),
        ("with_meals", "With Meals"),
        ("evening", "Evening"),
        ("as_needed", "As Needed"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Phase hero
                    if let phase = cycleService.currentPhase {
                        PhaseHeroCard(
                            phase: phase,
                            cycleStats: cycleService.cycleStats,
                            heroTitle: currentPhaseRecord?.heroTitle,
                            heroSubtitle: currentPhaseRecord?.heroSubtitle,
                            exerciseIntensity: currentPhaseRecord?.exerciseIntensity
                        )
                    }

                    // Macro summary
                    if !todayMeals.isEmpty {
                        MacroSummaryBar(meals: todayMeals, completedIds: todayMealCompletionIds)
                    }

                    // Meals
                    mealsSection

                    // Workout
                    workoutSection

                    // Supplements
                    supplementsSection

                    // Symptoms
                    SymptomsTabView(
                        todaySymptomLog: todaySymptomLog,
                        todayNote: todayNote,
                        today: today,
                        phaseColor: cycleService.currentPhase.flatMap { PhaseColors.forSlug($0.phaseSlug).color }
                    )
                }
                .padding()
            }
            .navigationTitle("Today")
            .navigationDestination(isPresented: $showProfile) {
                ProfileView(cycleService: cycleService)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showProfile = true
                        } label: {
                            Label("Profile", systemImage: "person")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Meals Section

    @ViewBuilder
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MEALS")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            if todayMeals.isEmpty {
                ContentUnavailableView(
                    "No Meals",
                    systemImage: "fork.knife",
                    description: Text("Log your cycle to see phase-specific meals.")
                )
            } else {
                ForEach(todayMeals, id: \.id) { meal in
                    MealCardView(
                        meal: meal,
                        isCompleted: todayMealCompletionIds.contains(meal.id),
                        onToggle: { toggleMeal(meal) }
                    )
                }
            }
        }
    }

    // MARK: - Workout Section

    @ViewBuilder
    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKOUT")
                .font(.caption2)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.secondary)

            if let (workout, sessions) = todayWorkout {
                if workout.isRestDay {
                    ContentUnavailableView(
                        "Rest Day",
                        systemImage: "leaf",
                        description: Text(workout.dayFocus)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(workout.dayLabel)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .textCase(.uppercase)
                                .tracking(2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(workout.dayFocus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(sessions, id: \.id) { session in
                            HStack(alignment: .top, spacing: 12) {
                                Text(session.timeSlot)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 56, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(session.sessionDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                ContentUnavailableView(
                    "No Workout",
                    systemImage: "figure.run",
                    description: Text("No workout data available.")
                )
            }
        }
    }

    // MARK: - Supplements Section

    @ViewBuilder
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
                    description: Text("Add supplements in the Plan tab.")
                )
            } else {
                let takenCount = activeRegimen.filter { todaySupplementLogIds.contains($0.id) }.count
                Text("\(takenCount) of \(activeRegimen.count) taken today")
                    .font(.footnote)
                    .fontWeight(.medium)

                ForEach(timeSlots, id: \.0) { slot, label in
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
                                supplementCard(userSup)
                            }
                        }
                    }
                }
            }
        }
    }

    private func supplementCard(_ userSup: UserSupplement) -> some View {
        let def = definitions.first { $0.id == userSup.supplementId }
        let isTaken = todaySupplementLogIds.contains(userSup.id)
        let supNutrients = supplementNutrients.filter { $0.supplementId == userSup.supplementId }

        return Button { toggleSupplement(userSup) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isTaken ? Color.phaseF : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(def?.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isTaken ? .secondary : .primary)
                        .strikethrough(isTaken)

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

                    if !supNutrients.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(supNutrients.prefix(3), id: \.id) { n in
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
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleMeal(_ meal: Meal) {
        if let existing = mealCompletions.first(where: { $0.mealId == meal.id && $0.date == today }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(MealCompletion(mealId: meal.id, date: today))
        }
    }

    private func toggleSupplement(_ userSup: UserSupplement) {
        if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
        } else {
            modelContext.insert(SupplementLog(userSupplementId: userSup.id, date: today, taken: true))
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
    }
}

// MARK: - Symptoms Tab

struct SymptomsTabView: View {
    @Environment(\.modelContext) private var modelContext

    let todaySymptomLog: SymptomLog?
    let todayNote: DailyNote?
    let today: String
    let phaseColor: Color?

    private var accentColor: Color { phaseColor ?? .spice }

    private struct SymptomItem: Identifiable {
        let id: String
        let icon: String
        let label: String
        let get: (SymptomLog) -> Int?
        let set: (SymptomLog, Int?) -> Void
    }

    private let symptoms: [SymptomItem] = [
        SymptomItem(id: "mood", icon: "face.smiling", label: "Mood", get: { $0.mood }, set: { $0.mood = $1 }),
        SymptomItem(id: "energy", icon: "bolt.fill", label: "Energy", get: { $0.energy }, set: { $0.energy = $1 }),
        SymptomItem(id: "cramps", icon: "waveform.path", label: "Cramps", get: { $0.cramps }, set: { $0.cramps = $1 }),
        SymptomItem(id: "bloating", icon: "wind", label: "Bloating", get: { $0.bloating }, set: { $0.bloating = $1 }),
        SymptomItem(id: "fatigue", icon: "battery.25percent", label: "Fatigue", get: { $0.fatigue }, set: { $0.fatigue = $1 }),
        SymptomItem(id: "acne", icon: "circle.fill", label: "Acne", get: { $0.acne }, set: { $0.acne = $1 }),
        SymptomItem(id: "headache", icon: "brain.head.profile", label: "Headache", get: { $0.headache }, set: { $0.headache = $1 }),
        SymptomItem(id: "breastTenderness", icon: "heart.fill", label: "Breast", get: { $0.breastTenderness }, set: { $0.breastTenderness = $1 }),
        SymptomItem(id: "sleepQuality", icon: "moon.fill", label: "Sleep", get: { $0.sleepQuality }, set: { $0.sleepQuality = $1 }),
        SymptomItem(id: "anxiety", icon: "exclamationmark.triangle", label: "Anxiety", get: { $0.anxiety }, set: { $0.anxiety = $1 }),
        SymptomItem(id: "irritability", icon: "flame.fill", label: "Irritable", get: { $0.irritability }, set: { $0.irritability = $1 }),
        SymptomItem(id: "libido", icon: "sparkles", label: "Libido", get: { $0.libido }, set: { $0.libido = $1 }),
        SymptomItem(id: "appetite", icon: "fork.knife", label: "Appetite", get: { $0.appetite }, set: { $0.appetite = $1 }),
    ]

    private let flowOptions = ["none", "spotting", "light", "medium", "heavy"]

    @State private var noteText: String = ""
    @State private var flowValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Symptom grid
            VStack(alignment: .leading, spacing: 10) {
                Text("SYMPTOMS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(symptoms) { symptom in
                        symptomCell(symptom)
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Flow intensity slider
            VStack(alignment: .leading, spacing: 10) {
                Text("FLOW")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Slider(value: $flowValue, in: 0...4, step: 1) {
                        Text("Flow")
                    }
                    .tint(accentColor)
                    .onChange(of: flowValue) {
                        let log = getOrCreateLog()
                        let idx = Int(flowValue)
                        log.flowIntensity = flowOptions[idx]
                    }

                    HStack {
                        ForEach(flowOptions, id: \.self) { option in
                            Text(option.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(flowOptions[Int(flowValue)] == option ? accentColor : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Daily notes
            VStack(alignment: .leading, spacing: 10) {
                Text("NOTES")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)

                TextEditor(text: $noteText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: noteText) {
                        saveNote()
                    }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onAppear {
            noteText = todayNote?.content ?? ""
            if let flow = todaySymptomLog?.flowIntensity,
               let idx = flowOptions.firstIndex(of: flow) {
                flowValue = Double(idx)
            }
        }
    }

    // MARK: - Symptom Cell (drag to adjust)

    private func symptomCell(_ symptom: SymptomItem) -> some View {
        let scoreVal = todaySymptomLog.flatMap { symptom.get($0) } ?? 0
        let intensity = Double(scoreVal) / 5.0

        return SymptomDragCell(
            icon: symptom.icon,
            label: symptom.label,
            value: scoreVal,
            maxValue: 5,
            accentColor: accentColor,
            intensity: intensity,
            onChange: { newValue in
                let log = getOrCreateLog()
                symptom.set(log, newValue == 0 ? nil : newValue)
            }
        )
    }

    // MARK: - Helpers

    private func getOrCreateLog() -> SymptomLog {
        if let existing = todaySymptomLog { return existing }
        let log = SymptomLog(date: today)
        modelContext.insert(log)
        return log
    }

    private func saveNote() {
        if let existing = todayNote {
            existing.content = noteText
            existing.updatedAt = Date()
        } else if !noteText.isEmpty {
            modelContext.insert(DailyNote(date: today, content: noteText))
        }
    }
}

// MARK: - Drag-to-adjust symptom cell

private struct SymptomDragCell: View {
    let icon: String
    let label: String
    let value: Int
    let maxValue: Int
    let accentColor: Color
    let intensity: Double
    let onChange: (Int) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @GestureState private var isActive = false

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(value > 0 ? accentColor : .secondary)
                .symbolEffect(.bounce, value: isDragging)

            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(value > 0 ? .primary : .secondary)
                .lineLimit(1)

            // Value indicator: filled dots
            HStack(spacing: 2) {
                ForEach(1...maxValue, id: \.self) { i in
                    Circle()
                        .fill(i <= value ? accentColor : Color(uiColor: .separator))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.top, 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(accentColor.opacity(intensity * 0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(value > 0 ? accentColor.opacity(0.3) : Color(uiColor: .separator), lineWidth: 1)
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($isActive) { _, state, _ in
                    state = true
                }
                .onChanged { gesture in
                    isDragging = true
                    dragOffset = gesture.translation.height
                    // Every 20pt of drag = 1 step. Up = increase, down = decrease.
                    let steps = Int(-dragOffset / 20)
                    let newValue = max(0, min(maxValue, value + steps))
                    if newValue != value {
                        onChange(newValue)
                        dragOffset = 0 // reset so next drag segment starts fresh
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    dragOffset = 0
                }
        )
        .onTapGesture {
            // Tap to cycle: 0→1→2→3→4→5→0
            let next = value >= maxValue ? 0 : value + 1
            onChange(next)
        }
    }
}
