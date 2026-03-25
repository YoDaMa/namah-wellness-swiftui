import SwiftUI
import SwiftData

struct ProfileView: View {
    let cycleService: CycleService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(SyncService.self) private var syncService
    @Environment(CycleLogManager.self) private var cycleLogManager: CycleLogManager?
    @Environment(TimeBlockService.self) private var timeBlockService
    @Query private var profiles: [UserProfile]
    @Query private var cycleLogs: [CycleLog]
    @Query private var schedules: [DailySchedule]
    @Query private var allMeals: [Meal]
    @Query private var userSupplements: [UserSupplement]
    @Query private var definitions: [SupplementDefinition]
    @Query private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var phases: [Phase]

    @State private var showLogSheet = false
    @State private var isEditingName = false
    @State private var editedName = ""

    private var profile: UserProfile {
        if let p = profiles.first { return p }
        let p = UserProfile()
        modelContext.insert(p)
        return p
    }

    private var schedule: DailySchedule {
        if let s = schedules.first { return s }
        let s = DailySchedule()
        modelContext.insert(s)
        return s
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private var sortedLogs: [CycleLog] {
        cycleLogs.sorted { $0.periodStartDate > $1.periodStartDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                accountSection

                scheduleSection

                notificationsSection

                Divider().padding(.vertical, 4)

                cycleLogSection

                Divider().padding(.vertical, 4)

                signOutSection

                Image("Logo")
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .opacity(0.4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogSheet) {
            if let manager = cycleLogManager {
                LogPeriodSheet(
                    cycleLogManager: manager,
                    isPresented: $showLogSheet
                )
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCOUNT")
                .namahLabel()

            VStack(spacing: 0) {
                HStack {
                    Text("Name")
                        .font(.nSubheadline)
                    Spacer()
                    if isEditingName {
                        TextField("Your Name", text: $editedName)
                            .font(.nSubheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.name)
                    } else {
                        Text(profile.name.isEmpty ? "—" : profile.name)
                            .font(.nSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        if isEditingName {
                            profile.name = editedName
                            try? modelContext.save()
                            Task { await syncService.pushProfile(profile: profile) }
                            isEditingName = false
                        } else {
                            editedName = profile.name
                            isEditingName = true
                        }
                    } label: {
                        Text(isEditingName ? "Save" : "Edit")
                            .font(.nCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(phaseColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)

                Divider().padding(.leading, 14)

                HStack {
                    Text("Email")
                        .font(.nSubheadline)
                    Spacer()
                    Text(authService.userEmail ?? "—")
                        .font(.nSubheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var phaseColor: Color {
        PhaseColors.forSlug(cycleService.currentPhase?.phaseSlug ?? "follicular").color
    }

    // MARK: - Daily Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAILY SCHEDULE")
                .namahLabel()

            VStack(spacing: 0) {
                DatePicker("Wake Time", selection: Binding(
                    get: { schedule.wakeTime },
                    set: { newValue in
                        schedule.wakeTime = newValue
                        timeBlockService.updateSchedule(wakeTime: newValue, sleepTime: schedule.sleepTime)
                        rescheduleHabitNotifications()
                    }
                ), displayedComponents: .hourAndMinute)
                .font(.nSubheadline)
                .padding(14)

                Divider().padding(.leading, 14)

                DatePicker("Sleep Time", selection: Binding(
                    get: { schedule.sleepTime },
                    set: { newValue in
                        schedule.sleepTime = newValue
                        timeBlockService.updateSchedule(wakeTime: schedule.wakeTime, sleepTime: newValue)
                        rescheduleHabitNotifications()
                    }
                ), displayedComponents: .hourAndMinute)
                .font(.nSubheadline)
                .padding(14)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTIFICATIONS")
                .namahLabel()

            VStack(spacing: 0) {
                // Habit Notifications toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Habit Reminders")
                            .font(.nSubheadline)
                            .fontWeight(.medium)
                        Text("Meal, supplement, and workout notifications")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { schedule.habitNotificationsEnabled },
                        set: { newValue in
                            schedule.habitNotificationsEnabled = newValue
                            Task { @MainActor in
                                if newValue {
                                    let granted = await NotificationService.requestPermissionIfNeeded()
                                    if granted {
                                        rescheduleHabitNotifications()
                                    } else {
                                        schedule.habitNotificationsEnabled = false
                                    }
                                } else {
                                    await NotificationService.cancelHabitNotifications()
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .padding(14)

                if schedule.habitNotificationsEnabled {
                    Divider().padding(.leading, 14)

                    // Quiet Hours
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiet Hours")
                                .font(.nSubheadline)
                                .fontWeight(.medium)
                            Text("No notifications during sleep")
                                .font(.nCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { schedule.quietHoursEnabled },
                            set: { newValue in
                                schedule.quietHoursEnabled = newValue
                                rescheduleHabitNotifications()
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(14)
                }

                Divider().padding(.leading, 14)

                // Daily Digest (existing)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Digest")
                            .font(.nSubheadline)
                            .fontWeight(.medium)
                        Text("Reminder to log symptoms & meals")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { profile.dailyReminderEnabled },
                        set: { newValue in
                            profile.dailyReminderEnabled = newValue
                            Task { @MainActor in
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

                // Period Prediction (existing)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Period Prediction")
                            .font(.nSubheadline)
                            .fontWeight(.medium)
                        Text("Notifies 3 days before predicted start")
                            .font(.nCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { profile.periodReminderEnabled },
                        set: { newValue in
                            profile.periodReminderEnabled = newValue
                            Task { @MainActor in
                                if newValue {
                                    let granted = await NotificationService.requestPermissionIfNeeded()
                                    if granted, let lastLog = sortedLogs.first {
                                        await NotificationService.schedulePeriodPrediction(
                                            lastPeriodStart: lastLog.periodStartDate,
                                            effectiveCycleLength: cycleService.cycleStats.effectiveCycleLength
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

    // MARK: - Notification Scheduling

    private func rescheduleHabitNotifications() {
        guard schedule.habitNotificationsEnabled else { return }

        let wakeMin = TimeParser.minutesSinceMidnight(from: schedule.wakeTime)
        let sleepMin = TimeParser.minutesSinceMidnight(from: schedule.sleepTime)
        let quietStart: Int? = schedule.quietHoursEnabled ? sleepMin : nil
        let quietEnd: Int? = schedule.quietHoursEnabled ? wakeMin : nil

        // Get current phase meals
        let currentPhaseName = cycleService.currentPhase?.phaseName

        // Build meal notification infos
        let todayMeals = buildTodayMeals()
        let mealInfos = todayMeals.map { meal in
            NotificationService.MealNotificationInfo(
                id: meal.id,
                title: meal.title,
                mealType: meal.mealType,
                time: meal.time,
                phaseName: currentPhaseName
            )
        }

        // Build supplement notification infos
        let activeSupps = userSupplements.filter(\.isActive)
        let suppInfos = activeSupps.map { userSup in
            let def = userSup.supplementId.flatMap { supId in definitions.first { $0.id == supId } }
            return NotificationService.SupplementNotificationInfo(
                userSupplementId: userSup.id,
                name: def?.name ?? "Supplement",
                timeOfDay: userSup.timeOfDay,
                dosage: "\(Int(userSup.dosage))"
            )
        }

        // Get workout info
        let jsDay = Calendar.current.component(.weekday, from: Date())
        let dayOfWeek = jsDay == 1 ? 6 : jsDay - 2
        let todayWorkout = workouts.first { $0.dayOfWeek == dayOfWeek }

        Task {
            await NotificationService.scheduleMealReminders(
                mealInfos,
                quietStart: quietStart,
                quietEnd: quietEnd
            )

            await NotificationService.scheduleSupplementReminders(
                suppInfos,
                wakeMinutes: wakeMin,
                sleepMinutes: sleepMin,
                quietStart: quietStart,
                quietEnd: quietEnd
            )

            if let workout = todayWorkout, !workout.isRestDay {
                let sessions = workoutSessions.filter { $0.workoutId == workout.id }
                if let firstSession = sessions.sorted(by: {
                    (TimeParser.minutesSinceMidnight(from: $0.timeSlot) ?? 0) <
                    (TimeParser.minutesSinceMidnight(from: $1.timeSlot) ?? 0)
                }).first {
                    await NotificationService.scheduleWorkoutReminder(
                        dayLabel: workout.dayLabel,
                        dayFocus: workout.dayFocus,
                        timeSlot: firstSession.timeSlot,
                        quietStart: quietStart,
                        quietEnd: quietEnd
                    )
                }
            }
        }
    }

    private func buildTodayMeals() -> [Meal] {
        guard let phase = cycleService.currentPhase,
              let phaseRecord = phases.first(where: { $0.slug == phase.phaseSlug })
        else { return [] }

        let phaseMeals = allMeals.filter { $0.phaseId == phaseRecord.id && $0.proteinG != nil }
        let dayNumbers = Array(Set(phaseMeals.map(\.dayNumber))).sorted()
        guard !dayNumbers.isEmpty else { return [] }
        let todayDay = dayNumbers[(phase.dayInPhase - 1) % dayNumbers.count]
        return phaseMeals.filter { $0.dayNumber == todayDay }
    }

    // MARK: - Cycle Log

    private var cycleLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CYCLE LOG")
                .namahLabel()

            if cycleLogs.isEmpty {
                Text("Log your first period to start tracking.")
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                let sorted = sortedLogs
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
                    .font(.nSubheadline)
                    .fontWeight(.medium)
                if let len = cycleLength {
                    Text("\(len) day cycle")
                        .font(.nCaption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let d = delta {
                Text(d == 0 ? "avg" : (d > 0 ? "+\(d)" : "\(d)"))
                    .font(.nCaption)
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

    // MARK: - Sign Out

    private var signOutSection: some View {
        Button(role: .destructive) {
            authService.signOut()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(.nSubheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
