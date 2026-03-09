import Foundation
import SwiftData

@Model
final class SyncChange {
    @Attribute(.unique) var id: String
    var tableName: String
    var action: String    // "upsert" or "delete"
    var payload: String   // JSON string
    var createdAt: Date

    init(id: String = UUID().uuidString, tableName: String, action: String, payload: String, createdAt: Date = Date()) {
        self.id = id
        self.tableName = tableName
        self.action = action
        self.payload = payload
        self.createdAt = createdAt
    }
}
