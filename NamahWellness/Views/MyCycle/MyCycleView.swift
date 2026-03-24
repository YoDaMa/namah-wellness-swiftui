import SwiftUI
import SwiftData

struct MyCycleView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Query private var cycleLogs: [CycleLog]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query(sort: \Meal.dayNumber) private var meals: [Meal]
    @Query private var phases: [Phase]
    @Query private var symptomLogs: [SymptomLog]
    @Query private var mealCompletions: [MealCompletion]
    @Query private var workoutCompletions: [WorkoutCompletion]
    @Query private var supplementLogs: [SupplementLog]
    @Query private var bbtLogs: [BBTLog]
    @Query private var sexualActivityLogs: [SexualActivityLog]
    @Query private var dailyNotes: [DailyNote]

    // Calendar state
    @State private var anchor: Date = {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: c) ?? Date()
    }()
    @State private var selectedDayId: String? = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }()
    @State private var slideDirection: Edge = .trailing

    // Cycle management state
    @State private var showDeleteConfirm = false
    @State private var logToDelete: CycleLog?
    @State private var showDayDetail = false
    @State private var todayPulse = false

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    /// Cycle logs sorted by periodStartDate (newest first)
    private var sortedLogs: [CycleLog] {
        cycleLogs.sorted { $0.periodStartDate > $1.periodStartDate }
    }

    private var calendarDays: [CalendarDay] {
        CalendarService.generateCalendarDays(
            anchor: anchor, logs: cycleLogs,
            stats: cycleService.cycleStats, phaseRanges: cycleService.phaseRanges
        )
    }

    private var selectedDay: CalendarDay? {
        guard let id = selectedDayId else { return nil }
        return calendarDays.first { $0.id == id }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: anchor)
    }

    // Data lookups for selected day
    private func symptomLog(for dateId: String) -> SymptomLog? {
        symptomLogs.first { $0.date == dateId }
    }

    private func dailyNote(for dateId: String) -> DailyNote? {
        dailyNotes.first { $0.date == dateId }
    }

    private func bbtLog(for dateId: String) -> BBTLog? {
        bbtLogs.first { $0.date == dateId }
    }

    private func sexualActivityEntries(for dateId: String) -> [SexualActivityLog] {
        sexualActivityLogs.filter { $0.date == dateId }
    }

    // Data density: sets of dates that have each data type
    private var datesWithSymptoms: Set<String> {
        Set(symptomLogs.filter { log in
            [log.cramps, log.mood, log.energy, log.bloating, log.fatigue,
             log.headache, log.anxiety, log.irritability, log.sleepQuality,
             log.breastTenderness, log.acne, log.libido, log.appetite]
                .contains { $0 != nil }
        }.map(\.date))
    }

    private var datesWithFlow: Set<String> {
        Set(symptomLogs.filter { $0.flowIntensity != nil && $0.flowIntensity != "none" }.map(\.date))
    }

    private var datesWithBBT: Set<String> {
        Set(bbtLogs.map(\.date))
    }

    private var datesWithSexualActivity: Set<String> {
        Set(sexualActivityLogs.map(\.date))
    }

    /// Logging streak: consecutive days (up to today) with any tracked data
    private var loggingStreak: Int {
        let cal = Calendar.current
        let today = Date()
        let allDates = datesWithSymptoms.union(datesWithFlow).union(datesWithBBT).union(datesWithSexualActivity)
        var streak = 0
        var date = today
        
        // Safety limit: don't check more than 365 days
        for _ in 0..<365 {
            let dateStr = dateFormatter.string(from: date)
            if allDates.contains(dateStr) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return streak
    }

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 0. Header + cycle info pill
                Text("Track your cycle, spot patterns, and understand your body's rhythm.")
                    .font(.prose(16, relativeTo: .body))
                    .foregroundStyle(.primary)

                NavigationLink {
                    EditProfileView(cycleService: cycleService)
                } label: {
                    HStack(spacing: 8) {
                        Label("\(cycleService.cycleStats.effectiveCycleLength) day cycle", systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90")
                        Text("·")
                        Label("\(cycleService.cycleStats.effectivePeriodLength) day period", systemImage: "drop.fill")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }

                // 1. Calendar header + logging streak
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monthTitle)
                            .font(.display(22, relativeTo: .title2))
                            .contentTransition(.numericText())
                        if loggingStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                                Text("\(loggingStreak)-day streak")
                                    .font(.nCaption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                    navigationButtons
                }

                // 2. Legend row
                legendRow

                // 3. Calendar grid with month transition
                calendarGrid
                    .id(monthTitle)
                    .transition(.push(from: slideDirection))
                    .clipped()
                    .simultaneousGesture(monthSwipeGesture)

                // 4. Selected day phase info + tap to view details
                if let day = selectedDay {
                    Button {
                        showDayDetail = true
                    } label: {
                        dayPhaseInfo(day)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // 5. BBT Chart
                if !bbtLogs.isEmpty {
                    BBTChartView(
                        bbtLogs: bbtLogs,
                        cycleLogs: cycleLogs,
                        cycleStats: cycleService.cycleStats,
                        phaseRanges: cycleService.phaseRanges
                    )
                }

                // 6. Divider
                Divider()
                    .padding(.vertical, 4)

                // 7. Cycle stats
                HStack(spacing: 0) {
                    statCard(
                        value: "\(cycleService.cycleStats.effectiveCycleLength)",
                        unit: "days",
                        label: cycleService.cycleStats.userDefaultCycleLength != nil ? "YOUR CYCLE" : "AVG CYCLE"
                    )
                    if cycleService.cycleStats.userDefaultCycleLength != nil
                        && cycleService.cycleStats.observedAvgCycleLength != cycleService.cycleStats.effectiveCycleLength {
                        statCard(
                            value: "\(cycleService.cycleStats.observedAvgCycleLength)",
                            unit: "days",
                            label: "OBSERVED"
                        )
                    }
                    statCard(value: "\(cycleService.cycleStats.effectivePeriodLength)", unit: "days", label: "PERIOD")
                    statCard(value: "\(cycleService.cycleStats.cycleCount)", unit: "", label: "CYCLES")
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 7. Period History
                if !sortedLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PERIOD HISTORY")
                            .namahLabel()

                        VStack(spacing: 0) {
                            ForEach(Array(sortedLogs.enumerated()), id: \.element.id) { index, log in
                                historyRow(log)
                                    .padding(14)
                                if index < sortedLogs.count - 1 {
                                    Divider()
                                        .padding(.leading, 14)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // 8. Symptom Patterns
                symptomPatternsSection

                // 9. Consistency
                consistencySection

            }
            .padding()
        }
        .refreshable {
            await syncService.sync()
        }
        .sensoryFeedback(.selection, trigger: selectedDayId)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("My Cycle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView(cycleService: cycleService)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showDayDetail) {
            if let day = selectedDay {
                DayDetailSheet(
                    day: day,
                    phaseRecord: phases.first { $0.slug == day.phase?.phaseSlug },
                    symptomLog: symptomLog(for: day.id),
                    dailyNote: dailyNote(for: day.id),
                    bbtLog: bbtLog(for: day.id),
                    sexualActivityLogs: sexualActivityEntries(for: day.id)
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                todayPulse = true
            }
        }
        .alert("Delete Period Log?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let log = logToDelete {
                    syncService.queueChange(table: "cycleLogs", action: "delete",
                                            data: ["id": log.id], modelContext: modelContext)
                    modelContext.delete(log)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove this period log from your history.")
        }
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 0) {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.sans(11)).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)

            Button {
                goToToday()
            } label: {
                Text("Today")
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.sans(11)).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func changeMonth(_ delta: Int) {
        slideDirection = delta > 0 ? .trailing : .leading
        withAnimation(.snappy(duration: 0.35)) {
            let cal = Calendar.current
            let c = cal.dateComponents([.year, .month], from: anchor)
            if let firstOfMonth = cal.date(from: c),
               let newDate = cal.date(byAdding: .month, value: delta, to: firstOfMonth) {
                anchor = newDate
            }
        }
    }

    private func goToToday() {
        let cal = Calendar.current
        let currentMonth = cal.dateComponents([.year, .month], from: Date())
        let target = cal.date(from: currentMonth) ?? Date()
        if target > anchor { slideDirection = .trailing }
        else if target < anchor { slideDirection = .leading }
        withAnimation(.snappy(duration: 0.35)) {
            anchor = target
            selectedDayId = dateFormatter.string(from: Date())
        }
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 60)
            .onEnded { value in
                let h = value.translation.width
                guard abs(h) > abs(value.translation.height) * 2 else { return }
                if h < -60 { changeMonth(1) }
                else if h > 60 { changeMonth(-1) }
            }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 12) {
            legendItem("Period", color: .phaseMMid)
            legendItem("Follicular", color: .phaseFMid)
            legendItem("Fertile", color: .phaseOMid)
            legendItem("Luteal", color: .phaseLMid)
        }
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
                .font(.nCaption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        let days = calendarDays

        return VStack(spacing: 2) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    dayCell(day, index: index, in: days)
                }
            }
        }
    }

    private func dayCell(_ day: CalendarDay, index: Int, in days: [CalendarDay]) -> some View {
        let isSelected = selectedDayId == day.id
        let hasFlow = datesWithFlow.contains(day.id)
        let hasSymptoms = datesWithSymptoms.contains(day.id)
        let hasBBT = datesWithBBT.contains(day.id)
        let hasActivity = datesWithSexualActivity.contains(day.id)
        let hasDots = hasFlow || hasSymptoms || hasBBT || hasActivity

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedDayId = day.id
            }
        } label: {
            VStack(spacing: 1) {
                ZStack {
                    if day.phase != nil {
                        phaseBackground(day, index: index, in: days)
                    }

                    if day.isToday {
                        Text("\(day.dayOfMonth)")
                            .font(.nCaption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle().fill(Color.accentColor)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentColor.opacity(todayPulse ? 0.4 : 0), lineWidth: 2)
                                            .scaleEffect(todayPulse ? 1.4 : 1.0)
                                    )
                            )
                    } else {
                        Text("\(day.dayOfMonth)")
                            .font(.nCaption)
                            .foregroundStyle(day.isCurrentMonth ? .primary : .secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)

                // Data density dots
                if hasDots && day.isCurrentMonth {
                    HStack(spacing: 2) {
                        if hasFlow { Circle().fill(Color.phaseM).frame(width: 4, height: 4) }
                        if hasSymptoms { Circle().fill(Color.blue).frame(width: 4, height: 4) }
                        if hasBBT { Circle().fill(Color.green).frame(width: 4, height: 4) }
                        if hasActivity { Circle().fill(Color.purple).frame(width: 4, height: 4) }
                    }
                    .frame(height: 4)
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.primary : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func phaseBackground(_ day: CalendarDay, index: Int, in days: [CalendarDay]) -> some View {
        let slug = day.phase?.phaseSlug ?? ""
        let isPeak = day.phase?.isPeak ?? false
        let color = colorForPhase(slug, isPeak: isPeak)

        let prevSlug = index > 0 ? days[index - 1].phase?.phaseSlug : nil
        let nextSlug = index < days.count - 1 ? days[index + 1].phase?.phaseSlug : nil

        let isStart = prevSlug != slug
        let isEnd = nextSlug != slug

        return UnevenRoundedRectangle(
            topLeadingRadius: isStart ? 12 : 0,
            bottomLeadingRadius: isStart ? 12 : 0,
            bottomTrailingRadius: isEnd ? 12 : 0,
            topTrailingRadius: isEnd ? 12 : 0
        )
        .fill(color.opacity(0.35))
        .padding(.vertical, 4)
    }

    private func colorForPhase(_ slug: String?, isPeak: Bool) -> Color {
        switch slug {
        case "menstrual": return .phaseM
        case "follicular": return .phaseF
        case "ovulatory": return isPeak ? .phaseO : .phaseOMid
        case "luteal": return .phaseL
        default: return .clear
        }
    }

    // MARK: - Day Phase Info

    @ViewBuilder
    private func dayPhaseInfo(_ day: CalendarDay) -> some View {
        if let phase = day.phase {
            let phaseRecord = phases.first { $0.slug == phase.phaseSlug }
            let colors = PhaseColors.forSlug(phase.phaseSlug)
            let slugOrder = ["menstrual", "follicular", "ovulatory", "luteal"]

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    // Phase badge + day counter
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.white.opacity(0.8))
                            .frame(width: 8, height: 8)
                        Text(phase.phaseSlug.uppercased())
                            .font(.nCaption2)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.8))

                        if phase.isProjected {
                            Text("· PROJECTED")
                                .font(.nCaption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    // Hero title
                    if let title = phaseRecord?.heroTitle {
                        Text(title)
                            .font(.display(22, relativeTo: .title2))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Hero subtitle
                    if let subtitle = phaseRecord?.heroSubtitle {
                        Text(subtitle)
                            .font(.prose(13, relativeTo: .footnote))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Footer
                HStack {
                    Text("Day \(phase.dayInPhase) · Cycle day \(phase.cycleDay)")
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    if phase.isPeak {
                        Text("Peak Fertility")
                            .font(.nCaption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    } else {
                        HStack(spacing: 6) {
                            ForEach(slugOrder, id: \.self) { slug in
                                let isCurrent = phase.phaseSlug == slug
                                Circle()
                                    .fill(isCurrent ? .white : .white.opacity(0.3))
                                    .frame(width: isCurrent ? 8 : 6, height: isCurrent ? 8 : 6)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .background(colors.color)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Stats

    private func statCard(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.display(22, relativeTo: .title2))
                    .foregroundStyle(.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.sans(8)).fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - History Row

    private func historyRow(_ log: CycleLog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.periodStartDate)
                    .font(.nSubheadline)
                    .fontWeight(.medium)

                if let override = log.phaseOverride {
                    Text(override.capitalized)
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(PhaseColors.forSlug(override).color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PhaseColors.forSlug(override).soft)
                        .clipShape(Capsule())
                }
            }

            if let nextLog = nextLog(after: log),
               let len = daysBetween(log.periodStartDate, nextLog.periodStartDate) {
                Text("\(len) day cycle")
                    .font(.nCaption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func deleteLogs(at offsets: IndexSet) {
        let logs = sortedLogs
        for index in offsets {
            let log = logs[index]
            syncService.queueChange(table: "cycleLogs", action: "delete",
                                    data: ["id": log.id], modelContext: modelContext)
            modelContext.delete(log)
        }
    }

    private func nextLog(after log: CycleLog) -> CycleLog? {
        let ascending = cycleLogs.sorted { $0.periodStartDate < $1.periodStartDate }
        guard let idx = ascending.firstIndex(where: { $0.id == log.id }),
              idx + 1 < ascending.count else { return nil }
        return ascending[idx + 1]
    }

    private func daysBetween(_ start: String, _ end: String) -> Int? {
        guard let s = dateFormatter.date(from: start),
              let e = dateFormatter.date(from: end) else { return nil }
        return Calendar.current.dateComponents([.day], from: s, to: e).day
    }

    // MARK: - Symptom Patterns

    private struct SymptomInsight {
        let icon: String
        let text: String
    }

    private var symptomPatternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYMPTOM PATTERNS")
                .namahLabel()

            let insights = computeSymptomInsights()
            if insights.isEmpty {
                Text("Log symptoms daily to unlock patterns.")
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                        HStack(spacing: 10) {
                            Image(systemName: insight.icon)
                                .font(.sans(14))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(insight.text)
                                .font(.nCaption)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(14)
                        if index < insights.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func computeSymptomInsights() -> [SymptomInsight] {
        guard symptomLogs.count >= 14 else { return [] }

        let symptoms: [(name: String, icon: String, keyPath: KeyPath<SymptomLog, Int?>)] = [
            ("Fatigue", "moon.zzz.fill", \.fatigue),
            ("Bloating", "wind", \.bloating),
            ("Cramps", "bolt.fill", \.cramps),
            ("Anxiety", "exclamationmark.triangle.fill", \.anxiety),
            ("Headache", "brain.head.profile", \.headache),
            ("Mood", "face.smiling.inverse", \.mood),
            ("Energy", "bolt.heart.fill", \.energy),
            ("Acne", "circle.dotted.circle", \.acne),
            ("Irritability", "flame.fill", \.irritability),
        ]

        let avgCycle = cycleService.cycleStats.avgCycleLength
        let ranges = CycleService.computePhaseRanges(
            cycleLength: avgCycle,
            periodLength: cycleService.cycleStats.avgPeriodLength
        )
        let phaseMap: [(name: String, start: Int, end: Int)] = [
            ("menstrual", ranges.menstrual.start, ranges.menstrual.end),
            ("follicular", ranges.follicular.start, ranges.follicular.end),
            ("ovulatory", ranges.ovulatory.start, ranges.ovulatory.end),
            ("luteal", ranges.luteal.start, ranges.luteal.end),
        ]

        let logsByDate = cycleLogs.sorted { $0.periodStartDate < $1.periodStartDate }

        var insights: [SymptomInsight] = []

        for symptom in symptoms {
            var dayIntensities: [Int: [Int]] = [:]

            for log in symptomLogs {
                guard let value = log[keyPath: symptom.keyPath], value > 0,
                      let logDate = dateFormatter.date(from: log.date) else { continue }

                if let cd = symptomCycleDay(for: logDate, logs: logsByDate, avgCycle: avgCycle) {
                    dayIntensities[cd, default: []].append(value)
                }
            }

            guard !dayIntensities.isEmpty else { continue }

            let dayAverages = dayIntensities.mapValues { values in
                Double(values.reduce(0, +)) / Double(values.count)
            }
            let peakDays = dayAverages.filter { $0.value >= 2.5 }.keys.sorted()
            guard !peakDays.isEmpty else { continue }

            guard let peakStart = peakDays.first, let peakEnd = peakDays.last else { continue }

            let phaseName = phaseMap.first { peakStart >= $0.start && peakStart <= $0.end }?.name ?? "cycle"

            let dayRange = peakStart == peakEnd ? "day \(peakStart)" : "days \(peakStart)\u{2013}\(peakEnd)"
            insights.append(SymptomInsight(
                icon: symptom.icon,
                text: "\(symptom.name) peaks on \(dayRange) (\(phaseName))"
            ))
        }

        return Array(insights.prefix(4))
    }

    private func symptomCycleDay(for date: Date, logs: [CycleLog], avgCycle: Int) -> Int? {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)

        let logDates: [(date: Date, str: String)] = logs.compactMap { log in
            guard let d = dateFormatter.date(from: log.periodStartDate) else { return nil }
            return (cal.startOfDay(for: d), log.periodStartDate)
        }
        guard !logDates.isEmpty else { return nil }

        for i in (0..<logDates.count).reversed() {
            if target >= logDates[i].date {
                let day = (cal.dateComponents([.day], from: logDates[i].date, to: target).day ?? 0) + 1
                return day <= avgCycle ? day : ((day - 1) % avgCycle) + 1
            }
        }
        return nil
    }

    // MARK: - Consistency

    private var phaseColor: Color {
        PhaseColors.forSlug(cycleService.currentPhase?.phaseSlug ?? "follicular").color
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONSISTENCY")
                .namahLabel()

            VStack(spacing: 0) {
                streakRow("Meals", icon: "fork.knife", completionDates: Set(mealCompletions.map(\.date)))
                    .padding(14)
                Divider().padding(.leading, 48)
                streakRow("Workouts", icon: "figure.run", completionDates: Set(workoutCompletions.map(\.date)))
                    .padding(14)
                Divider().padding(.leading, 48)
                streakRow("Supplements", icon: "pill.fill", completionDates: Set(supplementLogs.filter(\.taken).map(\.date)))
                    .padding(14)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func streakRow(_ label: String, icon: String, completionDates: Set<String>) -> some View {
        let cal = Calendar.current
        let today = Date()

        let last7: [String] = (0..<7).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return dateFormatter.string(from: date)
        }
        let count = last7.filter { completionDates.contains($0) }.count

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.sans(14))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .font(.nSubheadline)
                .fontWeight(.medium)
            Spacer()
            HStack(spacing: 4) {
                ForEach(last7, id: \.self) { day in
                    Circle()
                        .fill(completionDates.contains(day) ? phaseColor : Color(uiColor: .tertiarySystemFill))
                        .frame(width: 8, height: 8)
                }
            }
            Text("\(count)/7")
                .font(.nCaption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}
