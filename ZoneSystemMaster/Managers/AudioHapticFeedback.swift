import Foundation
import AVFoundation
import UIKit
import CoreHaptics

// MARK: - Audio/Haptic Feedback Manager

/// Provides audio and haptic feedback for darkroom timer events
/// Designed to work in silent mode and with precise timing
@MainActor
final class AudioHapticFeedback: ObservableObject {
    
    static let shared = AudioHapticFeedback()
    
    // MARK: - Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var hapticEngine: CHHapticEngine?
    private var notificationGenerator: UINotificationFeedbackGenerator?
    private var impactGenerator: UIImpactFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?
    
    private var isHapticAvailable: Bool = false
    private var isAudioEnabled: Bool = true
    private var isHapticEnabled: Bool = true
    
    // MARK: - Sound Resources
    
    enum SoundType: String {
        case start = "timer_start"
        case pause = "timer_pause"
        case resume = "timer_resume"
        case stop = "timer_stop"
        case phaseComplete = "phase_complete"
        case sessionComplete = "session_complete"
        case agitationAlert = "agitation_alert"
        case agitationComplete = "agitation_complete"
        case countdownBeep = "countdown_beep"
        case warning = "warning"
    }
    
    // MARK: - Initialization
    
    private init() {
        setupAudioSession()
        setupHaptics()
        setupFeedbackGenerators()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            isHapticAvailable = false
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            isHapticAvailable = true
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
            
            // Handle engine stopped
            hapticEngine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
            isHapticAvailable = false
        }
    }
    
    private func setupFeedbackGenerators() {
        notificationGenerator = UINotificationFeedbackGenerator()
        impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        selectionGenerator = UISelectionFeedbackGenerator()
        
        notificationGenerator?.prepare()
        impactGenerator?.prepare()
        selectionGenerator?.prepare()
    }
    
    // MARK: - Settings
    
    func setAudioEnabled(_ enabled: Bool) {
        isAudioEnabled = enabled
    }
    
    func setHapticEnabled(_ enabled: Bool) {
        isHapticEnabled = enabled
    }
    
    // MARK: - Timer Event Sounds
    
    func playStartSound() {
        playSystemSound(id: 1113) // Tock sound
        playHapticPattern(.success)
    }
    
    func playPauseSound() {
        playSystemSound(id: 1114) // Tock sound variant
        playHapticPattern(.light)
    }
    
    func playResumeSound() {
        playSystemSound(id: 1113)
        playHapticPattern(.medium)
    }
    
    func playStopSound() {
        playSystemSound(id: 1112)
        playHapticPattern(.heavy)
    }
    
    func playPhaseCompleteSound() {
        // Triple beep pattern
        playBeepSequence(count: 3, interval: 0.15)
        playHapticPattern(.success)
        
        // Add notification
        notificationGenerator?.notificationOccurred(.success)
    }
    
    func playSessionCompleteSound() {
        // Celebration pattern
        playBeepSequence(count: 5, interval: 0.1)
        playHapticPattern(.celebration)
        
        notificationGenerator?.notificationOccurred(.success)
    }
    
    func playAgitationAlert() {
        // Rhythmic pattern for agitation
        playBeepSequence(count: 2, interval: 0.2)
        playHapticPattern(.agitation)
        
        notificationGenerator?.notificationOccurred(.warning)
    }
    
    func playAgitationCompleteSound() {
        playSystemSound(id: 1105) // Short beep
        playHapticPattern(.light)
    }
    
    func playCountdownBeep(secondsRemaining: Int) {
        guard secondsRemaining <= 5 && secondsRemaining > 0 else { return }
        
        playSystemSound(id: 1105)
        
        // Increasing intensity haptic
        let intensity = 1.0 - (Double(secondsRemaining) / 5.0)
        playHapticIntensity(intensity)
    }
    
    func playWarningSound() {
        playSystemSound(id: 1006) // Alert
        notificationGenerator?.notificationOccurred(.error)
    }
    
    // MARK: - Custom Patterns
    
    func playFilmLoadingComplete() {
        playBeepSequence(count: 2, interval: 0.3)
        playHapticPattern(.medium)
    }
    
    func playExposureComplete() {
        playSystemSound(id: 1113)
        playHapticPattern(.light)
    }
    
    func playTestStripComplete() {
        playBeepSequence(count: 4, interval: 0.1)
        playHapticPattern(.success)
    }
    
    // MARK: - Private Methods
    
    private func playSystemSound(id: UInt32) {
        guard isAudioEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }
    
    private func playBeepSequence(count: Int, interval: TimeInterval) {
        guard isAudioEnabled else { return }
        
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + (interval * Double(i))) {
                AudioServicesPlaySystemSound(1105)
            }
        }
    }
    
    // MARK: - Haptic Patterns
    
    enum HapticPattern {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case agitation
        case celebration
    }
    
    private func playHapticPattern(_ pattern: HapticPattern) {
        guard isHapticEnabled else { return }
        
        switch pattern {
        case .light:
            impactGenerator?.impactOccurred(intensity: 0.3)
        case .medium:
            impactGenerator?.impactOccurred(intensity: 0.6)
        case .heavy:
            impactGenerator?.impactOccurred(intensity: 1.0)
        case .success:
            playCustomHapticPattern(events: [
                (0.0, 0.5),
                (0.1, 0.8),
                (0.2, 1.0)
            ])
        case .warning:
            playCustomHapticPattern(events: [
                (0.0, 0.8),
                (0.15, 0.8)
            ])
        case .error:
            playCustomHapticPattern(events: [
                (0.0, 1.0),
                (0.1, 0.5),
                (0.2, 1.0)
            ])
        case .agitation:
            // Rhythmic pattern for agitation
            playCustomHapticPattern(events: [
                (0.0, 0.6),
                (0.15, 0.6),
                (0.3, 0.8)
            ])
        case .celebration:
            // Complex celebration pattern
            playCustomHapticPattern(events: [
                (0.0, 0.5),
                (0.08, 0.7),
                (0.16, 0.9),
                (0.24, 1.0),
                (0.4, 0.8)
            ])
        }
    }
    
    private func playHapticIntensity(_ intensity: Double) {
        guard isHapticEnabled else { return }
        impactGenerator?.impactOccurred(intensity: CGFloat(intensity))
    }
    
    private func playCustomHapticPattern(events: [(time: Double, intensity: Double)]) {
        guard isHapticAvailable,
              let engine = hapticEngine else { return }
        
        var hapticEvents: [CHHapticEvent] = []
        
        for event in events {
            let intensityParameter = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: Float(event.intensity)
            )
            let sharpnessParameter = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: Float(event.intensity)
            )
            
            let hapticEvent = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensityParameter, sharpnessParameter],
                relativeTime: event.time
            )
            hapticEvents.append(hapticEvent)
        }
        
        do {
            let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    // MARK: - Continuous Haptics
    
    func startContinuousAgitationHaptic() -> CHHapticPatternPlayer? {
        guard isHapticAvailable,
              let engine = hapticEngine else { return nil }
        
        let intensityParameter = CHHapticEventParameter(
            parameterID: .hapticIntensity,
            value: 0.3
        )
        let sharpnessParameter = CHHapticEventParameter(
            parameterID: .hapticSharpness,
            value: 0.5
        )
        
        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensityParameter, sharpnessParameter],
            relativeTime: 0,
            duration: 60 // Max duration
        )
        
        do {
            let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            return player
        } catch {
            print("Failed to start continuous haptic: \(error)")
            return nil
        }
    }
    
    func stopContinuousHaptic(_ player: CHHapticPatternPlayer?) {
        try? player?.stop(atTime: 0)
    }
}

