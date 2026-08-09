import Foundation
import SwiftData

protocol GameRepository {
    func save(_ attempt: GameAttempt) throws
    func recentAttempts(limit: Int) throws -> [GameAttempt]
    func bestScore() throws -> Int
    func bestCombo() throws -> Int
    func totalGames() throws -> Int
    /// Anzahl aufeinanderfolgender Perfects, beginnend beim neuesten Versuch.
    func lastPerfectsInARow() throws -> Int
}

struct SwiftDataGameRepository: GameRepository {
    let context: ModelContext

    func save(_ attempt: GameAttempt) throws {
        context.insert(attempt)
        try context.save()
    }

    func recentAttempts(limit: Int) throws -> [GameAttempt] {
        var descriptor = FetchDescriptor<GameAttempt>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func bestScore() throws -> Int {
        try context.fetch(FetchDescriptor<GameAttempt>()).map(\.score).max() ?? 0
    }

    func bestCombo() throws -> Int {
        try context.fetch(FetchDescriptor<GameAttempt>()).map(\.combo).max() ?? 0
    }

    func totalGames() throws -> Int {
        try context.fetchCount(FetchDescriptor<GameAttempt>())
    }

    func lastPerfectsInARow() throws -> Int {
        let attempts = try recentAttempts(limit: 64)
        var streak = 0
        for a in attempts {
            if a.rating == .perfect { streak += 1 } else { break }
        }
        return streak
    }
}