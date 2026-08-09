import Foundation
import SwiftData

protocol AchievementRepository {
    func all() throws -> [LocalAchievement]
    /// Legt die 6 Seed-Definitionen an, falls noch nicht vorhanden.
    func seedIfNeeded() throws
    /// Schaltet frei, falls noch gesperrt. Returns true bei Neu-Freischaltung.
    func unlock(code: String) throws -> Bool
    func isUnlocked(code: String) throws -> Bool
}

struct SwiftDataAchievementRepository: AchievementRepository {
    let context: ModelContext

    func seedIfNeeded() throws {
        let existing = try all()
        let existingCodes = Set(existing.map(\.code))
        for def in AchievementDefinition.all where !existingCodes.contains(def.code) {
            context.insert(LocalAchievement(code: def.code))
        }
        try context.save()
    }

    func all() throws -> [LocalAchievement] {
        try context.fetch(FetchDescriptor<LocalAchievement>(
            sortBy: [SortDescriptor(\.code)]
        ))
    }

    func unlock(code: String) throws -> Bool {
        let descriptor = FetchDescriptor<LocalAchievement>(
            predicate: #Predicate { $0.code == code }
        )
        guard let a = try context.fetch(descriptor).first else { return false }
        if a.unlockedAt != nil { return false }
        a.unlockedAt = .now
        try context.save()
        return true
    }

    func isUnlocked(code: String) throws -> Bool {
        let descriptor = FetchDescriptor<LocalAchievement>(
            predicate: #Predicate { $0.code == code }
        )
        return try context.fetch(descriptor).first?.unlockedAt != nil
    }
}