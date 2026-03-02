import Foundation
import Combine

// MARK: - Agitation Scheduler

/// Manages precise agitation timing for film development
/// Follows Ansel Adams' recommended agitation techniques
@MainActor
final class AgitationScheduler: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isInInitialContinuous: Bool = false
    @Published var isAgitationDue: Bool = false
    @Published var nextAgitationIn: TimeInterval = 0
    @Published var agitationCount: Int = 0
    @Published var totalAgitations: Int = 0
    @Published var initialContinuousRemaining: TimeInterval = 0
    
    // MARK: - Private Properties
    
    private var schedule: AgitationSchedule
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var agitationDueTimer: Timer?
    
    private var developmentStartTime: Date?
    private var lastAgitationTime: Date?
    private var nextScheduledAgitation: Date?
    private var initialContinuousEndTime: Date?
    
    private let feedback = AudioHapticFeedback.shared
    
    // MARK: - Computed Properties
    
    var isContinuousAgitation: Bool {
        schedule.initialContinuousSeconds == nil
    }
    
    var hasInitialContinuousPhase: Bool {
        schedule.initialContinuousSeconds != nil && schedule.initialContinuousSeconds! > 0
    }
    
    var formattedNextAgitation: String {
        let seconds = Int(nextAgitationIn)
        if seconds >= 60 {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
        return "\(seconds)s"
    }
    
    var progressToNextAgitation: Double {
        guard let lastTime = lastAgitationTime,
              let nextTime = nextScheduledAgitation else { return 0 }
        
        let totalInterval = nextTime.timeIntervalSince(lastTime)
        let elapsed = Date().timeIntervalSince(lastTime)
        return min(1.0, max(0, elapsed / totalInterval))
    }
    
    // MARK: - Initialization
    
    init(schedule: AgitationSchedule) {
        self.schedule = schedule
        self.totalAgitations = schedule.intervals.count
    }
    
    convenience init(style: AgitationStyle) {
        self.init(schedule: style.agitationSchedule)
    }
    
    // MARK: - Control
    
    func start() {
        let now = Date()
        developmentStartTime = now
        agitationCount = 0
        
        if let initialSeconds = schedule.initialContinuousSeconds, initialSeconds > 0 {
            // Start initial continuous phase
            isInInitialContinuous = true
            initialContinuousEndTime = now.addingTimeInterval(TimeInterval(initialSeconds))
            initialContinuousRemaining = TimeInterval(initialSeconds)
            
            // Schedule first agitation after initial period
            if let firstInterval = schedule.intervals.first {
                nextScheduledAgitation = now.addingTimeInterval(TimeInterval(firstInterval))
            }
        } else {
            // Continuous agitation throughout
            isInInitialContinuous = false
            isAgitationDue = true
            nextScheduledAgitation = nil
        }
        
        startUpdateTimer()
    }
    
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        agitationDueTimer?.invalidate()
        agitationDueTimer = nil
        
        isInInitialContinuous = false
        isAgitationDue = false
        developmentStartTime = nil
        lastAgitationTime = nil
        nextScheduledAgitation = nil
        initialContinuousEndTime = nil
    }
    
    func reset() {
        stop()
        agitationCount = 0
        nextAgitationIn = 0
        initialContinuousRemaining = 0
    }
    
    func acknowledgeAgitation() {
        guard isAgitationDue || isInInitialContinuous else { return }
        
        let now = Date()
        lastAgitationTime = now
        isAgitationDue = false
        agitationCount += 1
        
        // Play completion feedback
        feedback.playAgitationCompleteSound()
        
        // Check if initial continuous phase just ended
        if isInInitialContinuous {
            if let endTime = initialContinuousEndTime, now >= endTime {
                isInInitialContinuous = false
                // First scheduled agitation is now due
                isAgitationDue = true
                feedback.playAgitationAlert()
            }
        }
        
        // Schedule next agitation
        scheduleNextAgitation(from: now)
    }
    
    // MARK: - Private Methods
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatus()
            }
        }
    }
    
    private func updateStatus() {
        let now = Date()
        
        // Update initial continuous countdown
        if isInInitialContinuous, let endTime = initialContinuousEndTime {
            initialContinuousRemaining = max(0, endTime.timeIntervalSince(now))
            
            if initialContinuousRemaining <= 0 {
                // Initial phase complete
                isInInitialContinuous = false
                isAgitationDue = true
                feedback.playAgitationAlert()
            }
        }
        
        // Update next agitation countdown
        if let nextTime = nextScheduledAgitation {
            nextAgitationIn = max(0, nextTime.timeIntervalSince(now))
            
            if nextAgitationIn <= 0 && !isAgitationDue {
                isAgitationDue = true
                feedback.playAgitationAlert()
            }
        }
    }
    
    private func scheduleNextAgitation(from time: Date) {
        guard agitationCount < schedule.intervals.count else {
            // No more scheduled agitations
            nextScheduledAgitation = nil
            nextAgitationIn = 0
            return
        }
        
        // Find the next interval that hasn't passed
        let elapsedTime = time.timeIntervalSince(developmentStartTime ?? time)
        
        if let nextInterval = schedule.intervals.dropFirst(agitationCount).first {
            let nextAgitationTime = (developmentStartTime ?? time).addingTimeInterval(TimeInterval(nextInterval))
            nextScheduledAgitation = nextAgitationTime
            nextAgitationIn = nextAgitationTime.timeIntervalSince(time)
        }
    }
    
    // MARK: - Schedule Presets
    
    /// Ansel Adams Standard: 1 min continuous, then 10-15 sec every minute
    static var standard: AgitationScheduler {
        AgitationScheduler(schedule: AgitationSchedule(
            initialContinuousSeconds: 60,
            intervals: Array(stride(from: 120, through: 3600, by: 60)),
            durationPerAgitation: 15
        ))
    }
    
    /// Minimal agitation: 1 min continuous, then 5 sec every 2 minutes
    static var minimal: AgitationScheduler {
        AgitationScheduler(schedule: AgitationSchedule(
            initialContinuousSeconds: 60,
            intervals: Array(stride(from: 180, through: 3600, by: 120)),
            durationPerAgitation: 5
        ))
    }
    
    /// Ilford method: 10 sec inversions each minute
    static var ilford: AgitationScheduler {
        AgitationScheduler(schedule: AgitationSchedule(
            initialContinuousSeconds: 10,
            intervals: Array(stride(from: 70, through: 3600, by: 60)),
            durationPerAgitation: 10
        ))
    }
    
    /// Continuous agitation (rotary processor)
    static var continuous: AgitationScheduler {
        AgitationScheduler(schedule: AgitationSchedule(
            initialContinuousSeconds: nil,
            intervals: [],
            durationPerAgitation: 0
        ))
    }
}

