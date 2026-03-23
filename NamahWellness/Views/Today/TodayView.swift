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
    @Query private var definitions: [SupplementDefinition]
    @Query private var supplementNutrients: [SupplementNutrient]
    @Query private var userSupplements: [UserSupplement]
    @Query private var supplementLogs: [SupplementLog]
    @Query private var coreExercises: [CoreExercise]
    @Query private var cycleLogs: [CycleLog]
    @Query private var profiles: [UserProfile]
    @Query private var schedules: [DailySchedule]
    @Query private var bbtLogs: [BBTLog]
    @Query private var sexualActivityLogs: [SexualActivityLog]
    @Query private var userPlanItems: [UserPlanItem]
    @Query private var userItemsHidden: [UserItemHidden]

    @Environment(SyncService.self) private var syncService
    @Environment(AuthService.self) private var authService
    @Environment(CycleLogManager.self) private var cycleLogManager: CycleLogManager?
    @Environment(TimeBlockService.self) private var timeBlockService

    @State private var showProfile = false
    @State private var showCoreProtocol = false
    @State private var showLogSupplement = false
    @State private var showLogMeal = false
    @State private var showLogWorkout = false
    @State private var appearedBlocks: Set<TimeBlockKind> = []
    @State private var showLogPeriod = false
    @State private var showSymptoms = false
    @State private var showPhaseDetail = false
    @State private var mealPresentation: MealDetailPresentation?
    @State private var workoutPresentation: WorkoutDetailPresentation?

    @AppStorage("lastOverdueDismissDate") private var lastOverdueDismissDate: String = ""

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private var today: String {
        dateFormatter.string(from: Date())
    }

    private var hasCycleData: Bool {
        cycleService.currentPhase != nil
    }

    private var isOverdue: Bool {
        cycleService.cycleStats.isOverdue
    }

    private var daysOverdue: Int {
        cycleService.cycleStats.daysOverdue
    }

    private var daysSinceLastPeriod: Int {
        cycleService.currentPhase.map { $0.cycleDay } ?? 0
    }

    private var shouldShowPeriodPrompt: Bool {
        isOverdue && lastOverdueDismissDate != today
    }

    // MARK: - Computed Data

    private var hiddenIds: Set<String> {
        Set(userItemsHidden.map(\.itemId))
    }

    private var customMeals: [UserPlanItem] {
        userPlanItems.filter { $0.category == .meal && $0.isActive && $0.appliesOnDate(today) }
    }

    private var customWorkouts: [UserPlanItem] {
        userPlanItems.filter { $0.category == .workout && $0.isActive && $0.appliesOnDate(today) }
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

    private var todaySymptomLog: SymptomLog? {
        symptomLogs.first { $0.date == today }
    }

    private var todayNote: DailyNote? {
        dailyNotes.first { $0.date == today }
    }

    private var todayBBTLog: BBTLog? {
        bbtLogs.first { $0.date == today }
    }

    private var todaySexualActivityLogs: [SexualActivityLog] {
        sexualActivityLogs.filter { $0.date == today }
    }

    private var currentPhaseRecord: Phase? {
        guard let slug = cycleService.currentPhase?.phaseSlug else { return nil }
        return phases.first { $0.slug == slug }
    }

    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }

    private var todaySupplementLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }

    private var todayExtraSupplements: [(def: SupplementDefinition, log: SupplementLog)] {
        let activeIds = Set(activeRegimen.map(\.id))
        // Pre-compute dictionary for O(1) lookups
        let definitionsById = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        
        return supplementLogs
            .filter { $0.date == today && $0.taken && $0.userSupplementId.hasPrefix("extra-") && !activeIds.contains($0.userSupplementId) }
            .compactMap { log in
                let defId = String(log.userSupplementId.dropFirst("extra-".count))
                guard let def = definitionsById[defId] else { return nil }  // O(1) lookup
                return (def: def, log: log)
            }
    }

    private var firstName: String {
        let name = profiles.first?.name ?? ""
        return name.split(separator: " ").first.map(String.init) ?? ""
    }

    private var phaseColor: Color {
        cycleService.currentPhase.flatMap { PhaseColors.forSlug($0.phaseSlug).color } ?? .spice
    }

    // MARK: - Streak

    private var currentStreak: Int {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        var streak = 0

        // Pre-compute sets of dates with activity (MUCH faster than repeated .contains)
        let mealDates = Set(mealCompletions.map(\.date))
        let suppDates = Set(supplementLogs.filter(\.taken).map(\.date))
        let allActivityDates = mealDates.union(suppDates)

        // Check if today has any completions
        let todayStr = dateFormatter.string(from: todayStart)
        let todayHasActivity = allActivityDates.contains(todayStr)

        // Start checking from today (if active) or yesterday
        var checkDate = todayStart
        if !todayHasActivity {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) else { return 0 }
            checkDate = yesterday
        }

        // Limit to 365 days, but break early on first gap
        for dayOffset in 0..<365 {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: checkDate) else { break }
            let dateStr = dateFormatter.string(from: date)

            // Fast O(1) set lookup instead of O(n) array scan
            if allActivityDates.contains(dateStr) {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Progress

    private var totalActionableItems: Int {
        todayMeals.count + customMeals.count + activeRegimen.count
    }

    private var completedActionableItems: Int {
        let completedMeals = todayMeals.filter { todayMealCompletionIds.contains($0.id) }.count
        let completedCustomMeals = customMeals.filter { todayMealCompletionIds.contains($0.id) }.count
        let completedSupps = activeRegimen.filter { todaySupplementLogIds.contains($0.id) }.count
        return completedMeals + completedCustomMeals + completedSupps
    }

    // MARK: - Check-In State

    private var hasFlow: Bool {
        todaySymptomLog?.flowIntensity != nil && todaySymptomLog?.flowIntensity != "none"
    }

    private var hasSymptoms: Bool {
        guard let log = todaySymptomLog else { return false }
        return [log.mood, log.energy, log.cramps, log.bloating, log.fatigue].compactMap({ $0 }).count > 0
    }

    private var hasNote: Bool {
        todayNote != nil && !(todayNote?.content.isEmpty ?? true)
    }

    private var hasAnyCheckIn: Bool {
        hasFlow || hasSymptoms || hasNote
    }

    // MARK: - Time-of-Day Greeting

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let phase = cycleService.currentPhase?.phaseSlug
        return NamahCopy.greeting(phase: phase, hour: hour).title
    }

    private var phaseOneLiner: String? {
        guard let phase = cycleService.currentPhase else { return nil }
        let hour = Calendar.current.component(.hour, from: Date())
        return NamahCopy.greeting(phase: phase.phaseSlug, hour: hour).subtitle
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: NamahSpacing.relaxed) {
                    // 1. Greeting + Phase Hero
                    VStack(alignment: .leading, spacing: 16) {
                        if !firstName.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(timeGreeting), \(firstName).")
                                    .font(.prose(72))
                                    .foregroundStyle(.primary)

                                if let oneLiner = phaseOneLiner {
                                    Text(oneLiner)
                                        .font(.prose(13, relativeTo: .footnote))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if let phase = cycleService.currentPhase {
                            Button { showPhaseDetail = true } label: {
                                PhaseHeroCard(
                                    phase: phase,
                                    cycleStats: cycleService.cycleStats,
                                    heroTitle: currentPhaseRecord?.heroTitle,
                                    heroSubtitle: currentPhaseRecord?.heroSubtitle,
                                    exerciseIntensity: currentPhaseRecord?.exerciseIntensity
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Progress bar
                        if totalActionableItems > 0 {
                            TimeBlockProgressBar(
                                completed: completedActionableItems,
                                total: totalActionableItems,
                                streak: currentStreak,
                                phaseColor: phaseColor
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    // 2. Period prompt + Time Block Sections
                    if hasCycleData {
                        if shouldShowPeriodPrompt {
                            periodPromptBanner
                                .padding(.horizontal)
                        }
                        timeBlockSections
                    } else {
                        logCycleCTA
                            .padding(.horizontal)
                    }

                    // 3. Extra supplements + Log button
                    extrasSection
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            Button {
                                showLogMeal = true
                            } label: {
                                Label("Add Meal", systemImage: "fork.knife")
                            }
                            Button {
                                showLogSupplement = true
                            } label: {
                                Label("Log Supplement", systemImage: "pill.fill")
                            }
                            Button {
                                showLogWorkout = true
                            } label: {
                                Label("Add Workout", systemImage: "figure.run")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                        }

                        Button { showProfile = true } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView(cycleService: cycleService)
                }
            }
            .sheet(isPresented: $showPhaseDetail) {
                NavigationStack {
                    if let phase = phases.first(where: { $0.slug == cycleService.currentPhase?.phaseSlug }) {
                        PhaseDetailView(phase: phase, cycleService: cycleService)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showPhaseDetail = false }
                                }
                            }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLogPeriod) {
                if let manager = cycleLogManager {
                    LogPeriodSheet(
                        cycleLogManager: manager,
                        isPresented: $showLogPeriod
                    )
                }
            }
            .sheet(isPresented: $showSymptoms) {
                let slug = cycleService.currentPhase?.phaseSlug ?? "menstrual"
                NavigationStack {
                    ScrollView {
                        DailyTrackingView(
                            symptomLog: todaySymptomLog,
                            dailyNote: todayNote,
                            bbtLog: todayBBTLog,
                            sexualActivityLogs: todaySexualActivityLogs,
                            date: today,
                            phaseSlug: slug
                        )
                        .padding()
                    }
                    .background(
                        PhaseColors.forSlug(slug).soft.opacity(0.3)
                    )
                    .navigationTitle("Today's Check-in")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showSymptoms = false }
                        }
                    }
                }
                .presentationDragIndicator(.visible)
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
            .sheet(isPresented: $showLogSupplement) {
                LogSupplementSheet(phaseColor: phaseColor)
            }
            .sheet(isPresented: $showLogMeal) {
                NavigationStack {
                    AddPlanItemSheet(
                        defaultCategory: .meal,
                        phaseSlug: cycleService.currentPhase?.phaseSlug ?? "menstrual"
                    )
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLogWorkout) {
                NavigationStack {
                    AddPlanItemSheet(
                        defaultCategory: .workout,
                        phaseSlug: cycleService.currentPhase?.phaseSlug ?? "menstrual"
                    )
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCoreProtocol) {
                coreProtocolSheet
            }
            .sheet(item: $workoutPresentation) { presentation in
                WorkoutDetailView(
                    session: presentation.session,
                    customItem: presentation.customItem,
                    dayFocus: presentation.dayFocus,
                    phaseColor: phaseColor,
                    coreExercises: (todayWorkout?.0.hasCoreProtocol == true) ? Array(coreExercises) : []
                )
            }
            .onChange(of: timeBlockService.currentDate) {
                // Day rollover — force refresh of date-dependent computed properties
            }
        }
    }

    // MARK: - Time Block Sections

    @ViewBuilder
    private var timeBlockSections: some View {
        let blocks = timeBlockService.blocks
        let currentKind = timeBlockService.currentBlock?.kind

        ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
            let meals = mealsForBlock(block.kind)
            let supps = supplementsForBlock(block.kind)
            let sessions = workoutSessionsForBlock(block.kind)
            let isCheckIn = block.kind == .evening
            let isCurrentBlock = block.kind == currentKind

            // Use index instead of linear search - O(1) instead of O(n)
            let nextBlock: TimeBlock? = index + 1 < blocks.count ? blocks[index + 1] : nil

            TimeBlockSectionView(
                block: block,
                isCurrent: isCurrentBlock,
                meals: meals,
                supplements: supps,
                workoutSessions: sessions,
                isCheckInBlock: isCheckIn,
                hasCheckedIn: hasAnyCheckIn,
                nextBlockName: nextBlock?.displayName,
                nextBlockTime: nextBlock?.startTimeLabel,
                phaseColor: phaseColor,
                onToggleMeal: { mealId in
                    toggleMeal(mealId)
                    Haptics.completion()
                },
                onTapMeal: { item in
                    let displayable: any MealDisplayable = item.meal ?? item.customItem!
                    mealPresentation = MealDetailPresentation(id: item.id, meal: displayable)
                },
                onToggleSupplement: { suppId in
                    toggleSupplement(suppId)
                    Haptics.completion()
                },
                onCheckIn: {
                    showSymptoms = true
                },
                onToggleWorkout: { sessionId in
                    toggleWorkout(sessionId)
                    Haptics.completion()
                },
                onTapWorkout: { item in
                    workoutPresentation = WorkoutDetailPresentation(
                        id: item.id,
                        session: item.session,
                        customItem: item.customItem,
                        dayFocus: item.dayFocus
                    )
                }
            )
            .padding(.horizontal)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCurrentBlock)
            .opacity(appearedBlocks.contains(block.kind) ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.08)) {
                    _ = appearedBlocks.insert(block.kind)
                }
            }
        }

        // Core Protocol (shown once, after time blocks, if workout exists and not rest day)
        if let (workout, _) = todayWorkout, !workout.isRestDay, !coreExercises.isEmpty, workout.hasCoreProtocol {
            coreProtocolCard
                .padding(.horizontal)
        }

        // Rest day indicator
        if let (workout, _) = todayWorkout, workout.isRestDay {
            restDayCard
                .padding(.horizontal)
        }
    }

    // MARK: - Block Item Grouping

    private func mealsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.MealItem] {
        let templateItems = todayMeals
            .filter { timeBlockService.blockForMeal(time: $0.time, mealType: $0.mealType) == kind }
            .sorted { ($0.time).localizedStandardCompare($1.time) == .orderedAscending }
            .map { meal in
                TimeBlockSectionView.MealItem(
                    id: meal.id,
                    meal: meal,
                    isCompleted: todayMealCompletionIds.contains(meal.id)
                )
            }

        let customItems = customMeals
            .filter { timeBlockService.blockForMeal(time: $0.time ?? "12:00pm", mealType: $0.mealType ?? "Meal") == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time ?? "12:00pm") ?? 720) < (TimeParser.minutesSinceMidnight(from: $1.time ?? "12:00pm") ?? 720) }
            .map { item in
                TimeBlockSectionView.MealItem(
                    id: item.id,
                    customItem: item,
                    isCompleted: todayMealCompletionIds.contains(item.id)
                )
            }

        return templateItems + customItems
    }

    private func supplementsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.SupplementItem] {
        // Pre-compute lookups once instead of inside the map
        let definitionsById = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
        let nutrientsBySupplementId = Dictionary(grouping: supplementNutrients, by: { $0.supplementId })
        
        return activeRegimen
            .filter { timeBlockService.blockForSupplement(timeOfDay: $0.timeOfDay) == kind }
            .map { userSup in
                TimeBlockSectionView.SupplementItem(
                    id: userSup.id,
                    userSupplement: userSup,
                    definition: definitionsById[userSup.supplementId],  // O(1) lookup
                    nutrients: nutrientsBySupplementId[userSup.supplementId] ?? [],  // O(1) lookup
                    isTaken: todaySupplementLogIds.contains(userSup.id)
                )
            }
    }

    private func workoutSessionsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.WorkoutSessionItem] {
        var items: [TimeBlockSectionView.WorkoutSessionItem] = []

        if let (workout, sessions) = todayWorkout, !workout.isRestDay {
            items += sessions
                .filter { timeBlockService.blockForWorkoutSession(timeSlot: $0.timeSlot) == kind }
                .sorted { (TimeParser.minutesSinceMidnight(from: $0.timeSlot) ?? 0) < (TimeParser.minutesSinceMidnight(from: $1.timeSlot) ?? 0) }
                .map { session in
                    TimeBlockSectionView.WorkoutSessionItem(
                        id: session.id,
                        session: session,
                        isRestDay: false,
                        dayFocus: workout.dayFocus,
                        isCompleted: todayWorkoutCompletionIds.contains(session.id)
                    )
                }
        }

        items += customWorkouts
            .filter { timeBlockService.blockForWorkoutSession(timeSlot: $0.time ?? "9:00am") == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.time ?? "9:00am") ?? 540) < (TimeParser.minutesSinceMidnight(from: $1.time ?? "9:00am") ?? 540) }
            .map { item in
                TimeBlockSectionView.WorkoutSessionItem(
                    id: item.id,
                    customItem: item,
                    isCompleted: todayWorkoutCompletionIds.contains(item.id)
                )
            }

        return items
    }

    // MARK: - Core Protocol Card

    private var coreProtocolCard: some View {
        Button { showCoreProtocol = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.core.training")
                    .font(.sans(18))
                    .foregroundStyle(phaseColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Core Protocol")
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("\(coreExercises.count) exercises · phase-matched intensity")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.nCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(phaseColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: NamahRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: NamahRadius.medium)
                    .stroke(phaseColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var restDayCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.sans(14))
                .foregroundStyle(phaseColor)
            Text("REST DAY")
                .font(.nCaption2)
                .fontWeight(.semibold)
                .tracking(2)
                .foregroundStyle(.secondary)
            if let (workout, _) = todayWorkout {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(workout.dayFocus)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Extras Section

    @ViewBuilder
    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Extra supplements logged today
            if !todayExtraSupplements.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("EXTRAS")
                        .namahLabel()

                    ForEach(todayExtraSupplements, id: \.log.id) { item in
                        Button { toggleExtraSupplement(item.def) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.sans(18))
                                    .foregroundStyle(phaseColor)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.def.name)
                                        .font(.nSubheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                        .strikethrough()
                                    if let brand = item.def.brand, !brand.isEmpty {
                                        Text(brand)
                                            .font(.nCaption)
                                            .foregroundStyle(.secondary)
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
                }
            }

        }
    }

    // MARK: - Core Protocol Sheet

    private var coreProtocolSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(coreExercises.enumerated()), id: \.element.id) { index, exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(exercise.name)
                                    .font(.nSubheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(exercise.sets)
                                    .font(.nCaption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(exercise.exerciseDescription)
                                .font(.nCaption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        if index < coreExercises.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Daily Core Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showCoreProtocol = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Period Prompt Banner

    @ViewBuilder
    private var periodPromptBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "drop.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Has your period started?")
                        .font(.nSubheadline)
                        .fontWeight(.semibold)
                    Text("Day \(daysSinceLastPeriod) · \(daysOverdue) day\(daysOverdue == 1 ? "" : "s") late")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    showLogPeriod = true
                } label: {
                    Text("Yes, log it")
                        .font(.nCaption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.phaseM)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    lastOverdueDismissDate = today
                    if let profile = profiles.first {
                        profile.overdueAckDate = today
                        try? modelContext.save()
                    }
                } label: {
                    Text("Not yet")
                        .font(.nCaption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))

        if daysOverdue >= 14 {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(.pink)
                Text("Your period is significantly late. Consider consulting your healthcare provider.")
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.pink.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Log Cycle CTA

    private var logCycleCTA: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.sans(28))
                .foregroundStyle(.secondary)

            Text("Log your cycle to see phase-specific meals, workouts, and supplements.")
                .font(.nSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showLogPeriod = true
            } label: {
                Text("Log Period Start")
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .foregroundStyle(.white)
                    .background(Color.phaseM)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func toggleMeal(_ mealId: String) {
        // Check template meals first, then custom meals
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
            checkAllDoneHaptic()
        }
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
            checkAllDoneHaptic()
        }
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
            if existing.taken { checkAllDoneHaptic() }
        } else {
            let log = SupplementLog(userSupplementId: userSup.id, date: today, taken: true)
            modelContext.insert(log)
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": log.id, "userSupplementId": userSup.id,
                                           "date": today, "taken": true],
                                    modelContext: modelContext)
            checkAllDoneHaptic()
        }
    }

    private func toggleExtraSupplement(_ def: SupplementDefinition) {
        let extraId = "extra-\(def.id)"
        if let existing = supplementLogs.first(where: { $0.userSupplementId == extraId && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": existing.id, "userSupplementId": extraId,
                                           "date": today, "taken": existing.taken],
                                    modelContext: modelContext)
        }
    }

    private func checkAllDoneHaptic() {
        // +1 because this fires before SwiftData updates the query
        let willBeCompleted = completedActionableItems + 1
        if willBeCompleted >= totalActionableItems && totalActionableItems > 0 {
            Haptics.celebration()
        }
    }
}