// MARK: - Audio Services Extension

/// System sound IDs for reference
extension AudioServices {
    static let newMailSound: UInt32 = 1000
    static let mailSentSound: UInt32 = 1001
    static let voicemailSound: UInt32 = 1002
    static let receivedMessageSound: UInt32 = 1003
    static let sentMessageSound: UInt32 = 1004
    static let alarmSound: UInt32 = 1005
    static let lowPowerSound: UInt32 = 1006
    static let smsReceived1: UInt32 = 1007
    static let smsReceived2: UInt32 = 1008
    static let smsReceived3: UInt32 = 1009
    static let smsReceived4: UInt32 = 1010
    static let smsReceivedVibrate: UInt32 = 1011
    static let smsReceived1_2: UInt32 = 1012
    static let smsReceived2_2: UInt32 = 1013
    static let smsReceived3_2: UInt32 = 1014
    static let smsReceived4_2: UInt32 = 1015
    static let smsReceivedVibrate_2: UInt32 = 1016
    static let voicemail_2: UInt32 = 1017
    static let anticipateSound: UInt32 = 1020
    static let coinSound: UInt32 = 1103
    static let cameraShutterSound: UInt32 = 1108
    static let beginRecordingSound: UInt32 = 1113
    static let endRecordingSound: UInt32 = 1114
}
