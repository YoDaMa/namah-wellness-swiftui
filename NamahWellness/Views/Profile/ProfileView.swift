import SwiftUI
import SwiftData

struct ProfileView: View {
    let cycleService: CycleService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(SyncService.self) private var syncService
    @Environment(CycleLogManager.self) private var cycleLogManager: CycleLogManager?
    @Query private var profiles: [UserProfile]
    @Query private var cycleLogs: [CycleLog]

    @State private var showLogSheet = false
    @State private var isEditingName = false
    @State private var editedName = ""

    private var profile: UserProfile {
        if let p = profiles.first { return p }
        let p = UserProfile()
        modelContext.insert(p)
        return p
    }

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                accountSection

                notificationsSection

                Divider().padding(.vertical, 4)

                cycleLogSection

                Divider().padding(.vertical, 4)

                signOutSection

                // App logo
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

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTIFICATIONS")
                .namahLabel()

            VStack(spacing: 0) {
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
                            Task {
                                if newValue {
                                    let granted = await NotificationService.requestPermissionIfNeeded()
                                    if granted, let lastLog = sortedLogs.first {
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
