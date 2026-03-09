import SwiftUI
import SwiftData

@main
struct NamahWellnessApp: App {
    let modelContainer: ModelContainer
    @State private var authService = AuthService()
    @State private var syncService = SyncService()

    init() {
        do {
            let schema = Schema([
                Phase.self,
                Meal.self,
                GroceryItem.self,
                Workout.self,
                WorkoutSession.self,
                CoreExercise.self,
                PhaseReminder.self,
                PhaseNutrient.self,
                CycleLog.self,
                MealCompletion.self,
                WorkoutCompletion.self,
                GroceryCheck.self,
                SymptomLog.self,
                DailyNote.self,
                SupplementDefinition.self,
                SupplementNutrient.self,
                UserSupplement.self,
                SupplementLog.self,
                UserProfile.self,
                SyncChange.self,
            ])
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authService: authService, syncService: syncService)
        }
        .modelContainer(modelContainer)
    }
}
