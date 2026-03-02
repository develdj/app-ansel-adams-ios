import Foundation
import Combine
import UserNotifications
import SwiftUI

// MARK: - Timer State

enum TimerState: Equatable {
    case idle
    case running(startTime: Date, pausedDuration: TimeInterval)
    case paused(elapsedAtPause: TimeInterval)
    case completed
    
    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
    
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
    
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}

// MARK: - Timer Phase

struct TimerPhase: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    let type: PhaseType
    let description: String?
    var isOptional: Bool = false
    
    enum PhaseType: String {
        case developer = "Developer"
        case stopBath = "Stop Bath"
        case fixer = "Fixer"
        case wash = "Wash"
        case exposure = "Exposure"
        case printDev = "Print Developer"
        case hardener = "Hardening Bath"
        case clearing = "Clearing Bath"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .developer: return "drop.fill"
            case .stopBath: return "stop.circle.fill"
            case .fixer: return "lock.fill"
            case .wash: return "water.waves"
            case .exposure: return "lightbulb.fill"
            case .printDev: return "photo.fill"
            case .hardener: return "shield.fill"
            case .clearing: return "sparkles"
            case .custom: return "timer"
            }
        }
        
        var color: Color {
            switch self {
            case .developer: return .blue
            case .stopBath: return .yellow
            case .fixer: return .purple
            case .wash: return .cyan
            case .exposure: return .orange
            case .printDev: return .green
            case .hardener: return .gray
            case .clearing: return .mint
            case .custom: return .secondary
            }
        }
    }
}

// MARK: - Darkroom Timer Manager

