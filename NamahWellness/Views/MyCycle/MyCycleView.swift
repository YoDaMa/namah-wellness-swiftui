import SwiftUI
import SwiftData

struct MyCycleView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService
    @Query(sort: \CycleLog.createdAt, order: .reverse) private var cycleLogs: [CycleLog]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query(sort: \Meal.dayNumber) private var meals: [Meal]
    @Query private var phases: [Phase]
    @Query private var symptomLogs: [SymptomLog]

    // Calendar state
    @State private var anchor: Date = {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: c) ?? Date()
    }()
    @State private var selectedDayId: String?
    @State private var slideDirection: Edge = .trailing

    // Cycle management state
    @State private var showProfile = false
    @State private var showLogSheet = false
    @State private var newPeriodDate = Date()
    @State private var showOverrideSheet = false
    @State private var editingLog: CycleLog?
    @State private var editEndDate = Date()
    @State private var showDeleteConfirm = false
    @State private var logToDelete: CycleLog?

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Calendar header
                HStack {
                    Text(monthTitle)
                        .font(.title2)
                        .fontDesign(.serif)
                        .contentTransition(.numericText())
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

                // 4. Selected day phase info
                if let day = selectedDay {
                    dayPhaseInfo(day)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                // 5. Divider
                Divider()
                    .padding(.vertical, 4)

                // 6. Cycle stats
                HStack(spacing: 0) {
                    statCard(value: "\(cycleService.cycleStats.avgCycleLength)", unit: "days", label: "AVG CYCLE")
                    statCard(value: "\(cycleService.cycleStats.avgPeriodLength)", unit: "days", label: "AVG PERIOD")
                    statCard(value: "\(cycleService.cycleStats.cycleCount)", unit: "", label: "CYCLES")
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 7. Action buttons
                VStack(spacing: 0) {
                    Button {
                        showLogSheet = true
                    } label: {
                        HStack {
                            Label("Log Period Start", systemImage: "plus.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                    }

                    Divider()
                        .padding(.leading, 14)

                    Button {
                        showOverrideSheet = true
                    } label: {
                        HStack {
                            Label("Override Phase", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                    }
                }
                .foregroundStyle(.primary)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 8. Period History
                if !cycleLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PERIOD HISTORY")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .tracking(2)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 0) {
                            ForEach(Array(cycleLogs.enumerated()), id: \.element.id) { index, log in
                                historyRow(log)
                                    .padding(14)
                                if index < cycleLogs.count - 1 {
                                    Divider()
                                        .padding(.leading, 14)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // 9. Hormones card
                NavigationLink {
                    HormonesView(cycleService: cycleService)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "flask")
                            .font(.system(size: 20))
                            .foregroundStyle(.phaseO)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hormones")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text("Reference curves scaled to your cycle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .sensoryFeedback(.selection, trigger: selectedDayId)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("My Cycle")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView(cycleService: cycleService)
            }
        }
        .sheet(isPresented: $showLogSheet) {
            logPeriodSheet
        }
        .sheet(isPresented: $showOverrideSheet) {
            overrideSheet
        }
        .sheet(item: $editingLog) { log in
            editEndDateSheet(log)
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)

            Button {
                goToToday()
            } label: {
                Text("Today")
                    .font(.caption2)
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
                    .font(.system(size: 11, weight: .semibold))
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
                .font(.caption2)
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
                        .font(.caption2)
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

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedDayId = day.id
            }
        } label: {
            ZStack {
                if day.phase != nil {
                    phaseBackground(day, index: index, in: days)
                }

                if day.isToday {
                    Text("\(day.dayOfMonth)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.primary))
                } else {
                    Text("\(day.dayOfMonth)")
                        .font(.caption)
                        .foregroundStyle(day.isCurrentMonth ? .primary : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
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
            HStack(spacing: 8) {
                Circle()
                    .fill(colorForPhase(phase.phaseSlug, isPeak: phase.isPeak))
                    .frame(width: 10, height: 10)
                Text(phase.phaseSlug.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Day \(phase.dayInPhase)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if phase.isProjected {
                    Text("Projected")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())
                }
                if phase.isPeak {
                    Text("Peak Fertility")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(colorForPhase(phase.phaseSlug, isPeak: true))
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Stats

    private func statCard(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.light)
                    .fontDesign(.serif)
                    .foregroundStyle(.primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 8, weight: .medium))
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
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let override = log.phaseOverride {
                    Text(override.capitalized)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(PhaseColors.forSlug(override).color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PhaseColors.forSlug(override).soft)
                        .clipShape(Capsule())
                }
            }

            if let end = log.periodEndDate, !end.isEmpty {
                Text("End: \(end)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Add end date") {
                    editEndDate = Date()
                    editingLog = log
                }
                .font(.caption)
            }

            if let nextLog = nextLog(after: log),
               let len = daysBetween(log.periodStartDate, nextLog.periodStartDate) {
                Text("\(len) day cycle")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Log Period Sheet

    private var logPeriodSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("When did your period start?")
                    .font(.title3)
                    .fontDesign(.serif)

                DatePicker("", selection: $newPeriodDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)

                Button {
                    logPeriod()
                } label: {
                    Text("Log Period")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLogSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Override Sheet

    private var overrideSheet: some View {
        NavigationStack {
            List {
                Section("Select Phase") {
                    ForEach(["menstrual", "follicular", "ovulatory", "luteal"], id: \.self) { slug in
                        Button {
                            setOverride(slug)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(PhaseColors.forSlug(slug).color)
                                    .frame(width: 10, height: 10)
                                Text(slug.capitalized)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if cycleService.currentPhase?.phaseSlug == slug && cycleService.currentPhase?.isOverridden == true {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.phaseF)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Use Auto-Detect") {
                        clearOverride()
                        showOverrideSheet = false
                    }
                }
            }
            .navigationTitle("Override Phase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showOverrideSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Edit End Date Sheet

    private func editEndDateSheet(_ log: CycleLog) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("When did your period end?")
                    .font(.title3)
                    .fontDesign(.serif)

                Text("Started: \(log.periodStartDate)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                DatePicker("", selection: $editEndDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)

                Button {
                    log.periodEndDate = dateFormatter.string(from: editEndDate)
                    editingLog = nil
                } label: {
                    Text("Save End Date")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingLog = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func logPeriod() {
        let dateStr = dateFormatter.string(from: newPeriodDate)
        let log = CycleLog(periodStartDate: dateStr)
        modelContext.insert(log)
        syncService.queueChange(table: "cycleLogs", action: "upsert",
                                data: ["id": log.id, "periodStartDate": dateStr],
                                modelContext: modelContext)
        showLogSheet = false
    }

    private func setOverride(_ slug: String) {
        guard let latest = cycleLogs.first else { return }
        latest.phaseOverride = slug
        syncService.queueChange(table: "cycleLogs", action: "upsert",
                                data: ["id": latest.id, "periodStartDate": latest.periodStartDate,
                                       "phaseOverride": slug],
                                modelContext: modelContext)
        showOverrideSheet = false
    }

    private func clearOverride() {
        guard let latest = cycleLogs.first else { return }
        latest.phaseOverride = nil
        syncService.queueChange(table: "cycleLogs", action: "upsert",
                                data: ["id": latest.id, "periodStartDate": latest.periodStartDate],
                                modelContext: modelContext)
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            let log = cycleLogs[index]
            syncService.queueChange(table: "cycleLogs", action: "delete",
                                    data: ["id": log.id], modelContext: modelContext)
            modelContext.delete(log)
        }
    }

    private func nextLog(after log: CycleLog) -> CycleLog? {
        let sorted = cycleLogs.sorted { $0.periodStartDate < $1.periodStartDate }
        guard let idx = sorted.firstIndex(where: { $0.id == log.id }),
              idx + 1 < sorted.count else { return nil }
        return sorted[idx + 1]
    }

    private func daysBetween(_ start: String, _ end: String) -> Int? {
        guard let s = dateFormatter.date(from: start),
              let e = dateFormatter.date(from: end) else { return nil }
        return Calendar.current.dateComponents([.day], from: s, to: e).day
    }
}
