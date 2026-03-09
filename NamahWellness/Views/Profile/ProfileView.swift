import SwiftUI
import SwiftData

struct ProfileView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \CycleLog.createdAt, order: .reverse) private var cycleLogs: [CycleLog]
    @Query private var symptomLogs: [SymptomLog]
    @Query private var mealCompletions: [MealCompletion]
    @Query private var workoutCompletions: [WorkoutCompletion]
    @Query private var supplementLogs: [SupplementLog]

    @State private var showLogSheet = false
    @State private var newPeriodDate = Date()

    private var profile: UserProfile {
        if let p = profiles.first { return p }
        let p = UserProfile()
        modelContext.insert(p)
        return p
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsHeader
                notificationsSection

                Divider().padding(.vertical, 4)

                cycleLogSection
                symptomPatternsSection
                streaksSection
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogSheet) {
            logPeriodSheet
        }
    }

    // MARK: - Settings Header

    private var settingsHeader: some View {
        VStack(spacing: 16) {
            initialsAvatar

            TextField("Your Name", text: Binding(
                get: { profile.name },
                set: { profile.name = $0 }
            ))
            .font(.title3)
            .fontDesign(.serif)
            .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(cycleService.cycleStats.avgCycleLength)")
                        .font(.title2).fontWeight(.light).fontDesign(.serif)
                    Text("DAY CYCLE")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.5).foregroundStyle(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(cycleService.cycleStats.avgPeriodLength)")
                        .font(.title2).fontWeight(.light).fontDesign(.serif)
                    Text("DAY PERIOD")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.5).foregroundStyle(.secondary)
                }
            }

            Button {
                showLogSheet = true
            } label: {
                Label("Log Period Start", systemImage: "plus.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .foregroundStyle(.white)
                    .background(phaseColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var initialsAvatar: some View {
        let initials = profile.name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
        let display = initials.isEmpty ? "?" : initials

        return Text(display)
            .font(.title)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .frame(width: 80, height: 80)
            .background(Circle().fill(phaseColor))
    }

    private var phaseColor: Color {
        PhaseColors.forSlug(cycleService.currentPhase?.phaseSlug ?? "follicular").color
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTIFICATIONS")
                .namahLabel()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Digest")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Reminder to log symptoms & meals")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { profile.dailyReminderEnabled },
                        set: { newValue in
                            profile.dailyReminderEnabled = newValue
                            Task {
                                if newValue {
                                    let granted = await NotificationService.requestPermissionIfNeeded()
                                    if granted {
                                        await NotificationService.scheduleDailyReminder(at: profile.dailyReminderTime)
                                    } else {
                                        profile.dailyReminderEnabled = false
                                    }
                                } else {
                                    NotificationService.cancelDailyReminder()
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .padding(14)

                if profile.dailyReminderEnabled {
                    Divider().padding(.leading, 14)
                    DatePicker("Time", selection: Binding(
                        get: { profile.dailyReminderTime },
                        set: { newValue in
                            profile.dailyReminderTime = newValue
                            Task {
                                await NotificationService.scheduleDailyReminder(at: newValue)
                            }
                        }
                    ), displayedComponents: .hourAndMinute)
                    .padding(14)
                }

                Divider().padding(.leading, 14)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Period Prediction")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Notifies 3 days before predicted start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { profile.periodReminderEnabled },
                        set: { newValue in
                            profile.periodReminderEnabled = newValue
                            Task {
                                if newValue {
                                    let granted = await NotificationService.requestPermissionIfNeeded()
                                    if granted, let lastLog = cycleLogs.first {
                                        await NotificationService.schedulePeriodPrediction(
                                            lastPeriodStart: lastLog.periodStartDate,
                                            avgCycleLength: cycleService.cycleStats.avgCycleLength
                                        )
                                    } else {
                                        profile.periodReminderEnabled = false
                                    }
                                } else {
                                    NotificationService.cancelPeriodPrediction()
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .padding(14)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Cycle Log

    private var cycleLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CYCLE LOG")
                .namahLabel()

            if cycleLogs.isEmpty {
                Text("Log your first period to start tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                let sorted = cycleLogs.sorted { $0.periodStartDate > $1.periodStartDate }
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, log in
                        cycleLogRow(log, in: sorted)
                            .padding(14)
                        if index < sorted.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func cycleLogRow(_ log: CycleLog, in sorted: [CycleLog]) -> some View {
        let displayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d, yyyy"
            return f
        }()

        let startDate = dateFormatter.date(from: log.periodStartDate)
        let displayDate = startDate.map { displayFormatter.string(from: $0) } ?? log.periodStartDate

        // sorted is newest-first; the next element is the older log
        let cycleLength: Int? = {
            guard let idx = sorted.firstIndex(where: { $0.id == log.id }),
                  idx > 0 else { return nil }
            let newerLog = sorted[idx - 1]
            guard let s = dateFormatter.date(from: log.periodStartDate),
                  let e = dateFormatter.date(from: newerLog.periodStartDate) else { return nil }
            let days = Calendar.current.dateComponents([.day], from: s, to: e).day
            return (days != nil && days! > 0 && days! <= 60) ? days : nil
        }()

        let avg = cycleService.cycleStats.avgCycleLength
        let delta: Int? = cycleLength.map { $0 - avg }

        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(displayDate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let len = cycleLength {
                    Text("\(len) day cycle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let d = delta {
                Text(d == 0 ? "avg" : (d > 0 ? "+\(d)" : "\(d)"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(deltaColor(d))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(deltaColor(d).opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta == 0 { return .secondary }
        if abs(delta) <= 2 { return .phaseF }
        return .phaseM
    }

    // MARK: - Symptom Patterns

    private var symptomPatternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SYMPTOM PATTERNS")
                .namahLabel()

            let insights = computeSymptomInsights()
            if insights.isEmpty {
                Text("Log symptoms daily to unlock patterns.")
                    .font(.caption)
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
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(insight.text)
                                .font(.caption)
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

    private struct SymptomInsight {
        let icon: String
        let text: String
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

        let sortedLogs = cycleLogs.sorted { $0.periodStartDate < $1.periodStartDate }

        var insights: [SymptomInsight] = []

        for symptom in symptoms {
            var dayIntensities: [Int: [Int]] = [:]

            for log in symptomLogs {
                guard let value = log[keyPath: symptom.keyPath], value > 0,
                      let logDate = dateFormatter.date(from: log.date) else { continue }

                if let cd = cycleDay(for: logDate, logs: sortedLogs, avgCycle: avgCycle) {
                    dayIntensities[cd, default: []].append(value)
                }
            }

            guard !dayIntensities.isEmpty else { continue }

            let dayAverages = dayIntensities.mapValues { values in
                Double(values.reduce(0, +)) / Double(values.count)
            }
            let peakDays = dayAverages.filter { $0.value >= 2.5 }.keys.sorted()
            guard !peakDays.isEmpty else { continue }

            let peakStart = peakDays.first!
            let peakEnd = peakDays.last!

            let phaseName = phaseMap.first { peakStart >= $0.start && peakStart <= $0.end }?.name ?? "cycle"

            let dayRange = peakStart == peakEnd ? "day \(peakStart)" : "days \(peakStart)\u{2013}\(peakEnd)"
            insights.append(SymptomInsight(
                icon: symptom.icon,
                text: "\(symptom.name) peaks on \(dayRange) (\(phaseName))"
            ))
        }

        return Array(insights.prefix(4))
    }

    private func cycleDay(for date: Date, logs: [CycleLog], avgCycle: Int) -> Int? {
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

    // MARK: - Streaks

    private var streaksSection: some View {
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
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
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
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
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
                    modelContext.insert(CycleLog(periodStartDate: dateFormatter.string(from: newPeriodDate)))
                    showLogSheet = false
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
}
