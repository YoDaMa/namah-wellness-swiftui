import SwiftUI
import SwiftData

enum TodayTab: String, CaseIterable, Identifiable {
    case nourish = "NOURISH"
    case move = "MOVE"

    var id: String { rawValue }
}

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

    @Environment(SyncService.self) private var syncService
    @Environment(AuthService.self) private var authService
    @Environment(CycleLogManager.self) private var cycleLogManager: CycleLogManager?

    @State private var selectedTab: TodayTab = .nourish
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
    private let timeSlots = [
        ("morning", "Morning"),
        ("with_meals", "With Meals"),
        ("evening", "Evening"),
        ("as_needed", "As Needed"),
    ]

    private var firstName: String {
        let name = profiles.first?.name ?? ""
        return name.split(separator: " ").first.map(String.init) ?? ""
    }

    private var phaseColor: Color {
        cycleService.currentPhase.flatMap { PhaseColors.forSlug($0.phaseSlug).color } ?? .spice
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // 1. Greeting + Phase context + Check-in (above tabs)
                    VStack(alignment: .leading, spacing: 20) {
                        if !firstName.isEmpty {
                            Text("Hi, \(firstName).")
                                .font(.prose(72))
                                .foregroundStyle(.primary)
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

                        checkInSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                    // 2. Tabbed content
                    Section {
                        Group {
                            switch selectedTab {
                            case .nourish:
                                VStack(alignment: .leading, spacing: 20) {
                                    mealsSection
                                    supplementsSection
                                }
                            case .move:
                                workoutSection
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    } header: {
                        todayStickyHeader
                    }
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
        }
    }

    // MARK: - Sticky Tab Header

    private var todayStickyHeader: some View {
        Picker("Section", selection: $selectedTab) {
            ForEach(TodayTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Meals Section

    @ViewBuilder
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meals")
                .font(.display(36))
                .foregroundStyle(.primary)

            if todayMeals.isEmpty {
                logCycleCTA
            } else {
                MacroSummaryBar(meals: todayMeals, completedIds: todayMealCompletionIds)

                let sorted = todayMeals.sorted { $0.time.localizedStandardCompare($1.time) == .orderedAscending }
                ForEach(sorted, id: \.id) { meal in
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

    /// Parses a time string like "9:00am" or "4:00pm" into minutes since midnight for sorting.
    private func parseTimeSlotMinutes(_ slot: String) -> Int {
        let lower = slot.lowercased().trimmingCharacters(in: .whitespaces)
        let isPM = lower.contains("pm")
        let cleaned = lower.replacingOccurrences(of: "am", with: "").replacingOccurrences(of: "pm", with: "")
        let parts = cleaned.split(separator: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard let hour = parts.first else { return isPM ? 1440 : 0 }
        let minute = parts.count > 1 ? parts[1] : 0
        var h = hour
        if isPM && h != 12 { h += 12 }
        if !isPM && h == 12 { h = 0 }
        return h * 60 + minute
    }

    @ViewBuilder
    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let (workout, sessions) = todayWorkout {
                if workout.isRestDay {
                    HStack(spacing: 8) {
                        Text("REST DAY")
                            .namahLabel()
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(workout.dayFocus)
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Day header
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(workout.dayLabel)
                            .font(.display(36))
                            .foregroundStyle(.primary)
                        if !workout.dayFocus.isEmpty {
                            Text("·")
                                .font(.nCaption)
                                .foregroundStyle(.tertiary)
                            Text(workout.dayFocus)
                                .font(.nCaption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Core Protocol card (separate pill below header)
                    if !coreExercises.isEmpty {
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
                        .sheet(isPresented: $showCoreProtocol) {
                            coreProtocolSheet
                        }
                    }

                    // Sessions sorted chronologically — timeline layout
                    let sorted = sessions.sorted { parseTimeSlotMinutes($0.timeSlot) < parseTimeSlotMinutes($1.timeSlot) }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, session in
                            HStack(alignment: .top, spacing: 0) {
                                // Timeline rail
                                VStack(spacing: 0) {
                                    // Line above dot (invisible for first item)
                                    Rectangle()
                                        .fill(index == 0 ? Color.clear : phaseColor.opacity(0.25))
                                        .frame(width: 2, height: 12)

                                    // Dot
                                    Circle()
                                        .fill(phaseColor)
                                        .frame(width: 10, height: 10)
                                        .overlay(
                                            Circle()
                                                .fill(.white)
                                                .frame(width: 4, height: 4)
                                        )

                                    // Line below dot (invisible for last item)
                                    Rectangle()
                                        .fill(index == sorted.count - 1 ? Color.clear : phaseColor.opacity(0.25))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                                .frame(width: 10)
                                .padding(.trailing, 12)

                                // Time label
                                Text(session.timeSlot)
                                    .font(.nCaption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(phaseColor)
                                    .frame(width: 52, alignment: .leading)
                                    .padding(.top, 1)

                                // Session details
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title.replacingOccurrences(of: ".$", with: "", options: .regularExpression))
                                        .font(.nSubheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(session.sessionDescription)
                                        .font(.nCaption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

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

    // MARK: - Supplements Section

    @ViewBuilder
    private var supplementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supplements")
                .font(.display(36))
                .foregroundStyle(.primary)

            if activeRegimen.isEmpty {
                Text("No supplements yet — add them in the Plan tab")
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
            } else {
                let takenCount = activeRegimen.filter { todaySupplementLogIds.contains($0.id) }.count
                Text("\(takenCount) of \(activeRegimen.count) taken today")
                    .font(.nFootnote)
                    .fontWeight(.medium)

                ForEach(timeSlots, id: \.0) { slot, label in
                    let slotItems = activeRegimen.filter { $0.timeOfDay == slot }
                    if !slotItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(label.uppercased())
                                .namahLabel()

                            ForEach(slotItems, id: \.id) { userSup in
                                supplementCard(userSup)
                            }
                        }
                    }
                }
            }

            // Extra supplements logged today (not in active regimen)
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

    private func supplementCard(_ userSup: UserSupplement) -> some View {
        let def = definitions.first { $0.id == userSup.supplementId }
        let isTaken = todaySupplementLogIds.contains(userSup.id)
        let supNutrients = supplementNutrients.filter { $0.supplementId == userSup.supplementId }

        return Button { toggleSupplement(userSup) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.sans(18))
                    .foregroundStyle(isTaken ? phaseColor : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(def?.name ?? "Unknown")
                        .font(.nSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isTaken ? .secondary : .primary)
                        .strikethrough(isTaken)

                    HStack(spacing: 8) {
                        if let brand = def?.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.nCaption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(Int(userSup.dosage)) \(def?.servingUnit ?? "dose")")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }

                    if !supNutrients.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(supNutrients.prefix(3), id: \.id) { n in
                                Text("\(n.nutrientKey): \(formatAmount(n.amount))\(n.unit)")
                                    .font(.nCaption2)
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

    // MARK: - Check-In Section

    private var checkInSection: some View {
        Button { showSymptoms = true } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasAnyCheckIn ? "Adjust today's notes" : "How are you feeling today?")
                        .font(.display(20, relativeTo: .title3))
                        .foregroundStyle(.primary)

                    if !hasAnyCheckIn {
                        Text("Log your symptoms, flow, and notes — it takes less than a minute.")
                            .font(.prose(13, relativeTo: .footnote))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 5) {
                    // Flow dot
                    Circle()
                        .fill(hasFlow ? phaseColor : phaseColor.opacity(0.2))
                        .frame(width: 7, height: 7)
                    // Symptoms dot
                    Circle()
                        .fill(hasSymptoms ? phaseColor : phaseColor.opacity(0.2))
                        .frame(width: 7, height: 7)
                    // Notes dot
                    Circle()
                        .fill(hasNote ? phaseColor : phaseColor.opacity(0.2))
                        .frame(width: 7, height: 7)
                }

                Image(systemName: "chevron.right")
                    .font(.nCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(phaseColor.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(phaseColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(phaseColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

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

    // MARK: - Log Period Sheet

    // MARK: - Actions

    private func toggleMeal(_ meal: Meal) {
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

    private func toggleSupplement(_ userSup: UserSupplement) {
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
    }

    private func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? "\(Int(amount))" : String(format: "%.1f", amount)
    }
}

// MARK: - Symptoms Tab

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

    // All symptoms with contextual low/high descriptions
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
            // 1. Flow — most important data point, comes first
            flowSection

            // 2. Symptoms — 3-column grid, phase-relevant first
            symptomsSection

            // 3. Notes — warm placeholder
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

    // MARK: - Flow Section (segmented control)

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

    // MARK: - Symptoms Section (slider list)

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

    // MARK: - Symptom Slider Row

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