// MARK: - Agitation Logger

/// Logs agitation events for analysis and consistency
@MainActor
final class AgitationLogger: ObservableObject {
    
    @Published var logs: [AgitationLog] = []
    
    func log(event: AgitationEvent, phase: String, timestamp: Date = Date()) {
        let log = AgitationLog(
            event: event,
            phase: phase,
            timestamp: timestamp
        )
        logs.append(log)
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    func exportLogs() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        
        return logs.map { log in
            "[\(formatter.string(from: log.timestamp))] \(log.event.rawValue) - \(log.phase)"
        }.joined(separator: "\n")
    }
}

struct AgitationLog: Identifiable {
    let id = UUID()
    let event: AgitationEvent
    let phase: String
    let timestamp: Date
}

enum AgitationEvent: String {
    case started = "Started"
    case initialContinuousBegan = "Initial Continuous Began"
    case initialContinuousEnded = "Initial Continuous Ended"
    case agitationDue = "Agitation Due"
    case agitationAcknowledged = "Agitation Acknowledged"
    case agitationCompleted = "Agitation Completed"
    case stopped = "Stopped"
}

// MARK: - Agitation Guide

/// Provides visual and audio guidance during agitation
@MainActor
final class AgitationGuide: ObservableObject {
    
    @Published var currentInstruction: String = ""
    @Published var countdownValue: Int = 0
    @Published var isGuiding: Bool = false
    
    private var guideTimer: Timer?
    private let feedback = AudioHapticFeedback.shared
    
    func startGuidance(duration: Int, style: AgitationStyle) {
        isGuiding = true
        countdownValue = duration
        
        updateInstruction(for: style, remaining: duration)
        
        guideTimer?.invalidate()
        guideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.countdownValue -= 1
                
                if self.countdownValue <= 0 {
                    self.stopGuidance()
                    self.feedback.playAgitationCompleteSound()
                } else {
                    self.updateInstruction(for: style, remaining: self.countdownValue)
                    
                    // Countdown beeps for last 5 seconds
                    if self.countdownValue <= 5 {
                        self.feedback.playCountdownBeep(secondsRemaining: self.countdownValue)
                    }
                }
            }
        }
    }
    
    func stopGuidance() {
        guideTimer?.invalidate()
        guideTimer = nil
        isGuiding = false
        currentInstruction = ""
        countdownValue = 0
    }
    
    private func updateInstruction(for style: AgitationStyle, remaining: Int) {
        switch style {
        case .standard:
            if remaining > 10 {
                currentInstruction = "Invert tank continuously"
            } else {
                currentInstruction = "Tap tank to release bubbles"
            }
        case .ilford:
            currentInstruction = "4 inversions (\(remaining)s remaining)"
        case .minimal:
            currentInstruction = "Gentle swirl (\(remaining)s remaining)"
        case .continuous:
            currentInstruction = "Continuous rotation"
        case .rotary:
            currentInstruction = "Rotary processing active"
        }
    }
}

// MARK: - Agitation Presets

/// Common agitation presets for different development scenarios
enum AgitationPreset: String, CaseIterable {
    case standard = "Standard (Ansel Adams)"
    case minimal = "Minimal"
    case ilford = "Ilford Method"
    case continuous = "Continuous"
    case rotary = "Rotary"
    
    var style: AgitationStyle {
        switch self {
        case .standard: return .standard
        case .minimal: return .minimal
        case .ilford: return .ilford
        case .continuous: return .continuous
        case .rotary: return .rotary
        }
    }
    
    var description: String {
        switch self {
        case .standard:
            return "1 minute continuous, then 10-15 seconds every minute"
        case .minimal:
            return "1 minute continuous, then 5 seconds every 2 minutes"
        case .ilford:
            return "10 seconds of inversions each minute"
        case .continuous:
            return "Continuous agitation throughout"
        case .rotary:
            return "Rotary processor continuous agitation"
        }
    }
    
    var recommendedFor: [String] {
        switch self {
        case .standard:
            return ["General purpose", "Fine grain developers", "Standard contrast"]
        case .minimal:
            return ["High acutance", "Edge effects", "Compensating development"]
        case .ilford:
            return ["Ilford films", "Consistent results", "Tank development"]
        case .continuous:
            return ["Small tanks", "Short development times", "Critical timing"]
        case .rotary:
            return ["Jobo processors", "Consistent agitation", "Large batches"]
        }
    }
}
