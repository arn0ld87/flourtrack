import Foundation
import SwiftData

enum FlourTrackModelContainer {
    static func make() -> ModelContainer {
        let schema = Schema([
            GameAttempt.self,
            PlayerProfile.self,
            LocalAchievement.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer konnte nicht erzeugt werden: \(error)")
        }
    }
}