/// High-precision timer manager for darkroom processes
/// Uses CADisplayLink for smooth UI updates and precise timing
@MainActor
final class DarkroomTimerManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var state: TimerState = .idle
    @Published private(set) var currentPhaseIndex: Int = 0
    @Published private(set) var phases: [TimerPhase] = []
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var remainingTime: TimeInterval = 0
    @Published private(set) var progress: Double = 0
    @Published private(set) var isAgitationRequired: Bool = false
    @Published private(set) var agitationCountdown: TimeInterval = 0
    @Published private(set) var totalSessionDuration: TimeInterval = 0
    @Published private(set) var sessionElapsedTime: TimeInterval = 0
    
    // MARK: - Private Properties
    
    private var displayLink: CADisplayLink?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var agitationScheduler: AgitationScheduler?
    private var cancellables = Set<AnyCancellable>()
    
    private var phaseStartTime: Date?
    private var sessionStartTime: Date?
    private var lastAgitationTime: Date?
    private var nextAgitationTime: Date?
    
    // Audio/Haptic feedback
    private let feedback = AudioHapticFeedback.shared
    
    // MARK: - Computed Properties
    
    var currentPhase: TimerPhase? {
        guard currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }
    
    var isLastPhase: Bool {
        currentPhaseIndex >= phases.count - 1
    }
    
    var hasMorePhases: Bool {
        currentPhaseIndex < phases.count - 1
    }
    
    var formattedElapsedTime: String {
        formatTime(elapsedTime)
    }
    
    var formattedRemainingTime: String {
        formatTime(remainingTime)
    }
    
    var formattedTotalRemaining: String {
        let totalRemaining = phases.dropFirst(currentPhaseIndex).reduce(0) { $0 + $1.duration } - elapsedTime
        return formatTime(max(0, totalRemaining))
    }
    
    var sessionProgress: Double {
        guard totalSessionDuration > 0 else { return 0 }
        return min(1.0, sessionElapsedTime / totalSessionDuration)
    }
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    deinit {
        invalidateDisplayLink()
        endBackgroundTask()
    }
    
    // MARK: - Setup
    
    func setupPhases(_ phases: [TimerPhase], agitationScheduler: AgitationScheduler? = nil) {
        self.phases = phases
        self.agitationScheduler = agitationScheduler
        self.totalSessionDuration = phases.reduce(0) { $0 + $1.duration }
        reset()
    }
    
    // MARK: - Timer Control
    
    func start() {
        guard !phases.isEmpty else { return }
        
        let now = Date()
        
        switch state {
        case .idle:
            sessionStartTime = now
            phaseStartTime = now
            state = .running(startTime: now, pausedDuration: 0)
            startDisplayLink()
            beginBackgroundTask()
            feedback.playStartSound()
            scheduleNotifications()
            
        case .paused(let elapsedAtPause):
            let adjustedStartTime = now.addingTimeInterval(-elapsedAtPause)
            phaseStartTime = adjustedStartTime
            state = .running(startTime: adjustedStartTime, pausedDuration: 0)
            startDisplayLink()
            beginBackgroundTask()
            feedback.playResumeSound()
            
        case .running, .completed:
            break
        }
        
        setupAgitationSchedule()
    }
    
    func pause() {
        guard case .running = state else { return }
        
        state = .paused(elapsedAtPause: elapsedTime)
        invalidateDisplayLink()
        endBackgroundTask()
        cancelNotifications()
        feedback.playPauseSound()
    }
    
    func stop() {
        invalidateDisplayLink()
        endBackgroundTask()
        cancelNotifications()
        reset()
        feedback.playStopSound()
    }
    
    func reset() {
        state = .idle
        currentPhaseIndex = 0
        elapsedTime = 0
        remainingTime = currentPhase?.duration ?? 0
        progress = 0
        sessionElapsedTime = 0
        isAgitationRequired = false
        agitationCountdown = 0
        phaseStartTime = nil
        sessionStartTime = nil
        lastAgitationTime = nil
        nextAgitationTime = nil
        invalidateDisplayLink()
        endBackgroundTask()
        cancelNotifications()
    }
    
    func skipToNextPhase() {
        guard hasMorePhases else {
            completeSession()
            return
        }
        
        // Mark current phase as complete and move to next
        currentPhaseIndex += 1
        elapsedTime = 0
        remainingTime = currentPhase?.duration ?? 0
        progress = 0
        phaseStartTime = Date()
        
        // Reset agitation for new phase
        setupAgitationSchedule()
        
        feedback.playPhaseCompleteSound()
        scheduleNotifications()
    }
    
    func skipToPreviousPhase() {
        guard currentPhaseIndex > 0 else { return }
        
        currentPhaseIndex -= 1
        elapsedTime = 0
        remainingTime = currentPhase?.duration ?? 0
        progress = 0
        phaseStartTime = Date()
        setupAgitationSchedule()
        scheduleNotifications()
    }
    
    func jumpToPhase(at index: Int) {
        guard index >= 0 && index < phases.count else { return }
        
        currentPhaseIndex = index
        elapsedTime = 0
        remainingTime = currentPhase?.duration ?? 0
        progress = 0
        phaseStartTime = Date()
        setupAgitationSchedule()
        scheduleNotifications()
    }
    
    // MARK: - Private Methods
    
    private func startDisplayLink() {
        invalidateDisplayLink()
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateTimer))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateTimer() {
        guard case .running(let startTime, _) = state,
              let currentPhase = currentPhase else { return }
        
        let now = Date()
        elapsedTime = now.timeIntervalSince(startTime)
        remainingTime = max(0, currentPhase.duration - elapsedTime)
        progress = min(1.0, elapsedTime / currentPhase.duration)
        
        // Update session elapsed time
        if let sessionStart = sessionStartTime {
            sessionElapsedTime = now.timeIntervalSince(sessionStart)
        }
        
        // Check for agitation
        updateAgitationStatus()
        
        // Check if phase is complete
        if remainingTime <= 0 {
            completePhase()
        }
    }
    
    private func completePhase() {
        feedback.playPhaseCompleteSound()
        
        if hasMorePhases {
            skipToNextPhase()
        } else {
            completeSession()
        }
    }
    
    private func completeSession() {
        state = .completed
        invalidateDisplayLink()
        endBackgroundTask()
        cancelNotifications()
        feedback.playSessionCompleteSound()
        
        // Post notification for session completion
        NotificationCenter.default.post(
            name: .darkroomSessionCompleted,
            object: nil,
            userInfo: ["phasesCompleted": phases.count]
        )
    }
    
    // MARK: - Agitation
    
    private func setupAgitationSchedule() {
        guard let schedule = agitationScheduler,
              let currentPhase = currentPhase,
              currentPhase.type == .developer else {
            isAgitationRequired = false
            agitationCountdown = 0
            return
        }
        
        let now = Date()
        lastAgitationTime = now
        
        // Calculate next agitation time
        if let initialSeconds = schedule.initialContinuousSeconds {
            // After initial continuous period, first agitation
            nextAgitationTime = now.addingTimeInterval(TimeInterval(initialSeconds))
        } else {
            // Continuous agitation - no notifications needed
            isAgitationRequired = true
            agitationCountdown = 0
            return
        }
        
        updateAgitationStatus()
    }
    
    private func updateAgitationStatus() {
        guard let nextTime = nextAgitationTime else { return }
        
        let now = Date()
        let timeUntilAgitation = nextTime.timeIntervalSince(now)
        
        agitationCountdown = max(0, timeUntilAgitation)
        
        if timeUntilAgitation <= 0 && !isAgitationRequired {
            isAgitationRequired = true
            feedback.playAgitationAlert()
            
            // Schedule next agitation
            if let schedule = agitationScheduler {
                let elapsedInPhase = Int(elapsedTime)
                if let nextInterval = schedule.intervals.first(where: { $0 > elapsedInPhase }) {
                    nextAgitationTime = phaseStartTime?.addingTimeInterval(TimeInterval(nextInterval))
                } else {
                    nextAgitationTime = nil
                }
            }
        }
    }
    
    func acknowledgeAgitation() {
        isAgitationRequired = false
        lastAgitationTime = Date()
        feedback.playAgitationCompleteSound()
    }
    
    // MARK: - Background Task
    
    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission: \(granted)")
        }
    }
    
    private func scheduleNotifications() {
        guard let currentPhase = currentPhase else { return }
        
        // Schedule phase completion notification
        let content = UNMutableNotificationContent()
        content.title = "Darkroom Timer"
        content.body = "\(currentPhase.name) complete!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingTime, repeats: false)
        let request = UNNotificationRequest(identifier: "phase-complete-\(currentPhase.id.uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Formatting
    
    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let darkroomSessionCompleted = Notification.Name("darkroomSessionCompleted")
    static let darkroomPhaseCompleted = Notification.Name("darkroomPhaseCompleted")
    static let darkroomAgitationRequired = Notification.Name("darkroomAgitationRequired")
}
