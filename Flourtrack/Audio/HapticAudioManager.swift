import Foundation
import CoreHaptics
import AVFoundation
import SwiftUI

/// Core Haptics + synthetisiertes AVFoundation-Audio, beides schaltbar.
/// Plain Klasse (kein @MainActor), Inject über `\.hapticAudio` EnvironmentKey.
final class HapticAudioManager {
    private(set) var hapticsEnabled: Bool = true
    private(set) var audioEnabled: Bool = true

    private var hapticEngine: CHHapticEngine?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?

    init() {}

    func configure(haptics: Bool, audio: Bool) {
        hapticsEnabled = haptics
        audioEnabled = audio
        if haptics { prepareHaptics() } else { stopHaptics() }
        if audio { prepareAudio() } else { stopAudio() }
    }

    // MARK: - Haptics
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            hapticEngine = engine
        } catch {
            hapticEngine = nil
        }
    }

    private func stopHaptics() {
        hapticEngine?.stop()
        hapticEngine = nil
    }

    func playTick() {
        guard hapticsEnabled else { return }
        playHaptic(intensity: 0.6, sharpness: 0.4, duration: 0.05)
    }

    func playRatingFeedback(_ rating: Rating) {
        guard hapticsEnabled else { return }
        switch rating {
        case .perfect:   playHaptic(intensity: 1.0, sharpness: 0.8, duration: 0.22)
        case .excellent: playHaptic(intensity: 0.85, sharpness: 0.65, duration: 0.16)
        case .good:      playHaptic(intensity: 0.65, sharpness: 0.5, duration: 0.12)
        case .okay:      playHaptic(intensity: 0.45, sharpness: 0.4, duration: 0.1)
        case .tooSlow:   playHaptic(intensity: 0.5, sharpness: 0.3, duration: 0.15)
        case .tooEarly:  playHaptic(intensity: 0.75, sharpness: 0.9, duration: 0.2)
        }
    }

    private func playHaptic(intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard let engine = hapticEngine else { return }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: duration)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // stiller Fehlschlag
        }
    }

    // MARK: - Audio
    private func prepareAudio() {
        guard audioEngine == nil else { return }
        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif

        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            audioEngine = engine
            playerNode = node
            audioFormat = format
        } catch {
            audioEngine = nil
            playerNode = nil
        }
    }

    private func stopAudio() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }

    func playTone(frequency: Double, duration: TimeInterval, gain: Float = 0.25) {
        guard audioEnabled, let node = playerNode, let format = audioFormat else { return }
        let sampleRate = format.sampleRate
        let count = Int(sampleRate * duration)
        guard count > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        buffer.frameLength = AVAudioFrameCount(count)
        let channel = buffer.floatChannelData![0]
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let attack = min(1.0, t * 60)
            let release = min(1.0, max(0, duration - t) * 20)
            let env = attack * release
            channel[i] = Float(sin(twoPi * frequency * t) * env * Double(gain))
        }
        if !node.isPlaying { node.play() }
        node.scheduleBuffer(buffer, completionHandler: nil)
    }

    func countdownTone(for step: Int) {
        playTone(frequency: 440.0 + Double(5 - step) * 30, duration: 0.12)
    }

    func ratingTone(_ rating: Rating) {
        let freq: Double
        switch rating {
        case .perfect:   freq = 1320
        case .excellent: freq = 990
        case .good:      freq = 770
        case .okay:      freq = 660
        case .tooSlow:   freq = 330
        case .tooEarly:  freq = 220
        }
        playTone(frequency: freq, duration: 0.3)
    }
}

// MARK: - SwiftUI Environment
private struct HapticAudioManagerKey: EnvironmentKey {
    static let defaultValue: HapticAudioManager = HapticAudioManager()
}

extension EnvironmentValues {
    var hapticAudio: HapticAudioManager {
        get { self[HapticAudioManagerKey.self] }
        set { self[HapticAudioManagerKey.self] = newValue }
    }
}