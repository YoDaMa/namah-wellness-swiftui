import SwiftUI
import SwiftData
import UserNotifications

@main
struct NamahWellnessApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                DailySchedule.self,
                BBTLog.self,
                SexualActivityLog.self,
            ])
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        NotificationService.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(authService: authService, syncService: syncService)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - AppDelegate (Notification Action Handling)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle notification action (e.g., "Done" button)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier

        guard actionId == NotificationService.markDoneActionId else { return }
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "meal":
            if let mealId = userInfo["itemId"] as? String {
                await handleMealCompletion(mealId: mealId)
            }
        case "supplement":
            if let ids = userInfo["itemIds"] as? [String] {
                for id in ids {
                    await handleSupplementCompletion(userSupplementId: id)
                }
            }
        default:
            break
        }
    }

    @MainActor
    private func handleMealCompletion(mealId: String) async {
        guard let container = try? ModelContainer(for:
            MealCompletion.self, SupplementLog.self
        ) else { return }

        let context = container.mainContext
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = .current
            return f.string(from: Date())
        }()

        // Idempotent: check if already completed
        let descriptor = FetchDescriptor<MealCompletion>(
            predicate: #Predicate { $0.mealId == mealId && $0.date == dateStr }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }

        let completion = MealCompletion(mealId: mealId, date: dateStr)
        context.insert(completion)
        try? context.save()
    }

    @MainActor
    private func handleSupplementCompletion(userSupplementId: String) async {
        guard let container = try? ModelContainer(for:
            MealCompletion.self, SupplementLog.self
        ) else { return }

        let context = container.mainContext
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = .current
            return f.string(from: Date())
        }()

        // Idempotent: check if already logged
        let descriptor = FetchDescriptor<SupplementLog>(
            predicate: #Predicate { $0.userSupplementId == userSupplementId && $0.date == dateStr }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            if let log = existing.first, !log.taken {
                log.taken = true
                log.loggedAt = Date()
                try? context.save()
            }
            return
        }

        let log = SupplementLog(userSupplementId: userSupplementId, date: dateStr, taken: true)
        context.insert(log)
        try? context.save()
    }
}
