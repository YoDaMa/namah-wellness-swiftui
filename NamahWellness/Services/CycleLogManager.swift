import Foundation
import SwiftData

// MARK: - LogResult

enum LogResult {
    case success
    case correctionNeeded(existingDate: String, newDate: String)
    case duplicate
    case futureDate
}

// MARK: - CycleLogManager

@Observable
final class CycleLogManager {

    private(set) var pendingCorrection: (existingLog: CycleLog, newDate: String)?

    private let modelContext: ModelContext
    private let syncService: SyncService
    private let authService: AuthService

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    init(modelContext: ModelContext, syncService: SyncService, authService: AuthService) {
        self.modelContext = modelContext
        self.syncService = syncService
        self.authService = authService
    }

    // MARK: - Fetch logs (always fresh from modelContext)

    private func fetchLogs() -> [CycleLog] {
        (try? modelContext.fetch(FetchDescriptor<CycleLog>())) ?? []
    }

    // MARK: - Log Period (user-initiated)

    func logPeriod(date: Date) -> LogResult {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)

        // 1. Reject future dates
        if target > today {
            return .futureDate
        }

        let dateStr = dateFormatter.string(from: date)
        let logs = fetchLogs()

        // 2. Reject exact duplicates
        if logs.contains(where: { $0.periodStartDate == dateStr }) {
            return .duplicate
        }

        // 3. Check proximity (within 15 days of any existing entry)
        if let nearby = findClosestLog(date: target, in: logs, thresholdDays: 15) {
            pendingCorrection = (existingLog: nearby, newDate: dateStr)
            return .correctionNeeded(existingDate: nearby.periodStartDate, newDate: dateStr)
        }

        // 4. Insert
        insertLog(dateStr: dateStr)
        return .success
    }

    // MARK: - Confirm Correction

    func confirmCorrection() {
        guard let correction = pendingCorrection else { return }
        let oldLog = correction.existingLog
        let newDate = correction.newDate

        // Update existing log's date
        oldLog.periodStartDate = newDate
        syncService.queueChange(table: "cycleLogs", action: "upsert",
                                data: ["id": oldLog.id, "periodStartDate": newDate],
                                modelContext: modelContext)
        try? modelContext.save()
        pendingCorrection = nil
    }

    func cancelCorrection() {
        pendingCorrection = nil
    }

    // MARK: - Auto-log (system-initiated, silent)

    func checkAndAutoLog(stats: CycleStats) {
        let logs = fetchLogs()
        let sorted = logs.sorted { $0.periodStartDate > $1.periodStartDate }
        guard let latest = sorted.first else { return }

        guard let lastStart = dateFormatter.date(from: latest.periodStartDate) else { return }
        let cal = Calendar.current
        guard let predictedDate = cal.date(byAdding: .day, value: stats.avgCycleLength, to: lastStart) else { return }

        let today = cal.startOfDay(for: Date())
        let predicted = cal.startOfDay(for: predictedDate)

        // Only auto-log if predicted date <= today
        guard predicted <= today else { return }

        let predictedStr = dateFormatter.string(from: predicted)

        // Don't insert if one already exists for that date
        guard !logs.contains(where: { $0.periodStartDate == predictedStr }) else { return }

        // Don't insert if within 15 days of another entry
        guard findClosestLog(date: predicted, in: logs, thresholdDays: 15) == nil else { return }

        insertLog(dateStr: predictedStr)
    }

    // MARK: - Cleanup (one-time, removes existing bad data)

    func cleanupDuplicates() {
        let logs = fetchLogs()
        guard logs.count > 1 else { return }

        // Group by periodStartDate, keep oldest (by createdAt) for each date
        let grouped = Dictionary(grouping: logs, by: \.periodStartDate)
        var toDelete: [CycleLog] = []

        for (_, group) in grouped where group.count > 1 {
            let sorted = group.sorted { $0.createdAt < $1.createdAt }
            toDelete.append(contentsOf: sorted.dropFirst())
        }

        // Remove entries too close together (within 15 days), keep oldest
        let remaining = logs.filter { log in !toDelete.contains(where: { $0.id == log.id }) }
            .sorted { $0.periodStartDate < $1.periodStartDate }
        var i = 0
        while i < remaining.count - 1 {
            guard let d1 = dateFormatter.date(from: remaining[i].periodStartDate),
                  let d2 = dateFormatter.date(from: remaining[i + 1].periodStartDate) else {
                i += 1
                continue
            }
            let diff = Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 0
            if diff > 0 && diff <= 15 {
                // Keep the earlier one, mark later for deletion
                if !toDelete.contains(where: { $0.id == remaining[i + 1].id }) {
                    toDelete.append(remaining[i + 1])
                }
            }
            i += 1
        }

        for log in toDelete {
            syncService.queueChange(table: "cycleLogs", action: "delete",
                                    data: ["id": log.id], modelContext: modelContext)
            modelContext.delete(log)
        }

        if !toDelete.isEmpty {
            try? modelContext.save()
        }
    }

    // MARK: - Private

    private func insertLog(dateStr: String) {
        let log = CycleLog(userId: authService.userId ?? "", periodStartDate: dateStr)
        modelContext.insert(log)
        syncService.queueChange(table: "cycleLogs", action: "upsert",
                                data: ["id": log.id, "periodStartDate": dateStr],
                                modelContext: modelContext)
        try? modelContext.save()
    }

    private func findClosestLog(date: Date, in logs: [CycleLog], thresholdDays: Int) -> CycleLog? {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        var closest: (log: CycleLog, diff: Int)?

        for log in logs {
            guard let logDate = dateFormatter.date(from: log.periodStartDate) else { continue }
            let logDay = cal.startOfDay(for: logDate)
            let diff = abs(cal.dateComponents([.day], from: logDay, to: target).day ?? 0)
            if diff > 0 && diff <= thresholdDays {
                if closest == nil || diff < closest!.diff {
                    closest = (log, diff)
                }
            }
        }

        return closest?.log
    }
}
