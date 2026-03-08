import SwiftUI
import SwiftData

struct ProfileView: View {
    let cycleService: CycleService

    @Query(sort: \CycleLog.createdAt, order: .reverse) private var cycleLogs: [CycleLog]

    @State private var showLogSheet = false
    @State private var newPeriodDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Profile")
                        .font(.heading(32))
                        .foregroundStyle(.ink)

                    // Cycle stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CYCLE STATS")
                            .font(.bodyMedium(9))
                            .textCase(.uppercase)
                            .tracking(2.5)
                            .foregroundStyle(.muted)

                        HStack(spacing: 16) {
                            statItem(value: "\(cycleService.cycleStats.avgCycleLength)", label: "AVG LENGTH")
                            divider
                            statItem(value: "\(cycleService.cycleStats.cycleCount)", label: "CYCLES LOGGED")
                            if let phase = cycleService.currentPhase {
                                divider
                                statItem(value: "Day \(phase.cycleDay)", label: phase.phaseName.uppercased())
                            }
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(Color.border, lineWidth: 1))

                    // Current phase
                    if let phase = cycleService.currentPhase {
                        VStack(alignment: .leading, spacing: 8) {
                            PhaseHeaderView(phase: phase)

                            Text("Started \(phase.periodStartDate)")
                                .font(.body(11))
                                .foregroundStyle(.muted)
                        }
                        .padding(16)
                        .background(Color.white)
                        .overlay(Rectangle().stroke(Color.border, lineWidth: 1))
                    }

                    // Log period button
                    Button {
                        showLogSheet = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("LOG PERIOD START")
                                .font(.bodyMedium(10))
                                .tracking(2)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .foregroundStyle(.paper)
                        .background(Color.ink)
                    }
                    .buttonStyle(.plain)

                    // Cycle history
                    if !cycleLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PERIOD HISTORY")
                                .font(.bodyMedium(9))
                                .textCase(.uppercase)
                                .tracking(2.5)
                                .foregroundStyle(.muted)

                            ForEach(cycleLogs, id: \.id) { log in
                                HStack {
                                    Text(log.periodStartDate)
                                        .font(.body(13))
                                        .foregroundStyle(.ink)
                                    Spacer()
                                    if let override = log.phaseOverride {
                                        Text(override)
                                            .font(.bodyMedium(9))
                                            .textCase(.uppercase)
                                            .tracking(1)
                                            .foregroundStyle(.spice)
                                    }
                                }
                                .padding(.vertical, 8)
                                if log.id != cycleLogs.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .overlay(Rectangle().stroke(Color.border, lineWidth: 1))
                    }
                }
                .padding()
            }
            .background(Color.paper)
            .sheet(isPresented: $showLogSheet) {
                logPeriodSheet
            }
        }
    }

    private var logPeriodSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("When did your period start?")
                    .font(.heading(20))
                    .foregroundStyle(.ink)

                DatePicker("", selection: $newPeriodDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)

                Button {
                    logPeriod()
                } label: {
                    HStack {
                        Spacer()
                        Text("LOG PERIOD")
                            .font(.bodyMedium(10))
                            .tracking(2)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .foregroundStyle(.paper)
                    .background(Color.ink)
                }
                .buttonStyle(.plain)

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

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.bodyMedium(16))
                .foregroundStyle(.ink)
            Text(label)
                .font(.bodyMedium(7))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(.muted)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 1, height: 28)
    }

    @Environment(\.modelContext) private var modelContext

    private func logPeriod() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: newPeriodDate)
        let log = CycleLog(periodStartDate: dateString)
        modelContext.insert(log)
        showLogSheet = false
    }
}
