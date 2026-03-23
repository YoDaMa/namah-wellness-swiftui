import SwiftUI
import SwiftData

struct ContentView: View {
    let authService: AuthService
    let syncService: SyncService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var cycleLogs: [CycleLog]
    @Query private var phases: [Phase]
    @Query private var schedules: [DailySchedule]
    @Query private var profiles: [UserProfile]

    @State private var cycleService = CycleService()
    @State private var timeBlockService = TimeBlockService()
    @State private var cycleLogManager: CycleLogManager?
    @State private var selectedTab = 0
    @State private var hasInitialSync = false

    private var currentPhaseColor: Color {
        guard let slug = cycleService.currentPhase?.phaseSlug else { return .primary }
        return PhaseColors.forSlug(slug).color
    }

    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabView(selection: $selectedTab) {
                    TodayView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "sun.max")
                            Text("Today")
                        }
                        .tag(0)

                    MyCycleView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "circle.dotted.circle")
                            Text("My Cycle")
                        }
                        .tag(1)

                    PlanView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "list.bullet.rectangle")
                            Text("Plan")
                        }
                        .tag(2)

                    LearnView(cycleService: cycleService)
                        .tabItem {
                            Image(systemName: "book")
                            Text("Learn")
                        }
                        .tag(3)
                }
                .tint(currentPhaseColor)
                .environment(syncService)
                .environment(authService)
                .environment(cycleLogManager)
                .environment(timeBlockService)
                .onAppear {
                    syncService.configure(modelContext: modelContext, authService: authService)
                    if cycleLogManager == nil {
                        let manager = CycleLogManager(
                            modelContext: modelContext,
                            syncService: syncService,
                            authService: authService
                        )
                        manager.cleanupDuplicates()
                        cycleLogManager = manager
                    }
                    recalculate()
                    updateTimeBlocks()
                    ensureDefaultSchedule()
                    if !hasInitialSync {
                        hasInitialSync = true
                        Task { await syncService.sync(); recalculate() }
                    }
                }
                .onChange(of: cycleLogSnapshot) { recalculate() }
                .onChange(of: profileSnapshot) { recalculate() }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        cycleLogManager?.checkAndAutoLog(
                            stats: cycleService.cycleStats
                        )
                        timeBlockService.refresh()
                        updateTimeBlocks()
                        Task { await syncService.sync(); recalculate() }
                    }
                }
            } else {
                LoginView(authService: authService)
            }
        }
    }

    private var cycleLogSnapshot: [String] {
        cycleLogs.map { "\($0.id)|\($0.periodStartDate)|\($0.periodEndDate ?? "")|\($0.phaseOverride ?? "")" }
    }

    private var profileSnapshot: String {
        guard let p = profiles.first else { return "" }
        return "\(p.cycleLengthOverride ?? 0)|\(p.periodLengthOverride ?? 0)|\(p.overdueAckDate ?? "")"
    }

    private func recalculate() {
        withAnimation(.easeInOut(duration: 0.3)) {
            cycleService.recalculate(logs: cycleLogs, phases: phases, profile: profiles.first)
        }
    }

    private func updateTimeBlocks() {
        if let schedule = schedules.first {
            timeBlockService.updateSchedule(wakeTime: schedule.wakeTime, sleepTime: schedule.sleepTime)
        }
    }

    private func ensureDefaultSchedule() {
        if schedules.isEmpty {
            let schedule = DailySchedule()
            modelContext.insert(schedule)
        }
    }
}
