import Foundation
import SwiftData
import Combine

enum GamePhase: Equatable {
    case idle
    case counting
    case waitingTap
    case result
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published var phase: GamePhase = .idle
    @Published var countdownValue: Int = 5
    @Published var rating: Rating?
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var streak: Int = 0
    @Published var accuracyMs: Int = 0
    @Published var bestScore: Int = 0
    @Published var newlyUnlocked: [AchievementDefinition] = []

    private var zeroTime: Date?
    private var countdownTimer: Timer?
    private var tooSlowWork: DispatchWorkItem?

    private let gameRepo: GameRepository
    private let achievementRepo: AchievementRepository
    private let haptics: HapticAudioManager

    init(gameRepo: GameRepository, achievementRepo: AchievementRepository, haptics: HapticAudioManager) {
        self.gameRepo = gameRepo
        self.achievementRepo = achievementRepo
        self.haptics = haptics
        refreshBest()
    }

    func refreshBest() {
        bestScore = (try? gameRepo.bestScore()) ?? 0
    }

    func start() {
        countdownTimer?.invalidate()
        tooSlowWork?.cancel()
        phase = .counting
        countdownValue = 5
        rating = nil
        score = 0
        accuracyMs = 0
        newlyUnlocked = []
        zeroTime = Date().addingTimeInterval(5)
        haptics.countdownTone(for: 5)
        haptics.playTick()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .counting, let zero = zeroTime else { return }
        let remaining = zero.timeIntervalSinceNow
        let displayed = Int(ceil(max(0, remaining)))
        if displayed != countdownValue {
            countdownValue = displayed
            if displayed > 0 {
                haptics.countdownTone(for: displayed)
                haptics.playTick()
            }
        }
        if remaining <= 0 {
            countdownTimer?.invalidate()
            countdownValue = 0
            phase = .waitingTap
            scheduleTooSlowFallback()
        }
    }

    private func scheduleTooSlowFallback() {
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.phase == .waitingTap else { return }
                self.finalize(accuracyMs: 1500, rating: .tooSlow)
            }
        }
        tooSlowWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    func tap() {
        switch phase {
        case .counting:
            guard let zero = zeroTime else { return }
            let earlyMs = Int(max(0, zero.timeIntervalSinceNow) * 1000)
            finalize(accuracyMs: max(1, earlyMs), rating: .tooEarly)
        case .waitingTap:
            guard let zero = zeroTime else { return }
            let lateMs = Int(max(0, -zero.timeIntervalSinceNow) * 1000)
            finalize(accuracyMs: lateMs, rating: Rating.from(accuracyMs: lateMs))
        default:
            break
        }
    }

    private func finalize(accuracyMs: Int, rating: Rating) {
        countdownTimer?.invalidate()
        tooSlowWork?.cancel()
        self.accuracyMs = accuracyMs
        self.rating = rating
        if rating.countsAsHit {
            combo += 1
            streak += 1
        } else {
            combo = 0
            streak = 0
        }
        score = rating.isMiss ? 0 : Rating.score(accuracyMs: accuracyMs, combo: combo)
        haptics.playRatingFeedback(rating)
        haptics.ratingTone(rating)
        phase = .result
        persist(rating: rating, accuracyMs: accuracyMs)
    }

    private func persist(rating: Rating, accuracyMs: Int) {
        let attempt = GameAttempt(
            score: score,
            accuracyMs: accuracyMs,
            rating: rating,
            combo: combo,
            streak: streak,
            tappedEarly: rating == .tooEarly
        )
        do {
            try gameRepo.save(attempt)
            try evaluateAchievements(rating: rating)
        } catch {
            // MVP: stiller Fehlschlag
        }
        refreshBest()
    }

    private func evaluateAchievements(rating: Rating) throws {
        var unlocked: [AchievementDefinition] = []
        if try achievementRepo.unlock(code: "rookie_baker") { unlocked.append(.rookieBaker) }
        if rating == .perfect, try achievementRepo.unlock(code: "millisecond_master") { unlocked.append(.millisecondMaster) }
        if combo >= 5, try achievementRepo.unlock(code: "flour_power") { unlocked.append(.flourPower) }
        let perfectStreak = try gameRepo.lastPerfectsInARow()
        if perfectStreak >= 3, try achievementRepo.unlock(code: "precision_machine") { unlocked.append(.precisionMachine) }
        if Calendar.current.component(.hour, from: .now) < 8, try achievementRepo.unlock(code: "early_bird") { unlocked.append(.earlyBird) }
        newlyUnlocked = unlocked
    }

    func reset() {
        countdownTimer?.invalidate()
        tooSlowWork?.cancel()
        phase = .idle
        rating = nil
        score = 0
        accuracyMs = 0
        newlyUnlocked = []
    }
}