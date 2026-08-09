import Foundation
import SwiftData
import Combine

/// Engine fur Offline-First-Sync: Holt pending Queue-Items und pusht sie ans Backend.
@MainActor
final class SyncEngine: ObservableObject {
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: String?
    @Published var pendingCount: Int = 0

    private let api: FlourTrackAPI
    private let batchSize: Int = 20

    init(api: FlourTrackAPI = FlourTrackAPI()) {
        self.api = api
    }

    /// Prufe Anzahl der pending Items (furs UI-Badge).
    func refreshPendingCount(context: ModelContext) {
        let descriptor = FetchDescriptor<SyncQueueItem>(predicate: #Predicate { $0.statusRaw == "pending" })
        pendingCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Verarbeite die Outbox-Queue: pending -> inProgress -> upload -> completed/failed.
    func flushQueue(context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        // Stelle sicher, dass Auth vorhanden ist (lazy guest auth)
        if !KeychainTokenStore.isAuthenticated {
            // Versuche Guest-Account zu erstellen
            let authService = AuthService(api: api)
            await authService.ensureGuestAccount()
            if !KeychainTokenStore.isAuthenticated {
                lastSyncError = "Keine Authentifizierung verfugbar"
                return
            }
        }

        // Hole pending Items, limitiert auf Batch-Size
        let descriptor = FetchDescriptor<SyncQueueItem>(
            predicate: #Predicate { $0.statusRaw == "pending" },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let items = try? context.fetch(descriptor), !items.isEmpty else {
            pendingCount = 0
            return
        }

        let batch = items.prefix(batchSize)
        var successCount = 0
        var failCount = 0

        for item in batch {
            item.status = .inProgress
            try? context.save()

            do {
                try await upload(item: item)
                item.status = .completed
                item.syncedAt = .now
                successCount += 1
            } catch {
                item.retryCount += 1
                item.lastError = error.localizedDescription

                // Max 3 Retries, dann failed
                if item.retryCount >= 3 {
                    item.status = .failed
                    failCount += 1
                } else {
                    item.status = .pending // Wieder in Queue
                }
            }
            try? context.save()
        }

        refreshPendingCount(context: context)

        if failCount > 0 {
            lastSyncError = "\(failCount) Items konnten nicht synchronisiert werden"
        }
    }

    /// Erstellt ein Queue-Item aus einem GameAttempt (wird nach dem lokalen Speichern aufgerufen).
    func enqueue(game: GameAttempt, context: ModelContext) {
        let request = CreateGameRequest(
            client_game_id: game.attemptId.uuidString,
            reaction_time_ms: game.accuracyMs,
            rating: game.ratingRaw.lowercased(),
            accuracy_score: max(0, 1000 - game.accuracyMs * 2),
            combo_multiplier: 1.0 + Double(game.combo) * 0.1,
            total_score: game.score,
            played_at: ISO8601DateFormatter().string(from: game.createdAt),
            virtual_line_count: nil,
            virtual_distance_meters: nil,
            metadata: nil
        )

        guard let payload = try? JSONEncoder().encode(request) else { return }

        let item = SyncQueueItem(
            entityType: "Game",
            payload: payload
        )
        context.insert(item)
        try? context.save()
        pendingCount += 1
    }

    // MARK: - Private

    private func upload(item: SyncQueueItem) async throws {
        let request = try JSONDecoder().decode(CreateGameRequest.self, from: item.payload)
        _ = try await api.createGame(request)
    }
}
