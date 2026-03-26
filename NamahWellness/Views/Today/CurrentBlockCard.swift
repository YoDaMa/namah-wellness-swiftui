import SwiftUI
import SwiftData

/// Focused card showing only the current time block's items.
/// Self-contained: owns its own @Query data and toggle functions.
/// This prevents TodayView re-renders from cascading into the card.
struct CurrentBlockCard: View {
    let cycleService: CycleService
    let onSeeFullDay: () -> Void
    var onOpenMealDetail: ((Meal?, Habit?, String) -> Void)? = nil

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

    private var block: TimeBlock {
        timeBlockService.currentBlock ?? timeBlockService.blocks.first
            ?? TimeBlock(kind: .morning, startMinutes: 360, endMinutes: 660)
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

    private var todayMealCompletionIds: Set<String> {
        Set(mealCompletions.filter { $0.date == today }.map(\.mealId))
    }

    private var todayWorkoutCompletionIds: Set<String> {
        Set(workoutCompletions.filter { $0.date == today }.map(\.workoutId))
    }

    private var todaySupplementLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }

    private var todayHabitLogIds: Set<String> {
        Set(habitLogs.filter { $0.date == today && $0.completed }.map(\.habitId))
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

    private var hasAnyCheckIn: Bool {
        symptomLogs.contains { $0.date == today }
    }

    // MARK: - Grouped Items

    private var meals: [TimeBlockSectionView.MealItem] {
        mealsForBlock(block.kind)
    }

    private var supplements: [TimeBlockSectionView.SupplementItem] {
        supplementsForBlock(block.kind)
    }

    private var sessions: [TimeBlockSectionView.WorkoutSessionItem] {
        workoutSessionsForBlock(block.kind)
    }

    private var blockHabits: [TimeBlockSectionView.HabitItem] {
        habitsForBlock(block.kind)
    }

    private var totalItems: Int {
        meals.count + supplements.count + sessions.count + blockHabits.count
    }

    private var completedItems: Int {
        meals.filter(\.isCompleted).count + supplements.filter(\.isTaken).count
            + sessions.filter(\.isCompleted).count + blockHabits.filter(\.isCompleted).count
    }

    private var isEmpty: Bool {
        meals.isEmpty && supplements.isEmpty && sessions.isEmpty && blockHabits.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if isEmpty {
                emptyBlock
            } else {
                cardContent
            }
            footer
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(phaseColor.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Card Content (extracted to help type-checker)

    private var cardContent: some View {
        TimeBlockSectionView(
            block: block,
            isCurrent: true,
            meals: meals,
            supplements: supplements,
            workoutSessions: sessions,
            habitItems: blockHabits,
            isCheckInBlock: false,
            hasCheckedIn: hasAnyCheckIn,
            nextBlockName: nil,
            nextBlockTime: nil,
            phaseColor: phaseColor,
            onToggleMeal: { toggleMeal($0) },
            onTapMeal: { item in onOpenMealDetail?(item.meal, item.customItem, item.id) },
            onToggleSupplement: { toggleSupplement($0) },
            onCheckIn: { showSymptoms = true },
            onToggleWorkout: { toggleWorkout($0) },
            onTapWorkout: { toggleWorkout($0.id) },
            onToggleHabit: { toggleHabit($0) }
        )
    }

    // MARK: - Empty Block

    private var emptyBlock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: block.icon)
                    .font(.sans(13))
                    .foregroundStyle(phaseColor)

                Text(block.displayName.uppercased())
                    .font(.nCaption2)
                    .fontWeight(.semibold)
                    .tracking(2)
                    .foregroundStyle(phaseColor)

                Spacer()

                Text("NOW")
                    .font(.nCaption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(phaseColor))
            }

            Text("Nothing scheduled")
                .font(.nCaption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Button(action: onSeeFullDay) {
            HStack {
                if totalItems > 0 {
                    Text("\(completedItems) of \(totalItems) done")
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("See full day")
                        .font(.nCaption2)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Block Item Grouping

    private func mealsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.MealItem] {
        let templateItems = todayMeals
            .filter { timeBlockService.blockForMeal(time: $0.time, mealType: $0.mealType) == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time) ?? 720) < (TimeParser.minutesSinceMidnight(from: $1.time) ?? 720) }
            .map { meal in
                TimeBlockSectionView.MealItem(id: meal.id, meal: meal, isCompleted: todayMealCompletionIds.contains(meal.id))
            }

        let customItems = customMeals
            .filter { timeBlockService.blockForMeal(time: $0.time ?? "12:00pm", mealType: $0.mealType ?? "Meal") == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time ?? "12:00pm") ?? 720) < (TimeParser.minutesSinceMidnight(from: $1.time ?? "12:00pm") ?? 720) }
            .map { item in
                TimeBlockSectionView.MealItem(id: item.id, customItem: item, isCompleted: todayMealCompletionIds.contains(item.id))
            }

        return templateItems + customItems
    }

