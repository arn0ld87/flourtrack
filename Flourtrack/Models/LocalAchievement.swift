import Foundation
import SwiftData

@Model
final class LocalAchievement {
    @Attribute(.unique) var code: String
    var unlockedAt: Date?

    init(code: String, unlockedAt: Date? = nil) {
        self.code = code
        self.unlockedAt = unlockedAt
    }
}