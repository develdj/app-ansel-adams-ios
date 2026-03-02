import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct ZoneSystemMasterWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            ZoneSystemMasterLiveActivityWidget()
        }
    }
}

// MARK: - Live Activity Widget

@available(iOS 16.1, *)
struct ZoneSystemMasterLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DarkroomTimerAttributes.self) { context in
            // Lock Screen / Notification Center view
            ZoneSystemMasterLockScreenView(context: context)
                .containerBackground(for: .widget) {
                    Color.black
                }
        } dynamicIsland: { context in
            // Dynamic Island view
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct ZoneSystemMasterLockScreenView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: context.attributes.sessionType.icon)
                    .foregroundColor(context.attributes.sessionType.color)
                    .font(.title3)
                
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
            
            // Timer
            HStack {
                Text(context.state.formattedRemainingTime)
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
                    .minimumScaleFactor(0.5)
                Spacer()
            }
            
            // Progress
            ProgressView(value: context.state.progress)
                .tint(context.attributes.sessionType.color)
                .scaleEffect(y: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Agitation Alert
            if context.state.isAgitationRequired {
                HStack {
                    Image(systemName: "arrow.2.circlepath")
                        .foregroundColor(.yellow)
                        .symbolEffect(.pulse)
                    
                    Text("AGITATE NOW!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)
            } else if context.state.agitationCountdown > 0 {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                    
                    Text("Agitation in \(context.state.formattedAgitationCountdown)")
                        .font(.subheadline)
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

// MARK: - Dynamic Island Expanded Views

@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: context.attributes.sessionType.icon)
                .font(.title2)
                .foregroundColor(context.attributes.sessionType.color)
            
            Text(context.state.currentPhase)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(context.state.formattedRemainingTime)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
            
            Text("remaining")
                .font(.caption)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        ProgressView(value: context.state.progress)
            .tint(context.attributes.sessionType.color)
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        HStack {
            if context.state.isAgitationRequired {
                Label("AGITATE", systemImage: "arrow.2.circlepath")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
                    .symbolEffect(.pulse)
            } else {
                Text("Phase \(context.state.currentPhaseIndex + 1) of \(context.attributes.totalPhases)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Compact Views

@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        Image(systemName: context.attributes.sessionType.icon)
            .foregroundColor(context.attributes.sessionType.color)
    }
}

@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        Text(context.state.formattedRemainingTime)
            .font(.caption)
            .fontWeight(.bold)
            .monospacedDigit()
    }
}

@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<DarkroomTimerAttributes>
    
    var body: some View {
        Image(systemName: context.attributes.sessionType.icon)
            .foregroundColor(context.attributes.sessionType.color)
    }
}

// MARK: - Preview Provider

@available(iOS 16.1, *)
#Preview("Live Activity", as: .content, using: DarkroomTimerAttributes.preview) {
    ZoneSystemMasterLiveActivityWidget()
} contentStates: {
    DarkroomTimerAttributes.ContentState.development
    DarkroomTimerAttributes.ContentState.agitation
    DarkroomTimerAttributes.ContentState.completion
}

// MARK: - Preview Data

@available(iOS 16.1, *)
extension DarkroomTimerAttributes {
    static var preview: DarkroomTimerAttributes {
        DarkroomTimerAttributes(
            sessionType: .filmDevelopment,
            totalPhases: 4,
            totalDuration: 1800
        )
    }
}

@available(iOS 16.1, *)
extension DarkroomTimerAttributes.ContentState {
    static var development: DarkroomTimerAttributes.ContentState {
        DarkroomTimerAttributes.ContentState(
            currentPhase: "Developer",
            currentPhaseIndex: 0,
            remainingTime: 420,
            progress: 0.3,
            isAgitationRequired: false,
            agitationCountdown: 45
        )
    }
    
    static var agitation: DarkroomTimerAttributes.ContentState {
        DarkroomTimerAttributes.ContentState(
            currentPhase: "Developer",
            currentPhaseIndex: 0,
            remainingTime: 380,
            progress: 0.4,
            isAgitationRequired: true,
            agitationCountdown: 0
        )
    }
    
    static var completion: DarkroomTimerAttributes.ContentState {
        DarkroomTimerAttributes.ContentState(
            currentPhase: "Complete",
            currentPhaseIndex: 3,
            remainingTime: 0,
            progress: 1.0,
            isAgitationRequired: false,
            agitationCountdown: 0
        )
    }
}
