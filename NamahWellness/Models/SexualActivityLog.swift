import Foundation
import SwiftData

enum ProtectionType: String, Codable, CaseIterable {
    case protected = "protected"
    case unprotected = "unprotected"
    case withdrawal = "withdrawal"
    case insemination = "insemination"

    var displayName: String {
        switch self {
        case .protected: return "Protected"
        case .unprotected: return "Unprotected"
        case .withdrawal: return "Withdrawal"
        case .insemination: return "Insemination"
        }
    }

    var icon: String {
        switch self {
        case .protected: return "shield.fill"
        case .unprotected: return "shield.slash"
        case .withdrawal: return "shield.lefthalf.filled"
        case .insemination: return "heart.fill"
        }
    }
}

@Model
final class SexualActivityLog {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var date: String                     // "YYYY-MM-DD"
    var time: Date?
    var protectionTypeRaw: String        // ProtectionType raw value
    var notes: String?
    var createdAt: Date

    var protectionType: ProtectionType {
        get { ProtectionType(rawValue: protectionTypeRaw) ?? .protected }
        set { protectionTypeRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        date: String,
        time: Date? = nil,
        protectionType: ProtectionType = .protected,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.time = time
        self.protectionTypeRaw = protectionType.rawValue
        self.notes = notes
        self.createdAt = createdAt
    }
}
