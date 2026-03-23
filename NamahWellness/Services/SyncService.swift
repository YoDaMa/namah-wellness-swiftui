import Foundation
import SwiftData
import Network

// MARK: - SyncState

enum SyncState: Equatable {
    case idle
    case syncing
    case error(String)
}

// MARK: - SyncService

@Observable
final class SyncService {

    private(set) var syncState: SyncState = .idle
    private(set) var lastSyncDate: Date?

    private let apiClient = APIClient.shared
    private var modelContext: ModelContext?
    private weak var authService: AuthService?
    private let monitor = NWPathMonitor()
    private var isOnline = false

    // MARK: - Configuration

    func configure(modelContext: ModelContext, authService: AuthService) {
        self.modelContext = modelContext
        self.authService = authService
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied
                if wasOffline && path.status == .satisfied {
                    await self?.sync()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.namah.network-monitor"))
    }

    // MARK: - Sync

    @MainActor
    func sync() async {
        guard let modelContext else { return }
        guard syncState != .syncing else { return }

        syncState = .syncing

        do {
            try await pushPendingChanges(context: modelContext)
            try await pullContent(context: modelContext)
            try await pullUserData(context: modelContext)
            try modelContext.save()
            lastSyncDate = Date()
            syncState = .idle
        } catch let error as APIError {
            if case .unauthorized = error {
                syncState = .error("Session expired. Please sign in again.")
                authService?.handleUnauthorized()
            } else {
                syncState = .error(error.localizedDescription)
            }
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }

    // MARK: - Queue Change

    func queueChange(table: String, action: String, data: [String: Any], modelContext: ModelContext) {
        guard JSONSerialization.isValidJSONObject(data),
              let jsonData = try? JSONSerialization.data(withJSONObject: data) else { return }

        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let change = SyncChange(tableName: table, action: action, payload: jsonString)
        modelContext.insert(change)
    }

    // MARK: - Push

    @MainActor
    private func pushPendingChanges(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<SyncChange>(sortBy: [SortDescriptor(\.createdAt)])
        let changes = try context.fetch(descriptor)

        guard !changes.isEmpty else { return }

        var changeDicts: [[String: Any]] = []
        for change in changes {
            var dict: [String: Any] = [
                "table": change.tableName,
                "action": change.action,
            ]
            if let data = change.payload.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                dict["data"] = parsed
            }
            changeDicts.append(dict)
        }

        let body: [String: Any] = ["changes": changeDicts]
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        try await apiClient.postRaw(path: "/api/v1/sync", body: jsonData)

        for change in changes {
            context.delete(change)
        }
    }

    // MARK: - Pull Content

    @MainActor
    private func pullContent(context: ModelContext) async throws {
        let response: ContentResponse = try await apiClient.get(path: "/api/v1/content")

        // Delete existing content models
        try context.delete(model: RecipeIngredient.self)
        try context.delete(model: Phase.self)
        try context.delete(model: Meal.self)
        try context.delete(model: GroceryItem.self)
        try context.delete(model: Workout.self)
        try context.delete(model: WorkoutSession.self)
        try context.delete(model: CoreExercise.self)
        try context.delete(model: PhaseReminder.self)
        try context.delete(model: PhaseNutrient.self)
        try context.delete(model: SupplementDefinition.self)
        try context.delete(model: SupplementNutrient.self)
        try context.delete(model: PlanTemplate.self)

        // Insert new content
        for dto in response.phases { context.insert(dto.toModel()) }
        for dto in response.meals { context.insert(dto.toModel()) }
        for dto in response.recipeIngredients { context.insert(dto.toModel()) }
        for dto in response.groceryItems { context.insert(dto.toModel()) }
        for dto in response.workouts { context.insert(dto.toModel()) }
        for dto in response.workoutSessions { context.insert(dto.toModel()) }
        for dto in response.coreExercises { context.insert(dto.toModel()) }
        for dto in response.phaseReminders { context.insert(dto.toModel()) }
        for dto in response.phaseNutrients { context.insert(dto.toModel()) }
        for dto in response.supplementDefinitions { context.insert(dto.toModel()) }
        for dto in response.supplementNutrients { context.insert(dto.toModel()) }
        for dto in response.planTemplates { context.insert(dto.toModel()) }
    }

    // MARK: - Pull User Data

    @MainActor
    private func pullUserData(context: ModelContext) async throws {
        let response: UserDataResponse = try await apiClient.get(path: "/api/v1/sync")

        // Delete existing user data models
        try context.delete(model: CycleLog.self)
        try context.delete(model: MealCompletion.self)
        try context.delete(model: WorkoutCompletion.self)
        try context.delete(model: SymptomLog.self)
        try context.delete(model: DailyNote.self)
        try context.delete(model: GroceryCheck.self)
        try context.delete(model: UserSupplement.self)
        try context.delete(model: SupplementLog.self)
        try context.delete(model: UserPlanSelection.self)
        try context.delete(model: UserPlanItem.self)
        try context.delete(model: UserItemHidden.self)
        try context.delete(model: PlanItemLog.self)

        // Insert new user data
        for dto in response.cycleLogs { context.insert(dto.toModel()) }
        for dto in response.mealCompletions { context.insert(dto.toModel()) }
        for dto in response.workoutCompletions { context.insert(dto.toModel()) }
        for dto in response.symptomLogs { context.insert(dto.toModel()) }
        for dto in response.dailyNotes { context.insert(dto.toModel()) }
        for dto in response.groceryChecks { context.insert(dto.toModel()) }
        for dto in response.userSupplements { context.insert(dto.toModel()) }
        for dto in response.supplementLogs { context.insert(dto.toModel()) }
        for dto in response.userPlanSelections { context.insert(dto.toModel()) }
        for dto in response.userPlanItems { context.insert(dto.toModel()) }
        for dto in response.userItemsHidden { context.insert(dto.toModel()) }
        for dto in response.planItemLogs { context.insert(dto.toModel()) }
    }
}
