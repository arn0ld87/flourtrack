import Foundation

/// Trigger-Typ für eine lokale Achievement-Auswertung.
enum AchievementTrigger: String, Codable {
    case firstGame          // rookie_baker
    case perfectOnce        // millisecond_master
    case comboFive          // flour_power
    case threePerfectsRow   // precision_machine
    case beforeEightAM      // early_bird
    case deferred           // around_the_world (braucht MapKit)
}

/// Definition der 6 Achievements aus dem Phase-1-Seed.
struct AchievementDefinition: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let title: String
    let detail: String
    let trigger: AchievementTrigger

    static let all: [AchievementDefinition] = [
        .rookieBaker,
        .millisecondMaster,
        .flourPower,
        .precisionMachine,
        .earlyBird,
        .aroundTheWorld
    ]

    static let rookieBaker = AchievementDefinition(
        code: "rookie_baker", title: "Rookie Baker",
        detail: "Schließe dein erstes Spiel ab.", trigger: .firstGame)

    static let millisecondMaster = AchievementDefinition(
        code: "millisecond_master", title: "Millisecond Master",
        detail: "Erziele ein Perfect (≤ 50 ms).", trigger: .perfectOnce)

    static let flourPower = AchievementDefinition(
        code: "flour_power", title: "Flour Power",
        detail: "Erreiche eine Combo von 5.", trigger: .comboFive)

    static let precisionMachine = AchievementDefinition(
        code: "precision_machine", title: "Precision Machine",
        detail: "3 Perfects in Folge.", trigger: .threePerfectsRow)

    static let earlyBird = AchievementDefinition(
        code: "early_bird", title: "Early Bird",
        detail: "Spiele vor 08:00.", trigger: .beforeEightAM)

    static let aroundTheWorld = AchievementDefinition(
        code: "around_the_world", title: "Around the World",
        detail: "Braucht MapKit / Year in Swipe.", trigger: .deferred)
}