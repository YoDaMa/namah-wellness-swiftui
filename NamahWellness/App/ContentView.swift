import SwiftUI
import SwiftData

struct ContentView: View {
    let authService: AuthService
    let syncService: SyncService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \CycleLog.createdAt, order: .reverse) private var cycleLogs: [CycleLog]
    @Query private var phases: [Phase]

    @State private var cycleService = CycleService()
    @State private var selectedTab = 0
    @State private var hasInitialSync = false

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
                .environment(syncService)
                .environment(authService)
                .onAppear {
                    syncService.configure(modelContext: modelContext)
                    recalculate()
                    if !hasInitialSync {
                        hasInitialSync = true
                        Task { await syncService.sync(); recalculate() }
                    }
                }
                .onChange(of: cycleLogs.count) { recalculate() }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        Task { await syncService.sync(); recalculate() }
                    }
                }
            } else {
                LoginView(authService: authService)
            }
        }
    }

    private func recalculate() {
        cycleService.recalculate(logs: cycleLogs, phases: phases)
    }
}