// MARK: - Workout Detail Presentation

struct WorkoutDetailPresentation: Identifiable {
    let id: String
    let session: WorkoutSession?
    let customItem: UserPlanItem?
    let dayFocus: String
}

// MARK: - Haptics

enum Haptics {
    static func completion() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func blockComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func celebration() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

// MARK: - Symptoms Tab (unchanged — kept in same file for cohesion)

struct DailyTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    let symptomLog: SymptomLog?
    let dailyNote: DailyNote?
    let bbtLog: BBTLog?
    let sexualActivityLogs: [SexualActivityLog]
    let date: String
    let phaseSlug: String

    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }
    private var accentColor: Color { phaseColors.color }

    private struct SymptomItem: Identifiable {
        let id: String
        let icon: String
        let label: String
        let lowLabel: String
        let highLabel: String
        let get: (SymptomLog) -> Int?
        let set: (SymptomLog, Int?) -> Void
    }

    private static let allSymptoms: [SymptomItem] = [
        SymptomItem(id: "cramps", icon: "waveform.path", label: "Cramps", lowLabel: "None", highLabel: "Severe", get: { $0.cramps }, set: { $0.cramps = $1 }),
        SymptomItem(id: "mood", icon: "face.smiling", label: "Mood", lowLabel: "Low", highLabel: "Great", get: { $0.mood }, set: { $0.mood = $1 }),
        SymptomItem(id: "energy", icon: "bolt.fill", label: "Energy", lowLabel: "Low", highLabel: "High", get: { $0.energy }, set: { $0.energy = $1 }),
        SymptomItem(id: "bloating", icon: "wind", label: "Bloating", lowLabel: "None", highLabel: "A lot", get: { $0.bloating }, set: { $0.bloating = $1 }),
        SymptomItem(id: "fatigue", icon: "moon.zzz.fill", label: "Fatigue", lowLabel: "Alert", highLabel: "Exhausted", get: { $0.fatigue }, set: { $0.fatigue = $1 }),
        SymptomItem(id: "headache", icon: "brain.head.profile", label: "Headache", lowLabel: "None", highLabel: "Splitting", get: { $0.headache }, set: { $0.headache = $1 }),
        SymptomItem(id: "anxiety", icon: "heart.text.clipboard", label: "Anxiety", lowLabel: "Calm", highLabel: "Very anxious", get: { $0.anxiety }, set: { $0.anxiety = $1 }),
        SymptomItem(id: "irritability", icon: "flame.fill", label: "Irritability", lowLabel: "Patient", highLabel: "Very irritable", get: { $0.irritability }, set: { $0.irritability = $1 }),
        SymptomItem(id: "sleepQuality", icon: "moon.fill", label: "Sleep", lowLabel: "Poor", highLabel: "Great", get: { $0.sleepQuality }, set: { $0.sleepQuality = $1 }),
        SymptomItem(id: "breastTenderness", icon: "heart.fill", label: "Tenderness", lowLabel: "None", highLabel: "Very sore", get: { $0.breastTenderness }, set: { $0.breastTenderness = $1 }),
        SymptomItem(id: "acne", icon: "circle.dotted", label: "Acne", lowLabel: "Clear", highLabel: "Breaking out", get: { $0.acne }, set: { $0.acne = $1 }),
        SymptomItem(id: "libido", icon: "flame", label: "Libido", lowLabel: "Low", highLabel: "High", get: { $0.libido }, set: { $0.libido = $1 }),
        SymptomItem(id: "appetite", icon: "fork.knife", label: "Appetite", lowLabel: "No appetite", highLabel: "Ravenous", get: { $0.appetite }, set: { $0.appetite = $1 }),
    ]

    private static let phaseRelevant: [String: [String]] = [
        "menstrual": ["cramps", "fatigue", "bloating", "mood"],
        "follicular": ["energy", "mood", "sleepQuality", "appetite"],
        "ovulatory": ["libido", "energy", "mood", "bloating"],
        "luteal": ["mood", "irritability", "bloating", "breastTenderness", "anxiety"],
    ]

    private var orderedSymptoms: [SymptomItem] {
        let relevant = Set(Self.phaseRelevant[phaseSlug] ?? [])
        let top = Self.allSymptoms.filter { relevant.contains($0.id) }
        let rest = Self.allSymptoms.filter { !relevant.contains($0.id) }
        return top + rest
    }

    private let flowOptions = ["none", "spotting", "light", "medium", "heavy"]
    private let flowLabels = ["None", "Spotting", "Light", "Medium", "Heavy"]

    @State private var noteText: String = ""
    @State private var selectedFlow: Int = 0
    @State private var noteSaveTask: Task<Void, Never>?

    // BBT state
    @State private var bbtTemperature: Double = 97.6
    @State private var bbtUnit: TemperatureUnit = .fahrenheit
    @State private var bbtTimeOfMeasurement: Date = {
        Calendar.current.date(from: DateComponents(hour: 6, minute: 30)) ?? Date()
    }()
    @State private var bbtHasEntry: Bool = false

    // Sexual activity state
    @State private var showAddActivity: Bool = false
    @State private var newActivityProtection: ProtectionType = .protected

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            bbtSection
            flowSection
            sexualActivitySection
            symptomsSection
            notesSection
        }
        .onAppear {
            syncLocalState()
        }
        .onChange(of: symptomLog?.flowIntensity) {
            if let flow = symptomLog?.flowIntensity,
               let idx = flowOptions.firstIndex(of: flow) {
                selectedFlow = idx
            } else {
                selectedFlow = 0
            }
        }
    }

    // MARK: - BBT Section

    private var bbtSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BASAL BODY TEMPERATURE")
                    .namahLabel()
                Spacer()
                if bbtHasEntry {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.sans(14))
                }
            }

            if bbtHasEntry {
                // Show current entry with edit capability
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.1f%@", bbtTemperature, bbtUnit.symbol))
                            .font(.display(28, relativeTo: .title))
                            .foregroundStyle(.primary)
                        if let time = bbtLog?.timeOfMeasurement {
                            Text("Measured at \(time.formatted(date: .omitted, time: .shortened))")
                                .font(.nCaption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            bbtHasEntry = false
                        }
                    } label: {
                        Text("Edit")
                            .font(.nCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(accentColor)
                    }
                }
            } else {
                // Entry form
                VStack(spacing: 12) {
                    HStack {
                        Text("Temperature")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Unit", selection: $bbtUnit) {
                            Text("°F").tag(TemperatureUnit.fahrenheit)
                            Text("°C").tag(TemperatureUnit.celsius)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }

                    HStack(spacing: 12) {
                        let range: ClosedRange<Double> = bbtUnit == .fahrenheit ? 95.0...105.0 : 35.0...40.5
                        let step: Double = 0.1

                        Button {
                            if bbtTemperature > range.lowerBound {
                                bbtTemperature = max(range.lowerBound, bbtTemperature - step)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(accentColor)
                        }

                        Text(String(format: "%.1f%@", bbtTemperature, bbtUnit.symbol))
                            .font(.display(32, relativeTo: .title))
                            .monospacedDigit()
                            .frame(minWidth: 120)

                        Button {
                            if bbtTemperature < range.upperBound {
                                bbtTemperature = min(range.upperBound, bbtTemperature + step)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    DatePicker("Time measured", selection: $bbtTimeOfMeasurement, displayedComponents: .hourAndMinute)
                        .font(.nCaption)

                    Button {
                        saveBBT()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            bbtHasEntry = true
                        }
                        Haptics.completion()
                    } label: {
                        Text("Save Temperature")
                            .font(.nCaption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sexual Activity Section

    private var sexualActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SEXUAL ACTIVITY")
                    .namahLabel()
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAddActivity.toggle()
                    }
                } label: {
                    Image(systemName: showAddActivity ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.sans(18))
                        .foregroundStyle(accentColor)
                }
            }

            // Existing entries
            if !sexualActivityLogs.isEmpty {
                ForEach(sexualActivityLogs, id: \.id) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.protectionType.icon)
                            .font(.sans(14))
                            .foregroundStyle(accentColor)
                            .frame(width: 24)

                        Text(entry.protectionType.displayName)
                            .font(.nCaption)
                            .fontWeight(.medium)

                        if let time = entry.time {
                            Text(time.formatted(date: .omitted, time: .shortened))
                                .font(.nCaption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            deleteActivityEntry(entry)
                        } label: {
                            Image(systemName: "trash")
                                .font(.nCaption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            // Add new entry
            if showAddActivity {
                VStack(spacing: 10) {
                    Divider()

                    HStack(spacing: 6) {
                        ForEach(ProtectionType.allCases, id: \.rawValue) { type in
                            let isSelected = newActivityProtection == type
                            Button {
                                newActivityProtection = type
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.sans(16))
                                    Text(type.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(accentColor.opacity(0.2))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
                                            )
                                    }
                                }
                                .foregroundStyle(isSelected ? accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        saveActivityEntry()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showAddActivity = false
                        }
                        Haptics.completion()
                    } label: {
                        Text("Log Activity")
                            .font(.nCaption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                }
            } else if sexualActivityLogs.isEmpty {
                Text("Tap + to log sexual activity")
                    .font(.nCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Flow Section

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FLOW")
                .namahLabel()

            HStack(spacing: 4) {
                ForEach(0..<flowOptions.count, id: \.self) { idx in
                    let isSelected = selectedFlow == idx

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedFlow = idx
                        }
                        let log = getOrCreateSymptomLog()
                        log.flowIntensity = flowOptions[idx]
                        queueSymptomSync(log)
                    } label: {
                        Text(flowLabels[idx])
                            .font(.nCaption)
                            .fontWeight(isSelected ? .semibold : .medium)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(accentColor.opacity(0.25))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
                                        )
                                        .shadow(color: accentColor.opacity(0.2), radius: 6, y: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Symptoms Section

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYMPTOMS")
                .namahLabel()

            VStack(spacing: 2) {
                ForEach(orderedSymptoms) { symptom in
                    symptomSliderRow(symptom)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .namahLabel()

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("How are you feeling? Be honest with yourself.")
                        .font(.prose(13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $noteText)
                    .font(.prose(13))
                    .foregroundStyle(.primary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .tint(accentColor)
                    .onChange(of: noteText) {
                        debouncedSaveNote()
                    }
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Symptom Slider

    private func symptomSliderRow(_ symptom: SymptomItem) -> some View {
        let currentValue = Double(symptomLog.flatMap { symptom.get($0) } ?? 0)

        return VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: symptom.icon)
                    .font(.sans(15))
                    .foregroundStyle(currentValue > 0 ? accentColor : .secondary)
                    .frame(width: 20)

                Text(symptom.label)
                    .font(.nCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                if currentValue > 0 {
                    Text("\(Int(currentValue))")
                        .font(.nCaption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                }
            }

            Slider(
                value: Binding(
                    get: { currentValue },
                    set: { newValue in
                        let rounded = Int(newValue.rounded())
                        let log = getOrCreateSymptomLog()
                        symptom.set(log, rounded == 0 ? nil : rounded)
                        queueSymptomSync(log)
                    }
                ),
                in: 0...5,
                step: 1
            )
            .tint(accentColor)

            HStack {
                Text(symptom.lowLabel)
                    .font(.nCaption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(symptom.highLabel)
                    .font(.nCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func getOrCreateSymptomLog() -> SymptomLog {
        if let existing = symptomLog { return existing }
        let log = SymptomLog(date: date)
        modelContext.insert(log)
        return log
    }

    private func queueSymptomSync(_ log: SymptomLog) {
        var data: [String: Any] = [
            "id": log.id,
            "date": log.date,
        ]
        if let v = log.mood { data["mood"] = v }
        if let v = log.energy { data["energy"] = v }
        if let v = log.cramps { data["cramps"] = v }
        if let v = log.bloating { data["bloating"] = v }
        if let v = log.fatigue { data["fatigue"] = v }
        if let v = log.acne { data["acne"] = v }
        if let v = log.headache { data["headache"] = v }
        if let v = log.breastTenderness { data["breastTenderness"] = v }
        if let v = log.sleepQuality { data["sleepQuality"] = v }
        if let v = log.anxiety { data["anxiety"] = v }
        if let v = log.irritability { data["irritability"] = v }
        if let v = log.libido { data["libido"] = v }
        if let v = log.appetite { data["appetite"] = v }
        if let v = log.flowIntensity { data["flowIntensity"] = v }
        syncService.queueChange(table: "symptomLogs", action: "upsert",
                                data: data, modelContext: modelContext)
    }

    private func saveBBT() {
        if let existing = bbtLog {
            existing.temperature = bbtTemperature
            existing.unit = bbtUnit
            existing.timeOfMeasurement = bbtTimeOfMeasurement
        } else {
            let log = BBTLog(
                date: date,
                temperature: bbtTemperature,
                unit: bbtUnit,
                timeOfMeasurement: bbtTimeOfMeasurement
            )
            modelContext.insert(log)
        }
        syncService.queueChange(table: "bbtLogs", action: "upsert",
                                data: [
                                    "id": bbtLog?.id ?? UUID().uuidString,
                                    "date": date,
                                    "temperature": bbtTemperature,
                                    "unit": bbtUnit.rawValue,
                                ],
                                modelContext: modelContext)
    }

    private func saveActivityEntry() {
        let entry = SexualActivityLog(
            date: date,
            time: Date(),
            protectionType: newActivityProtection
        )
        modelContext.insert(entry)
        syncService.queueChange(table: "sexualActivityLogs", action: "upsert",
                                data: [
                                    "id": entry.id,
                                    "date": date,
                                    "protectionType": newActivityProtection.rawValue,
                                ],
                                modelContext: modelContext)
    }

    private func deleteActivityEntry(_ entry: SexualActivityLog) {
        syncService.queueChange(table: "sexualActivityLogs", action: "delete",
                                data: ["id": entry.id],
                                modelContext: modelContext)
        modelContext.delete(entry)
    }

    private func syncLocalState() {
        noteText = dailyNote?.content ?? ""
        if let flow = symptomLog?.flowIntensity,
           let idx = flowOptions.firstIndex(of: flow) {
            selectedFlow = idx
        } else {
            selectedFlow = 0
        }
        if let existing = bbtLog {
            bbtTemperature = existing.temperature
            bbtUnit = existing.unit
            if let time = existing.timeOfMeasurement {
                bbtTimeOfMeasurement = time
            }
            bbtHasEntry = true
        }
    }

    private func debouncedSaveNote() {
        noteSaveTask?.cancel()
        noteSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await MainActor.run { saveNote() }
        }
    }

    private func saveNote() {
        if let existing = dailyNote {
            existing.content = noteText
            existing.updatedAt = Date()
            syncService.queueChange(table: "dailyNotes", action: "upsert",
                                    data: ["id": existing.id, "date": existing.date, "content": noteText],
                                    modelContext: modelContext)
        } else if !noteText.isEmpty {
            let note = DailyNote(date: date, content: noteText)
            modelContext.insert(note)
            syncService.queueChange(table: "dailyNotes", action: "upsert",
                                    data: ["id": note.id, "date": date, "content": noteText],
                                    modelContext: modelContext)
        }
    }
}
