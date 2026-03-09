import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CycleLog.createdAt, order: .reverse) private var cycleLogs: [CycleLog]
    @Query private var phases: [Phase]

    @State private var cycleService = CycleService()
    @State private var selectedTab = 0

    var body: some View {
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
        .onAppear { seedIfNeeded(); SeedService.migrateIconsToSFSymbols(in: modelContext); recalculate() }
        .onChange(of: cycleLogs.count) { recalculate() }
    }

    private func recalculate() {
        cycleService.recalculate(logs: cycleLogs, phases: phases)
    }

    private func seedIfNeeded() {
        guard phases.isEmpty else { return }
        SeedService.seed(into: modelContext)
    }
}
