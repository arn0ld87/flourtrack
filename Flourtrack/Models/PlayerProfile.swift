import Foundation
import SwiftData

@Model
final class PlayerProfile {
    var displayName: String
    var hapticsEnabled: Bool
    var audioEnabled: Bool

    init(
        displayName: String = "Baker",
        hapticsEnabled: Bool = true,
        audioEnabled: Bool = true
    ) {
        self.displayName = displayName
        self.hapticsEnabled = hapticsEnabled
        self.audioEnabled = audioEnabled
    }
}