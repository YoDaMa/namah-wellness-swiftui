import Foundation
import os

// MARK: - TimeBlock

/// Represents a segment of the user's day.
///
/// Architecture:
///   DailySchedule (wake/sleep) ──▶ TimeBlockService.computeBlocks()
///     ──▶ [TimeBlock] with computed start/end minutes
///     ──▶ currentBlock updated every 60s by Timer
///
enum TimeBlockKind: String, CaseIterable, Identifiable, Codable {
    case morning
    case midday
    case afternoon
    case evening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning:   return "Morning"
        case .midday:    return "Midday"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        }
    }

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .midday:    return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .evening:   return "moon.fill"
        }
    }
}

struct TimeBlock: Identifiable {
    let kind: TimeBlockKind
    let startMinutes: Int  // minutes since midnight
    let endMinutes: Int    // minutes since midnight (exclusive)

    var id: String { kind.rawValue }
    var displayName: String { kind.displayName }
    var icon: String { kind.icon }

    /// Formatted start time string (e.g., "6:00am")
    var startTimeLabel: String { Self.formatMinutes(startMinutes) }
    var endTimeLabel: String { Self.formatMinutes(endMinutes) }

    func contains(minutes: Int) -> Bool {
        if startMinutes < endMinutes {
            return minutes >= startMinutes && minutes < endMinutes
        } else {
            // Wraps midnight (e.g., evening 10pm-6am)
            return minutes >= startMinutes || minutes < endMinutes
        }
    }

    private static func formatMinutes(_ m: Int) -> String {
        let h = (m / 60) % 24
        let min = m % 60
        let period = h >= 12 ? "pm" : "am"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return min == 0 ? "\(displayHour)\(period)" : "\(displayHour):\(String(format: "%02d", min))\(period)"
    }
}

// MARK: - TimeBlockService

/// Computes and auto-updates the current time block based on DailySchedule.
///
/// Usage:
///   @State var timeBlockService = TimeBlockService()
///   // Pass via .environment(timeBlockService)
///   // Call updateSchedule(wake:sleep:) when DailySchedule changes
///
@Observable
final class TimeBlockService {

    private(set) var blocks: [TimeBlock] = []
    private(set) var currentBlock: TimeBlock?
    private(set) var currentDate: String = ""

    private var timer: Timer?
    private var wakeMinutes: Int = 360   // 6:00am default
    private var sleepMinutes: Int = 1320 // 10:00pm default

    private static let logger = Logger(subsystem: "com.namah.wellness", category: "TimeBlockService")

    init() {
        recompute()
        startTimer()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    /// Update schedule from DailySchedule model.
    func updateSchedule(wakeTime: Date, sleepTime: Date) {
        let newWake = TimeParser.minutesSinceMidnight(from: wakeTime)
        let newSleep = TimeParser.minutesSinceMidnight(from: sleepTime)

        // Guard against wake == sleep
        guard newWake != newSleep else {
            Self.logger.warning("Wake time equals sleep time — keeping current schedule")
            return
        }

        wakeMinutes = newWake
        sleepMinutes = newSleep
        recompute()
    }

    /// Force a recomputation (e.g., on scenePhase == .active).
    func refresh() {
        recompute()
    }

    // MARK: - Block assignment for items

    /// Returns the TimeBlock a meal belongs to, based on its time string and mealType.
    func blockForMeal(time: String, mealType: String) -> TimeBlockKind {
        let minutes = TimeParser.minutesSinceMidnight(from: time)
            ?? TimeParser.defaultMinutes(forMealType: mealType)
        return blockKind(forMinutes: minutes)
    }

    /// Returns the TimeBlock for a supplement based on its timeOfDay category.
    func blockForSupplement(timeOfDay: String) -> TimeBlockKind {
        let minutes = TimeParser.defaultMinutes(forSupplementTime: timeOfDay, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)
        return blockKind(forMinutes: minutes)
    }

    /// Returns the TimeBlock for a workout session based on its timeSlot string.
    func blockForWorkoutSession(timeSlot: String) -> TimeBlockKind {
        let minutes = TimeParser.minutesSinceMidnight(from: timeSlot) ?? (9 * 60) // default 9am
        return blockKind(forMinutes: minutes)
    }

    /// Returns the next block after the current one, or nil if this is the last block.
    var nextBlock: TimeBlock? {
        guard let current = currentBlock,
              let idx = blocks.firstIndex(where: { $0.kind == current.kind }),
              idx + 1 < blocks.count else { return nil }
        return blocks[idx + 1]
    }

    // MARK: - Private

    private func recompute() {
        blocks = Self.computeBlocks(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)

        let now = TimeParser.minutesSinceMidnight(from: Date())
        let newBlock = blocks.first { $0.contains(minutes: now) } ?? blocks.last
        if currentBlock?.kind != newBlock?.kind {
            if let prev = currentBlock, let next = newBlock {
                Self.logger.info("Time block transition: \(prev.displayName) → \(next.displayName)")
            }
            currentBlock = newBlock
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        currentDate = formatter.string(from: Date())
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.recompute()
        }
    }

    private func blockKind(forMinutes minutes: Int) -> TimeBlockKind {
        for block in blocks {
            if block.contains(minutes: minutes) {
                return block.kind
            }
        }
        return .evening // fallback
    }

    /// Computes 4 time blocks from wake/sleep times.
    ///
    /// Distribution:
    ///   Morning:   wake    → wake + 42% of awake time
    ///   Midday:    ...     → wake + 58% of awake time
    ///   Afternoon: ...     → wake + 75% of awake time
    ///   Evening:   ...     → sleep
    ///
    static func computeBlocks(wakeMinutes: Int, sleepMinutes: Int) -> [TimeBlock] {
        let awake: Int
        if sleepMinutes > wakeMinutes {
            awake = sleepMinutes - wakeMinutes
        } else {
            awake = (1440 - wakeMinutes) + sleepMinutes // wraps midnight
        }

        // Proportional split: ~5h morning, ~3h midday, ~2h afternoon, ~4h evening (for 16h awake)
        let morningEnd = (wakeMinutes + Int(Double(awake) * 0.31)) % 1440  // ~5h
        let middayEnd  = (wakeMinutes + Int(Double(awake) * 0.47)) % 1440  // +~2.5h
        let afterEnd   = (wakeMinutes + Int(Double(awake) * 0.66)) % 1440  // +~3h

        return [
            TimeBlock(kind: .morning,   startMinutes: wakeMinutes, endMinutes: morningEnd),
            TimeBlock(kind: .midday,    startMinutes: morningEnd,  endMinutes: middayEnd),
            TimeBlock(kind: .afternoon, startMinutes: middayEnd,   endMinutes: afterEnd),
            TimeBlock(kind: .evening,   startMinutes: afterEnd,    endMinutes: sleepMinutes),
        ]
    }
}