    private func supplementsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.SupplementItem] {
        let definitionsById = Dictionary(definitions.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let nutrientsBySupplementId = Dictionary(grouping: supplementNutrients, by: { $0.supplementId })

        return activeRegimen
            .filter { timeBlockService.blockForSupplement(timeOfDay: $0.timeOfDay) == kind }
            .map { userSup in
                TimeBlockSectionView.SupplementItem(
                    id: userSup.id, userSupplement: userSup,
                    definition: userSup.supplementId.flatMap { definitionsById[$0] },
                    nutrients: userSup.supplementId.flatMap { nutrientsBySupplementId[$0] } ?? [],
                    isTaken: todaySupplementLogIds.contains(userSup.id)
                )
            }
    }

    private func workoutSessionsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.WorkoutSessionItem] {
        var items: [TimeBlockSectionView.WorkoutSessionItem] = []

        if let (workout, wSessions) = todayWorkout, !workout.isRestDay {
            items += wSessions
                .filter { timeBlockService.blockForWorkoutSession(timeSlot: $0.timeSlot) == kind }
                .sorted { (TimeParser.minutesSinceMidnight(from: $0.timeSlot) ?? 540) < (TimeParser.minutesSinceMidnight(from: $1.timeSlot) ?? 540) }
                .map { session in
                    TimeBlockSectionView.WorkoutSessionItem(id: session.id, session: session, isRestDay: false, dayFocus: workout.dayFocus, isCompleted: todayWorkoutCompletionIds.contains(session.id))
                }
        }

        items += customWorkouts
            .filter { timeBlockService.blockForWorkoutSession(timeSlot: $0.time ?? "9:00am") == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time ?? "9:00am") ?? 540) < (TimeParser.minutesSinceMidnight(from: $1.time ?? "9:00am") ?? 540) }
            .map { item in
                TimeBlockSectionView.WorkoutSessionItem(id: item.id, customItem: item, isCompleted: todayWorkoutCompletionIds.contains(item.id))
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
                TimeBlockSectionView.HabitItem(id: habit.id, habit: habit, isCompleted: todayHabitLogIds.contains(habit.id))
            }
    }

    // MARK: - Toggle Actions

    private func toggleMeal(_ mealId: String) {
        let isValidMeal = todayMeals.contains { $0.id == mealId } || customMeals.contains { $0.id == mealId }
        guard isValidMeal else { return }

        if let existing = mealCompletions.first(where: { $0.mealId == mealId && $0.date == today }) {
            syncService.queueChange(table: "mealCompletions", action: "delete", data: ["id": existing.id], modelContext: modelContext)
            modelContext.delete(existing)
        } else {
            let completion = MealCompletion(mealId: mealId, date: today)
            modelContext.insert(completion)
            syncService.queueChange(table: "mealCompletions", action: "upsert", data: ["id": completion.id, "mealId": mealId, "date": today], modelContext: modelContext)
        }
        Haptics.completion()
    }

    private func toggleWorkout(_ sessionId: String) {
        if let existing = workoutCompletions.first(where: { $0.workoutId == sessionId && $0.date == today }) {
            syncService.queueChange(table: "workoutCompletions", action: "delete", data: ["id": existing.id], modelContext: modelContext)
            modelContext.delete(existing)
        } else {
            let completion = WorkoutCompletion(workoutId: sessionId, date: today)
            modelContext.insert(completion)
            syncService.queueChange(table: "workoutCompletions", action: "upsert", data: ["id": completion.id, "workoutId": sessionId, "date": today], modelContext: modelContext)
        }
        Haptics.completion()
    }

    private func toggleSupplement(_ suppId: String) {
        guard let userSup = activeRegimen.first(where: { $0.id == suppId }) else { return }
        if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": existing.id, "userSupplementId": userSup.id, "date": today, "taken": existing.taken],
                                    modelContext: modelContext)
        } else {
            let log = SupplementLog(userSupplementId: userSup.id, date: today, taken: true)
            modelContext.insert(log)
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": log.id, "userSupplementId": userSup.id, "date": today, "taken": true],
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
