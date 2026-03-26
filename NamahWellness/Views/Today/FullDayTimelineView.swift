import SwiftUI
import SwiftData

struct FullDayTimelineView: View {
    let cycleService: CycleService
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Environment(TimeBlockService.self) private var timeBlockService

    @Query(sort: \Meal.dayNumber) private var allMeals: [Meal]
    @Query private var mealCompletions: [MealCompletion]
    @Query private var workoutCompletions: [WorkoutCompletion]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var phases: [Phase]
    @Query private var definitions: [SupplementDefinition]
    @Query private var supplementNutrients: [SupplementNutrient]
    @Query private var userSupplements: [UserSupplement]
    @Query private var supplementLogs: [SupplementLog]
    @Query private var habits: [Habit]
    @Query private var habitLogs: [HabitLog]
    @Query private var userItemsHidden: [UserItemHidden]
    @Query private var symptomLogs: [SymptomLog]


    @State private var showSymptoms = false
    @State private var mealPresentation: MealDetailPresentation?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private var today: String { dateFormatter.string(from: Date()) }

    private var phaseColor: Color {
        guard let slug = cycleService.currentPhase?.phaseSlug else { return .primary }
        return PhaseColors.forSlug(slug).color
    }

    // MARK: - Computed Data

    private var hiddenIds: Set<String> {
        Set(userItemsHidden.map(\.itemId))
    }

    private var customMeals: [Habit] {
        habits.filter { $0.category == .meal && $0.isActive && $0.appliesOnDate(today) }
    }

    private var customWorkouts: [Habit] {
        habits.filter { $0.category == .workout && $0.isActive && $0.appliesOnDate(today) }
    }

    private var todayHabits: [Habit] {
        habits.filter { $0.category == .habit && $0.isActive && $0.appliesOnDate(today) }
    }

    private var todayHabitLogIds: Set<String> {
        Set(habitLogs.filter { $0.date == today && $0.completed }.map(\.habitId))
    }

    private var todayMealCompletionIds: Set<String> {
        Set(mealCompletions.filter { $0.date == today }.map(\.mealId))
    }

    private var todayWorkoutCompletionIds: Set<String> {
        Set(workoutCompletions.filter { $0.date == today }.map(\.workoutId))
    }

    private var todayMeals: [Meal] {
        guard let phase = cycleService.currentPhase,
              let phaseRecord = phases.first(where: { $0.slug == phase.phaseSlug })
        else { return [] }
        let phaseMeals = allMeals.filter { $0.phaseId == phaseRecord.id && $0.proteinG != nil && !hiddenIds.contains($0.id) }
        let dayNumbers = Array(Set(phaseMeals.map(\.dayNumber))).sorted()
        guard !dayNumbers.isEmpty else { return [] }
        let todayDay = dayNumbers[(phase.dayInPhase - 1) % dayNumbers.count]
        return phaseMeals.filter { $0.dayNumber == todayDay }
    }

