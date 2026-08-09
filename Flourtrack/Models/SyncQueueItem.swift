import Foundation
import SwiftData

/// Status eines Sync-Queue-Items.
enum SyncStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
}

/// Outbox-Item fur Offline-First-Sync zum Backend.
@Model
final class SyncQueueItem {
    @Attribute(.unique) var id: UUID
    var entityType: String       // z.B. "Game"
    var payload: Data            // JSON-codierter Payload
    var statusRaw: String
    var createdAt: Date
    var retryCount: Int
    var lastError: String?
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        entityType: String,
        payload: Data,
        status: SyncStatus = .pending,
        createdAt: Date = .now,
        retryCount: Int = 0,
        lastError: String? = nil,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.payload = payload
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.syncedAt = syncedAt
    }

    var status: SyncStatus {
        get { SyncStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
