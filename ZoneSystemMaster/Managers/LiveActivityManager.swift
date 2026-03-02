import Foundation
import ActivityKit
import SwiftUI

// MARK: - Live Activity Manager

/// Manages Live Activities for darkroom timer on iOS Lock Screen
/// Provides real-time updates for development and printing sessions
@available(iOS 16.1, *)
@MainActor
final class LiveActivityManager: ObservableObject {
    
    static let shared = LiveActivityManager()
    
    // MARK: - Properties
    
    private var currentActivity: Activity<DarkroomTimerAttributes>?
    private var updateTimer: Timer?
    
    @Published var isActivityActive: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    private func requestAuthorization() {
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            print("Live Activities are enabled")
        } else {
            print("Live Activities are not enabled")
        }
    }
    
    // MARK: - Activity Control
    
    func startActivity(
        sessionType: SessionType,
        currentPhase: String,
        totalPhases: Int,
        currentPhaseIndex: Int,
        totalDuration: TimeInterval,
        remainingTime: TimeInterval
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // End any existing activity
        endActivity()
        
        let attributes = DarkroomTimerAttributes(
            sessionType: sessionType,
            totalPhases: totalPhases,
            totalDuration: totalDuration
        )
        
        let contentState = DarkroomTimerAttributes.ContentState(
            currentPhase: currentPhase,
            currentPhaseIndex: currentPhaseIndex,
            remainingTime: remainingTime,
            progress: 0.0,
            isAgitationRequired: false,
            agitationCountdown: 0
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            isActivityActive = true
            print("Started Live Activity: \(currentActivity?.id ?? "unknown")")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updateActivity(
        currentPhase: String,
        currentPhaseIndex: Int,
        remainingTime: TimeInterval,
        progress: Double,
        isAgitationRequired: Bool = false,
        agitationCountdown: TimeInterval = 0
    ) {
        guard let activity = currentActivity else { return }
        
        let contentState = DarkroomTimerAttributes.ContentState(
            currentPhase: currentPhase,
            currentPhaseIndex: currentPhaseIndex,
            remainingTime: remainingTime,
            progress: progress,
            isAgitationRequired: isAgitationRequired,
            agitationCountdown: agitationCountdown
        )
        
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        let finalState = DarkroomTimerAttributes.ContentState(
            currentPhase: "Complete",
            currentPhaseIndex: activity.attributes.totalPhases,
            remainingTime: 0,
            progress: 1.0,
            isAgitationRequired: false,
            agitationCountdown: 0
        )
        
        let content = ActivityContent(state: finalState, staleDate: nil)
        
        Task {
            await activity.end(content, dismissalPolicy: .default)
            isActivityActive = false
            currentActivity = nil
        }
    }
    
    func endActivityImmediately() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            isActivityActive = false
            currentActivity = nil
        }
    }
}

// MARK: - Live Activity Attributes

@available(iOS 16.1, *)
struct DarkroomTimerAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        var currentPhase: String
        var currentPhaseIndex: Int
        var remainingTime: TimeInterval
        var progress: Double
        var isAgitationRequired: Bool
        var agitationCountdown: TimeInterval
        
        var formattedRemainingTime: String {
            let totalSeconds = Int(remainingTime)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            if minutes > 0 {
                return String(format: "%d:%02d", minutes, seconds)
            } else {
                return String(format: "%02d", seconds)
            }
        }
        
        var formattedAgitationCountdown: String {
            let totalSeconds = Int(agitationCountdown)
            return String(format: "%02d", totalSeconds)
        }
    }
    
    var sessionType: SessionType
    var totalPhases: Int
    var totalDuration: TimeInterval
}

enum SessionType: String, Codable, CaseIterable {
    case filmDevelopment = "Film Development"
    case printDevelopment = "Print Development"
    case testStrip = "Test Strip"
    case splitGrade = "Split Grade"
    
    var icon: String {
        switch self {
        case .filmDevelopment: return "film"
        case .printDevelopment: return "photo"
        case .testStrip: return "rectangle.split.3x1"
        case .splitGrade: return "circle.lefthalf.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .filmDevelopment: return .blue
        case .printDevelopment: return .green
        case .testStrip: return .orange
        case .splitGrade: return .purple
        }
    }
}

// MARK: - Live Activity Widget Views

@available(iOS 16.1, *)
struct DarkroomTimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DarkroomTimerAttributes.self) { context in
            // Lock Screen / Notification Center
            DarkroomTimerLockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DarkroomTimerExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DarkroomTimerExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    DarkroomTimerExpandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DarkroomTimerExpandedBottom(context: context)
                }
            } compactLeading: {
                DarkroomTimerCompactLeading(context: context)
            } compactTrailing: {
                DarkroomTimerCompactTrailing(context: context)
            } minimal: {
                DarkroomTimerMinimal(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct DarkroomTimerLockScreenView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: context.attributes.sessionType.icon)
                    .foregroundColor(context.attributes.sessionType.color)
                Text(context.attributes.sessionType.rawValue)
                    .font(.headline)
                Spacer()
                Text("Phase \(context.state.currentPhaseIndex + 1)/\(context.attributes.totalPhases)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Current Phase
            HStack {
                Text(context.state.currentPhase)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // Timer Display
            HStack {
                Text(context.state.formattedRemainingTime)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
                Spacer()
            }
            
            // Progress Bar
            ProgressView(value: context.state.progress)
                .tint(context.attributes.sessionType.color)
            
            // Agitation Alert
            if context.state.isAgitationRequired {
                HStack {
                    Image(systemName: "arrow.2.circlepath")
                        .foregroundColor(.yellow)
                    Text("AGITATE NOW!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    Spacer()
                }
            } else if context.state.agitationCountdown > 0 {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                    Text("Agitation in \(context.state.formattedAgitationCountdown)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
    }
    
    private var timerColor: Color {
        if context.state.remainingTime < 10 {
            return .red
        } else if context.state.remainingTime < 30 {
            return .orange
        }
        return .primary
    }
}

// MARK: - Dynamic Island Views

@available(iOS 16.1, *)
struct DarkroomTimerExpandedLeading: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: context.attributes.sessionType.icon)
                .font(.title2)
                .foregroundColor(context.attributes.sessionType.color)
            Text(context.state.currentPhase)
                .font(.caption)
        }
    }
}