    private var todayWorkout: (Workout, [WorkoutSession])? {
        let jsDay = Calendar.current.component(.weekday, from: Date())
        let dayOfWeek = jsDay == 1 ? 6 : jsDay - 2
        guard let w = workouts.first(where: { $0.dayOfWeek == dayOfWeek }) else { return nil }
        let sessions = workoutSessions.filter { $0.workoutId == w.id && !hiddenIds.contains($0.id) }
        return (w, sessions)
    }

    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }

    private var todaySupplementLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }

    private var hasAnyCheckIn: Bool {
        symptomLogs.contains { $0.date == today }
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    let blocks = timeBlockService.blocks
                    let currentKind = timeBlockService.currentBlock?.kind

                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        blockSection(block: block, index: index, currentKind: currentKind, blocks: blocks)
                            .id(block.kind)
                            .padding(.horizontal)
                    }

                    // Rest day indicator
                    if let (workout, _) = todayWorkout, workout.isRestDay {
                        restDayCard
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .onAppear {
                if let currentKind = timeBlockService.currentBlock?.kind {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(currentKind, anchor: .top)
                        }
                    }
                }
            }
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Today's Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showSymptoms) {
            let slug = cycleService.currentPhase?.phaseSlug ?? "menstrual"
            ScrollView {
                DailyTrackingView(
                    symptomLog: symptomLogs.first { $0.date == today },
                    dailyNote: nil,
                    bbtLog: nil,
                    sexualActivityLogs: [],
                    date: today,
                    phaseSlug: slug
                )
                .padding()
            }
            .background(PhaseColors.forSlug(slug).soft.opacity(0.3))
            .navigationTitle("Today's Check-in")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $mealPresentation) { presentation in
            NavigationStack {
                MealDetailView(
                    meal: presentation.meal,
                    mealId: presentation.id,
                    phaseSlug: cycleService.currentPhase?.phaseSlug ?? "menstrual",
                    phaseColor: phaseColor
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Rest Day Card

    private var restDayCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.sans(14))
                .foregroundStyle(phaseColor)
            Text("Rest Day — recover and restore")
                .font(.prose(14))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(phaseColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Block Section Builder

    @ViewBuilder
    private func blockSection(block: TimeBlock, index: Int, currentKind: TimeBlockKind?, blocks: [TimeBlock]) -> some View {
        let isCurrentBlock = block.kind == currentKind
        let nextBlock: TimeBlock? = index + 1 < blocks.count ? blocks[index + 1] : nil

        TimeBlockSectionView(
            block: block,
            isCurrent: isCurrentBlock,
            meals: mealsForBlock(block.kind),
            supplements: supplementsForBlock(block.kind),
            workoutSessions: workoutSessionsForBlock(block.kind),
            habitItems: habitsForBlock(block.kind),
            isCheckInBlock: false,
            hasCheckedIn: hasAnyCheckIn,
            nextBlockName: nextBlock?.displayName,
            nextBlockTime: nextBlock?.startTimeLabel,
            phaseColor: phaseColor,
            onToggleMeal: { toggleMeal($0) },
            onTapMeal: { handleMealTap($0) },
            onToggleSupplement: { toggleSupplement($0) },
            onCheckIn: { showSymptoms = true },
            onToggleWorkout: { toggleWorkout($0) },
            onTapWorkout: { toggleWorkout($0.id) },
            onToggleHabit: { toggleHabit($0) }
        )
    }

    private func handleMealTap(_ item: TimeBlockSectionView.MealItem) {
        guard let displayable: any MealDisplayable = item.meal ?? item.customItem else { return }
        mealPresentation = MealDetailPresentation(id: item.id, meal: displayable)
    }

    // MARK: - Block Item Grouping

    private func mealsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.MealItem] {
        let templateMeals = todayMeals
            .filter { timeBlockService.blockForMeal(time: $0.time, mealType: $0.mealType) == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time) ?? 720) < (TimeParser.minutesSinceMidnight(from: $1.time) ?? 720) }
            .map { meal in
                TimeBlockSectionView.MealItem(
                    id: meal.id, meal: meal,
                    isCompleted: todayMealCompletionIds.contains(meal.id)
                )
            }

        let customItems = customMeals
            .filter { timeBlockService.blockForMeal(time: $0.time ?? "12:00pm", mealType: $0.mealType ?? "Meal") == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time ?? "12:00pm") ?? 720) < (TimeParser.minutesSinceMidnight(from: $1.time ?? "12:00pm") ?? 720) }
            .map { item in
                TimeBlockSectionView.MealItem(
                    id: item.id, customItem: item,
                    isCompleted: todayMealCompletionIds.contains(item.id)
                )
            }

        return templateMeals + customItems
    }

    private func supplementsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.SupplementItem] {
        let definitionsById = Dictionary(definitions.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let nutrientsBySupplementId = Dictionary(grouping: supplementNutrients, by: { $0.supplementId })

        return activeRegimen
            .filter { timeBlockService.blockForSupplement(timeOfDay: $0.timeOfDay) == kind }
            .map { userSup in
                TimeBlockSectionView.SupplementItem(
                    id: userSup.id,
                    userSupplement: userSup,
                    definition: userSup.supplementId.flatMap { definitionsById[$0] },
                    nutrients: userSup.supplementId.flatMap { nutrientsBySupplementId[$0] } ?? [],
                    isTaken: todaySupplementLogIds.contains(userSup.id)
                )
            }
    }

    private func workoutSessionsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.WorkoutSessionItem] {
        var items: [TimeBlockSectionView.WorkoutSessionItem] = []

        if let (workout, sessions) = todayWorkout, !workout.isRestDay {
            items += sessions
                .filter { timeBlockService.blockForWorkoutSession(timeSlot: $0.timeSlot) == kind }
                .sorted { (TimeParser.minutesSinceMidnight(from: $0.timeSlot) ?? 540) < (TimeParser.minutesSinceMidnight(from: $1.timeSlot) ?? 540) }
                .map { session in
                    TimeBlockSectionView.WorkoutSessionItem(
                        id: session.id, session: session,
                        isRestDay: false, dayFocus: workout.dayFocus,
                        isCompleted: todayWorkoutCompletionIds.contains(session.id)
                    )
                }
        }

        items += customWorkouts
            .filter { timeBlockService.blockForWorkoutSession(timeSlot: $0.time ?? "9:00am") == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time ?? "9:00am") ?? 540) < (TimeParser.minutesSinceMidnight(from: $1.time ?? "9:00am") ?? 540) }
            .map { item in
                TimeBlockSectionView.WorkoutSessionItem(
                    id: item.id, customItem: item,
                    isCompleted: todayWorkoutCompletionIds.contains(item.id)
                )
            }

        return items
    }

    private func habitsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.HabitItem] {
        todayHabits
            .filter { habit in
                guard let time = habit.time, !time.isEmpty else { return kind == .morning }
                return timeBlockService.blockForWorkoutSession(timeSlot: time) == kind
            }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time ?? "8:00am") ?? 480) < (TimeParser.minutesSinceMidnight(from: $1.time ?? "8:00am") ?? 480) }
            .map { habit in
                TimeBlockSectionView.HabitItem(
                    id: habit.id, habit: habit,
                    isCompleted: todayHabitLogIds.contains(habit.id)
                )
            }
    }

    // MARK: - Toggle Actions

    private func toggleMeal(_ mealId: String) {
        let isValidMeal = todayMeals.contains { $0.id == mealId } || customMeals.contains { $0.id == mealId }
        guard isValidMeal else { return }

        if let existing = mealCompletions.first(where: { $0.mealId == mealId && $0.date == today }) {
            syncService.queueChange(table: "mealCompletions", action: "delete",
                                    data: ["id": existing.id], modelContext: modelContext)
            modelContext.delete(existing)
        } else {
            let completion = MealCompletion(mealId: mealId, date: today)
            modelContext.insert(completion)
            syncService.queueChange(table: "mealCompletions", action: "upsert",
                                    data: ["id": completion.id, "mealId": mealId, "date": today],
                                    modelContext: modelContext)
        }
        Haptics.completion()
    }

    private func toggleWorkout(_ sessionId: String) {
        if let existing = workoutCompletions.first(where: { $0.workoutId == sessionId && $0.date == today }) {
            syncService.queueChange(table: "workoutCompletions", action: "delete",
                                    data: ["id": existing.id], modelContext: modelContext)
            modelContext.delete(existing)
        } else {
            let completion = WorkoutCompletion(workoutId: sessionId, date: today)
            modelContext.insert(completion)
            syncService.queueChange(table: "workoutCompletions", action: "upsert",
                                    data: ["id": completion.id, "workoutId": sessionId, "date": today],
                                    modelContext: modelContext)
        }
        Haptics.completion()
    }

    private func toggleSupplement(_ suppId: String) {
        guard let userSup = activeRegimen.first(where: { $0.id == suppId }) else { return }
        if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": existing.id, "userSupplementId": userSup.id,
                                           "date": today, "taken": existing.taken],
                                    modelContext: modelContext)
        } else {
            let log = SupplementLog(userSupplementId: userSup.id, date: today, taken: true)
            modelContext.insert(log)
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": log.id, "userSupplementId": userSup.id,
                                           "date": today, "taken": true],
                                    modelContext: modelContext)
        }
        Haptics.completion()
    }

    private func toggleHabit(_ habitId: String) {
        if let existing = habitLogs.first(where: { $0.habitId == habitId && $0.date == today }) {
            existing.completed.toggle()
            syncService.queueChange(table: "habitLogs", action: "upsert",
                                    data: ["id": existing.id, "habitId": habitId, "date": today, "completed": existing.completed],
                                    modelContext: modelContext)
        } else {
            let log = HabitLog(habitId: habitId, date: today, completed: true)
            modelContext.insert(log)
            syncService.queueChange(table: "habitLogs", action: "upsert",
                                    data: ["id": log.id, "habitId": habitId, "date": today, "completed": true],
                                    modelContext: modelContext)
        }
        Haptics.completion()
    }
}
