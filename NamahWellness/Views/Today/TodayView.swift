import SwiftUI
import SwiftData

struct TodayView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var mealCompletions: [MealCompletion]
    @Query private var workoutCompletions: [WorkoutCompletion]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var phases: [Phase]
    @Query private var symptomLogs: [SymptomLog]
    @Query private var dailyNotes: [DailyNote]

    @State private var activeTab = 0

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let phase = cycleService.currentPhase {
                        NavigationLink {
                            PhaseDetailView(slug: phase.phaseSlug, cycleService: cycleService)
                        } label: {
                            PhaseHeroCard(phase: phase, cycleStats: cycleService.cycleStats)
                        }
                        .buttonStyle(.plain)
                    }

                    // Macro summary
                    if !todayMeals.isEmpty {
                        MacroSummaryBar(meals: todayMeals, completedIds: todayMealCompletionIds)
                    }

                    // Tab picker
                    Picker("Section", selection: $activeTab) {
                        Text("Meals").tag(0)
                        Text("Workout").tag(1)
                        Text("Symptoms").tag(2)
                    }
                    .pickerStyle(.segmented)

                    switch activeTab {
                    case 0: mealsTab
                    case 1: workoutTab
                    case 2:
                        SymptomsTabView(
                            todaySymptomLog: todaySymptomLog,
                            todayNote: todayNote,
                            today: today,
                            phaseColor: cycleService.currentPhase.flatMap { PhaseColors.forSlug($0.phaseSlug).color }
                        )
                    default: EmptyView()
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
        }
    }

    // MARK: - Meals Tab

    @ViewBuilder
    private var mealsTab: some View {
        if todayMeals.isEmpty {
            ContentUnavailableView(
                "No Meals",
                systemImage: "fork.knife",
                description: Text("Log your cycle to see phase-specific meals.")
            )
        } else {
            VStack(spacing: 8) {
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

    // MARK: - Workout Tab

    @ViewBuilder
    private var workoutTab: some View {
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

    // MARK: - Actions

    private func toggleMeal(_ meal: Meal) {
        if let existing = mealCompletions.first(where: { $0.mealId == meal.id && $0.date == today }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(MealCompletion(mealId: meal.id, date: today))
        }
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
                        symptomButton(symptom)
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Flow intensity
            VStack(alignment: .leading, spacing: 10) {
                Text("FLOW")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(flowOptions, id: \.self) { option in
                        flowButton(option)
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
        }
    }

    private func symptomButton(_ symptom: SymptomItem) -> some View {
        let scoreVal = todaySymptomLog.flatMap { symptom.get($0) } ?? 0
        let intensity = Double(scoreVal) / 5.0

        return Button {
            cycleSymptom(symptom)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symptom.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(scoreVal > 0 ? accentColor : .secondary)
                Text(symptom.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(scoreVal > 0 ? .primary : .secondary)
                    .lineLimit(1)
                if scoreVal > 0 {
                    Text("\(scoreVal)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(accentColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(accentColor.opacity(intensity * 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(scoreVal > 0 ? accentColor.opacity(0.3) : Color(uiColor: .separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func flowButton(_ option: String) -> some View {
        let isSelected = todaySymptomLog?.flowIntensity == option

        return Button {
            setFlow(option)
        } label: {
            Text(option.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(0.5)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(isSelected ? accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? .clear : Color(uiColor: .separator), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func getOrCreateLog() -> SymptomLog {
        if let existing = todaySymptomLog { return existing }
        let log = SymptomLog(date: today)
        modelContext.insert(log)
        return log
    }

    private func cycleSymptom(_ symptom: SymptomItem) {
        let log = getOrCreateLog()
        let current = symptom.get(log) ?? 0
        let next = current >= 5 ? 0 : current + 1
        symptom.set(log, next == 0 ? nil : next)
    }

    private func setFlow(_ option: String) {
        let log = getOrCreateLog()
        log.flowIntensity = log.flowIntensity == option ? nil : option
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