@available(iOS 16.1, *)
struct DarkroomTimerExpandedTrailing: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        VStack(alignment: .trailing) {
            Text(context.state.formattedRemainingTime)
                .font(.title2)
                .fontWeight(.bold)
            Text("remaining")
                .font(.caption)
        }
    }
}

@available(iOS 16.1, *)
struct DarkroomTimerExpandedCenter: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        ProgressView(value: context.state.progress)
            .tint(context.attributes.sessionType.color)
    }
}

@available(iOS 16.1, *)
struct DarkroomTimerExpandedBottom: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        HStack {
            if context.state.isAgitationRequired {
                Label("AGITATE", systemImage: "arrow.2.circlepath")
                    .font(.caption)
                    .foregroundColor(.yellow)
            } else {
                Text("Phase \(context.state.currentPhaseIndex + 1) of \(context.attributes.totalPhases)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

@available(iOS 16.1, *)
struct DarkroomTimerCompactLeading: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        Image(systemName: context.attributes.sessionType.icon)
            .foregroundColor(context.attributes.sessionType.color)
    }
}

@available(iOS 16.1, *)
struct DarkroomTimerCompactTrailing: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        Text(context.state.formattedRemainingTime)
            .font(.caption)
            .fontWeight(.bold)
    }
}

@available(iOS 16.1, *)
struct DarkroomTimerMinimal: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        Image(systemName: context.attributes.sessionType.icon)
            .foregroundColor(context.attributes.sessionType.color)
    }
}

// MARK: - Legacy Support (iOS < 16.1)

/// Fallback manager for devices without Live Activity support
class LegacyLiveActivityManager: ObservableObject {
    static let shared = LegacyLiveActivityManager()
    
    func startActivity(sessionType: SessionType, currentPhase: String, totalPhases: Int, currentPhaseIndex: Int, totalDuration: TimeInterval, remainingTime: TimeInterval) {
        // Use local notifications instead
        print("Legacy: Would start notification for \(sessionType.rawValue)")
    }
    
    func updateActivity(currentPhase: String, currentPhaseIndex: Int, remainingTime: TimeInterval, progress: Double, isAgitationRequired: Bool = false, agitationCountdown: TimeInterval = 0) {
        print("Legacy: Would update notification")
    }
    
    func endActivity() {
        print("Legacy: Would end notification")
    }
}

// MARK: - Unified Activity Manager

/// Unified interface that works on all iOS versions
@MainActor
final class UnifiedLiveActivityManager: ObservableObject {
    static let shared = UnifiedLiveActivityManager()
    
    @Published var isActivityActive: Bool = false
    
    private init() {}
    
    func startActivity(
        sessionType: SessionType,
        currentPhase: String,
        totalPhases: Int,
        currentPhaseIndex: Int,
        totalDuration: TimeInterval,
        remainingTime: TimeInterval
    ) {
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.startActivity(
                sessionType: sessionType,
                currentPhase: currentPhase,
                totalPhases: totalPhases,
                currentPhaseIndex: currentPhaseIndex,
                totalDuration: totalDuration,
                remainingTime: remainingTime
            )
            isActivityActive = LiveActivityManager.shared.isActivityActive
        } else {
            LegacyLiveActivityManager.shared.startActivity(
                sessionType: sessionType,
                currentPhase: currentPhase,
                totalPhases: totalPhases,
                currentPhaseIndex: currentPhaseIndex,
                totalDuration: totalDuration,
                remainingTime: remainingTime
            )
        }
    }
    
    func updateActivity(
        currentPhase: String,
        currentPhaseIndex: Int,
        remainingTime: TimeInterval,
        progress: Double,
        isAgitationRequired: Bool = false,
        agitationCountdown: TimeInterval = 0
    ) {
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.updateActivity(
                currentPhase: currentPhase,
                currentPhaseIndex: currentPhaseIndex,
                remainingTime: remainingTime,
                progress: progress,
                isAgitationRequired: isAgitationRequired,
                agitationCountdown: agitationCountdown
            )
        } else {
            LegacyLiveActivityManager.shared.updateActivity(
                currentPhase: currentPhase,
                currentPhaseIndex: currentPhaseIndex,
                remainingTime: remainingTime,
                progress: progress,
                isAgitationRequired: isAgitationRequired,
                agitationCountdown: agitationCountdown
            )
        }
    }
    
    func endActivity() {
        if #available(iOS 16.1, *) {
            LiveActivityManager.shared.endActivity()
            isActivityActive = LiveActivityManager.shared.isActivityActive
        } else {
            LegacyLiveActivityManager.shared.endActivity()
        }
    }
}
