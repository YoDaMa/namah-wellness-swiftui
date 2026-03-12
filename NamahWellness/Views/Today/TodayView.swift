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
    @Query private var coreExercises: [CoreExercise]
    @Query private var cycleLogs: [CycleLog]
    @Query private var profiles: [UserProfile]
    @Query private var schedules: [DailySchedule]

    @Environment(SyncService.self) private var syncService
    @Environment(AuthService.self) private var authService
    @Environment(CycleLogManager.self) private var cycleLogManager: CycleLogManager?
    @Environment(TimeBlockService.self) private var timeBlockService

    @State private var showProfile = false
    @State private var showCoreProtocol = false
    @State private var showLogSupplement = false
    @State private var showLogPeriod = false
    @State private var showSymptoms = false
    @State private var showPhaseDetail = false

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

    // MARK: - Computed Data

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

    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }

    private var todaySupplementLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }

    private var todayExtraSupplements: [(def: SupplementDefinition, log: SupplementLog)] {
        let activeIds = Set(activeRegimen.map(\.id))
        return supplementLogs
            .filter { $0.date == today && $0.taken && $0.userSupplementId.hasPrefix("extra-") && !activeIds.contains($0.userSupplementId) }
            .compactMap { log in
                let defId = String(log.userSupplementId.dropFirst("extra-".count))
                guard let def = definitions.first(where: { $0.id == defId }) else { return nil }
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

        // Check if today has any completions (meals or supplements)
        let todayHasActivity = !todayMealCompletionIds.isEmpty || !todaySupplementLogIds.isEmpty

        // Start checking from today (if active) or yesterday
        var checkDate = todayStart
        if !todayHasActivity {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) else { return 0 }
            checkDate = yesterday
        }

        for dayOffset in 0..<365 {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: checkDate) else { break }
            let dateStr = dateFormatter.string(from: date)

            let hasMeal = mealCompletions.contains { $0.date == dateStr }
            let hasSupp = supplementLogs.contains { $0.date == dateStr && $0.taken }

            if hasMeal || hasSupp {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Progress

    private var totalActionableItems: Int {
        todayMeals.count + activeRegimen.count
    }

    private var completedActionableItems: Int {
        let completedMeals = todayMeals.filter { todayMealCompletionIds.contains($0.id) }.count
        let completedSupps = activeRegimen.filter { todaySupplementLogIds.contains($0.id) }.count
        return completedMeals + completedSupps
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
        switch hour {
        case 0..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var phaseOneLiner: String? {
        guard let phase = cycleService.currentPhase else { return nil }
        switch phase.phaseSlug {
        case "menstrual":  return "Rest is productive today — honor your body's need to slow down."
        case "follicular": return "Your energy is building — great day for trying something new."
        case "ovulatory":  return "Peak energy and confidence — make the most of it."
        case "luteal":     return "Winding down — focus on comfort foods and gentle movement."
        default:           return nil
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
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

                    // 2. Time Block Sections
                    if hasCycleData {
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
                    Button { showProfile = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
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
                        SymptomsTabView(
                            todaySymptomLog: todaySymptomLog,
                            todayNote: todayNote,
                            today: today,
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
            .sheet(isPresented: $showLogSupplement) {
                LogSupplementSheet(phaseColor: phaseColor)
            }
            .sheet(isPresented: $showCoreProtocol) {
                coreProtocolSheet
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

        ForEach(blocks) { block in
            let meals = mealsForBlock(block.kind)
            let supps = supplementsForBlock(block.kind)
            let sessions = workoutSessionsForBlock(block.kind)
            let isCheckIn = block.kind == .evening
            let isCurrentBlock = block.kind == currentKind

            let nextBlock: TimeBlock? = {
                guard let idx = blocks.firstIndex(where: { $0.kind == block.kind }),
                      idx + 1 < blocks.count else { return nil }
                return blocks[idx + 1]
            }()

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
                onToggleSupplement: { suppId in
                    toggleSupplement(suppId)
                    Haptics.completion()
                },
                onCheckIn: {
                    showSymptoms = true
                }
            )
            .padding(.horizontal)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCurrentBlock)
        }

        // Core Protocol (shown once, after time blocks, if workout exists and not rest day)
        if let (workout, _) = todayWorkout, !workout.isRestDay, !coreExercises.isEmpty {
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
        todayMeals
            .filter { timeBlockService.blockForMeal(time: $0.time, mealType: $0.mealType) == kind }
            .sorted { ($0.time).localizedStandardCompare($1.time) == .orderedAscending }
            .map { meal in
                TimeBlockSectionView.MealItem(
                    id: meal.id,
                    meal: meal,
                    isCompleted: todayMealCompletionIds.contains(meal.id)
                )
            }
    }

    private func supplementsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.SupplementItem] {
        activeRegimen
            .filter { timeBlockService.blockForSupplement(timeOfDay: $0.timeOfDay) == kind }
            .map { userSup in
                TimeBlockSectionView.SupplementItem(
                    id: userSup.id,
                    userSupplement: userSup,
                    definition: definitions.first { $0.id == userSup.supplementId },
                    nutrients: supplementNutrients.filter { $0.supplementId == userSup.supplementId },
                    isTaken: todaySupplementLogIds.contains(userSup.id)
                )
            }
    }

    private func workoutSessionsForBlock(_ kind: TimeBlockKind) -> [TimeBlockSectionView.WorkoutSessionItem] {
        guard let (workout, sessions) = todayWorkout, !workout.isRestDay else { return [] }
        return sessions
            .filter { timeBlockService.blockForWorkoutSession(timeSlot: $0.timeSlot) == kind }
            .sorted { (TimeParser.minutesSinceMidnight(from: $0.timeSlot) ?? 0) < (TimeParser.minutesSinceMidnight(from: $1.timeSlot) ?? 0) }
            .map { session in
                TimeBlockSectionView.WorkoutSessionItem(
                    id: session.id,
                    session: session,
                    isRestDay: false,
                    dayFocus: workout.dayFocus
                )
            }
    }

    // MARK: - Core Protocol Card

    private var coreProtocolCard: some View {
        Button { showCoreProtocol = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.core.training")
                    .font(.sans(14))
                    .foregroundStyle(phaseColor)
                Text("Core Protocol")
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(coreExercises.count) exercises")
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.sans(11)).fontWeight(.medium)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

            Button {
                showLogSupplement = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.sans(16))
                        .foregroundStyle(phaseColor)
                    Text("Log Extra Supplement")
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
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
        guard let meal = todayMeals.first(where: { $0.id == mealId }) else { return }
        if let existing = mealCompletions.first(where: { $0.mealId == meal.id && $0.date == today }) {
            syncService.queueChange(table: "mealCompletions", action: "delete",
                                    data: ["id": existing.id], modelContext: modelContext)
            modelContext.delete(existing)
        } else {
            let completion = MealCompletion(mealId: meal.id, date: today)
            modelContext.insert(completion)
            syncService.queueChange(table: "mealCompletions", action: "upsert",
                                    data: ["id": completion.id, "mealId": meal.id, "date": today],
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

struct SymptomsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    let todaySymptomLog: SymptomLog?
    let todayNote: DailyNote?
    let today: String
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
        SymptomItem(id: "mood", icon: "face.smiling", label: "Mood", lowLabel: "Great", highLabel: "Awful", get: { $0.mood }, set: { $0.mood = $1 }),
        SymptomItem(id: "energy", icon: "bolt.fill", label: "Energy", lowLabel: "Drained", highLabel: "Energized", get: { $0.energy }, set: { $0.energy = $1 }),
        SymptomItem(id: "bloating", icon: "wind", label: "Bloating", lowLabel: "None", highLabel: "A lot", get: { $0.bloating }, set: { $0.bloating = $1 }),
        SymptomItem(id: "fatigue", icon: "moon.zzz.fill", label: "Fatigue", lowLabel: "Alert", highLabel: "Exhausted", get: { $0.fatigue }, set: { $0.fatigue = $1 }),
        SymptomItem(id: "headache", icon: "brain.head.profile", label: "Headache", lowLabel: "None", highLabel: "Splitting", get: { $0.headache }, set: { $0.headache = $1 }),
        SymptomItem(id: "anxiety", icon: "heart.text.clipboard", label: "Anxiety", lowLabel: "Calm", highLabel: "Very anxious", get: { $0.anxiety }, set: { $0.anxiety = $1 }),
        SymptomItem(id: "irritability", icon: "flame.fill", label: "Irritability", lowLabel: "Patient", highLabel: "Very irritable", get: { $0.irritability }, set: { $0.irritability = $1 }),
        SymptomItem(id: "sleepQuality", icon: "moon.fill", label: "Sleep", lowLabel: "Restless", highLabel: "Slept great", get: { $0.sleepQuality }, set: { $0.sleepQuality = $1 }),
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            flowSection
            symptomsSection
            notesSection
        }
        .onAppear {
            syncLocalState()
        }
        .onChange(of: todaySymptomLog?.flowIntensity) {
            if let flow = todaySymptomLog?.flowIntensity,
               let idx = flowOptions.firstIndex(of: flow) {
                selectedFlow = idx
            } else {
                selectedFlow = 0
            }
        }
    }

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
                        let log = getOrCreateLog()
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

    private func symptomSliderRow(_ symptom: SymptomItem) -> some View {
        let currentValue = Double(todaySymptomLog.flatMap { symptom.get($0) } ?? 0)

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
                        let log = getOrCreateLog()
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

    private func getOrCreateLog() -> SymptomLog {
        if let existing = todaySymptomLog { return existing }
        let log = SymptomLog(date: today)
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

    private func syncLocalState() {
        noteText = todayNote?.content ?? ""
        if let flow = todaySymptomLog?.flowIntensity,
           let idx = flowOptions.firstIndex(of: flow) {
            selectedFlow = idx
        } else {
            selectedFlow = 0
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
        if let existing = todayNote {
            existing.content = noteText
            existing.updatedAt = Date()
            syncService.queueChange(table: "dailyNotes", action: "upsert",
                                    data: ["id": existing.id, "date": existing.date, "content": noteText],
                                    modelContext: modelContext)
        } else if !noteText.isEmpty {
            let note = DailyNote(date: today, content: noteText)
            modelContext.insert(note)
            syncService.queueChange(table: "dailyNotes", action: "upsert",
                                    data: ["id": note.id, "date": today, "content": noteText],
                                    modelContext: modelContext)
        }
    }
}
