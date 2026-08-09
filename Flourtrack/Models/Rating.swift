import Foundation

/// Bewertungsstufen für einen Spielversuch.
enum Rating: String, Codable, CaseIterable, Identifiable {
    case perfect = "Perfect"
    case excellent = "Excellent"
    case good = "Good"
    case okay = "Okay"
    case tooSlow = "Too Slow"
    case tooEarly = "Too Early"

    var id: String { rawValue }

    // Schwellen in ms (|Δ| zum Tap-Zeitpunkt bei 0).
    static let perfectThreshold = 50
    static let excellentThreshold = 120
    static let goodThreshold = 250
    static let okayThreshold = 500

    static func from(accuracyMs: Int) -> Rating {
        if accuracyMs <= perfectThreshold { return .perfect }
        if accuracyMs <= excellentThreshold { return .excellent }
        if accuracyMs <= goodThreshold { return .good }
        if accuracyMs <= okayThreshold { return .okay }
        return .tooSlow
    }

    /// Zählt als Treffer (Combo +1).
    var countsAsHit: Bool {
        switch self {
        case .perfect, .excellent, .good, .okay: return true
        case .tooSlow, .tooEarly: return false
        }
    }

    var isMiss: Bool { !countsAsHit }

    var localizedName: String { rawValue }

    /// Basis-Score ohne Combo-Multiplikator.
    static func baseScore(accuracyMs: Int) -> Int {
        max(0, 1000 - accuracyMs * 2)
    }

    /// Score inkl. Combo-Multiplikator (combo ist der laufende Combo-Stand).
    static func score(accuracyMs: Int, combo: Int) -> Int {
        let base = baseScore(accuracyMs: accuracyMs)
        let multiplier = 1.0 + Double(combo) * 0.1
        return Int((Double(base) * multiplier).rounded())
    }
}