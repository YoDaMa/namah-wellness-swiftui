import SwiftUI
import SwiftData

struct MyCycleView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CycleLog.createdAt, order: .reverse) private var cycleLogs: [CycleLog]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query(sort: \Meal.dayNumber) private var meals: [Meal]
    @Query private var phases: [Phase]
    @Query private var symptomLogs: [SymptomLog]

    // Calendar state
    @State private var anchor = Date()
    @State private var selectedDayId: String?

    // Cycle management state (from ProfileView)
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
                // 1. Calendar header (month title + nav buttons)
                HStack {
                    Text(monthTitle)
                        .font(.title2)
                        .fontDesign(.serif)
                    Spacer()
                    navigationButtons
                }

                // 2. Legend row
                legendRow

                // 3. Calendar grid
                calendarGrid

                // 4. Selected day phase info
                if let day = selectedDay {
                    dayPhaseInfo(day)
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
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("My Cycle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        AccountSettingsView()
                    } label: {
                        Label("Profile", systemImage: "person")
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
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
            Button { shiftWeeks(-1) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)

            Button {
                anchor = Date()
                selectToday()
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

            Button { shiftWeeks(1) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func shiftWeeks(_ count: Int) {
        if let d = Calendar.current.date(byAdding: .weekOfYear, value: count, to: anchor) { anchor = d }
    }

    private func selectToday() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        selectedDayId = f.string(from: Date())
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
                ForEach(calendarDays) { day in
                    dayCell(day)
                }
            }
        }
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let isSelected = selectedDayId == day.id

        return Button {
            selectedDayId = day.id
        } label: {
            ZStack {
                if day.phase != nil {
                    phaseBackground(day)
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
                        .foregroundStyle(day.isCurrentMonth ? .primary : .quaternary)
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

    private func phaseBackground(_ day: CalendarDay) -> some View {
        let slug = day.phase?.phaseSlug ?? ""
        let isPeak = day.phase?.isPeak ?? false
        let color = colorForPhase(slug, isPeak: isPeak)

        let idx = calendarDays.firstIndex(where: { $0.id == day.id }) ?? 0
        let prevSlug = idx > 0 ? calendarDays[idx - 1].phase?.phaseSlug : nil
        let nextSlug = idx < calendarDays.count - 1 ? calendarDays[idx + 1].phase?.phaseSlug : nil

        let isStart = prevSlug != slug
        let isEnd = nextSlug != slug

        let corners: UIRectCorner = {
            if isStart && isEnd { return .allCorners }
            if isStart { return [.topLeft, .bottomLeft] }
            if isEnd { return [.topRight, .bottomRight] }
            return []
        }()

        return RoundedCornersShape(corners: corners, radius: 12)
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
        modelContext.insert(CycleLog(periodStartDate: dateFormatter.string(from: newPeriodDate)))
        showLogSheet = false
    }

    private func setOverride(_ slug: String) {
        guard let latest = cycleLogs.first else { return }
        latest.phaseOverride = slug
        showOverrideSheet = false
    }

    private func clearOverride() {
        guard let latest = cycleLogs.first else { return }
        latest.phaseOverride = nil
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cycleLogs[index])
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

// MARK: - Helpers

struct RoundedCornersShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect, byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
