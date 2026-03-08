import Foundation
import SwiftData

@Model
final class CycleLog {
    @Attribute(.unique) var id: String
    var periodStartDate: String   // "YYYY-MM-DD"
    var periodEndDate: String?
    var phaseOverride: String?    // menstrual|follicular|ovulatory|luteal
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        periodStartDate: String,
        periodEndDate: String? = nil,
        phaseOverride: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.periodStartDate = periodStartDate
        self.periodEndDate = periodEndDate
        self.phaseOverride = phaseOverride
        self.createdAt = createdAt
    }
}
