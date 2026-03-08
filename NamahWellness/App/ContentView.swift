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

            NutritionView(cycleService: cycleService)
                .tabItem {
                    Image(systemName: "fork.knife")
                    Text("Nutrition")
                }
                .tag(1)

            HormonesView(cycleService: cycleService)
                .tabItem {
                    Image(systemName: "flask")
                    Text("Hormones")
                }
                .tag(2)

            ExerciseView()
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Workouts")
                }
                .tag(3)

            ProfileView(cycleService: cycleService)
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .tint(.ink)
        .onAppear { seedIfNeeded(); recalculate() }
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
