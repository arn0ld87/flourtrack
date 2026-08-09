import Foundation
import SwiftData

/// Ein append-only Spielversuch. `attemptId` ist der client_game_id für spätere idempotente Backend-Syncs.
@Model
final class GameAttempt {
    @Attribute(.unique) var attemptId: UUID
    var score: Int
    var accuracyMs: Int
    var ratingRaw: String
    var combo: Int
    var streak: Int
    var tappedEarly: Bool
    var createdAt: Date

    init(
        attemptId: UUID = UUID(),
        score: Int,
        accuracyMs: Int,
        rating: Rating,
        combo: Int,
        streak: Int,
        tappedEarly: Bool,
        createdAt: Date = .now
    ) {
        self.attemptId = attemptId
        self.score = score
        self.accuracyMs = accuracyMs
        self.ratingRaw = rating.rawValue
        self.combo = combo
        self.streak = streak
        self.tappedEarly = tappedEarly
        self.createdAt = createdAt
    }

    var rating: Rating { Rating(rawValue: ratingRaw) ?? .tooSlow }
}