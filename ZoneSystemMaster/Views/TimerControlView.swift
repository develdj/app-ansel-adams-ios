import SwiftUI
import Combine

// MARK: - Timer Control View

/// Main view for controlling darkroom timer
/// Shows current phase, countdown, and controls
struct TimerControlView: View {
    @StateObject var session: FilmDevelopmentSession
    @StateObject private var liveActivity = UnifiedLiveActivityManager.shared
    
    @State private var showCancelConfirmation = false
    @State private var showPhaseSkipConfirmation = false
    @State private var showAgitationGuide = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            ScrollView {
                VStack(spacing: 24) {
                    // Main Timer Display
                    timerDisplay
                    
                    // Progress Section
                    progressSection
                    
                    // Agitation Alert
                    if session.timerManager.isAgitationRequired {
                        agitationAlertView
                    }
                    
                    // Phase List
                    phaseListView
                    
                    // Session Info
                    sessionInfoView
                }
                .padding()
            }
            
            // Control Buttons
            controlButtons
        }
        .background(Color(.systemBackground))
        .navigationTitle("Development Timer")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Cancel Session?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Session", role: .destructive) {
                session.stop()
            }
            Button("Continue", role: .cancel) {}
        } message: {
            Text("This will stop the current development session. Are you sure?")
        }
        .sheet(isPresented: $showAgitationGuide) {
            AgitationGuideView(
                style: session.recipe?.agitationStyle ?? .standard,
                isPresented: $showAgitationGuide
            )
        }
        .onAppear {
            setupLiveActivity()
        }
        .onDisappear {
            // Keep timer running in background
        }
        .onChange(of: session.timerManager.state) { _, newState in
            updateLiveActivity()
        }
        .onChange(of: session.timerManager.remainingTime) { _, _ in
            updateLiveActivity()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.currentPhaseName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Phase \(session.timerManager.currentPhaseIndex + 1) of \(session.timerManager.phases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Connection status
            HStack(spacing: 4) {
                Image(systemName: "iphone")
                Image(systemName: "applewatch")
                    .foregroundColor(WatchConnectivityManager.shared.isWatchConnected ? .green : .gray)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        VStack(spacing: 16) {
            // Main countdown
            Text(session.timerManager.formattedRemainingTime)
                .font(.system(size: 80, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)
                .minimumScaleFactor(0.5)
            
            // Elapsed time
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.secondary)
                Text("Elapsed: \(session.timerManager.formattedElapsedTime)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Completion time estimate
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .foregroundColor(.secondary)
                Text("Done at: \(session.formattedCompletionTime)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
    }
    
    private var timerColor: Color {
        let remaining = session.timerManager.remainingTime
        if remaining < 10 {
            return .red
        } else if remaining < 30 {
            return .orange
        }
        return .primary
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Phase progress
            ProgressView(value: session.timerManager.progress)
                .tint(phaseColor)
                .scaleEffect(y: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            HStack {
                Text("Phase Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(session.timerManager.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Session progress
            ProgressView(value: session.progress)
                .tint(.blue)
                .scaleEffect(y: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            
            HStack {
                Text("Session Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(session.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var phaseColor: Color {
        guard let phase = session.timerManager.currentPhase else { return .blue }
        return phase.type.color
    }
    
    // MARK: - Agitation Alert View
    
    private var agitationAlertView: some View {
        Button(action: {
            session.acknowledgeAgitation()
        }) {
            HStack(spacing: 16) {
                Image(systemName: "arrow.2.circlepath")
                    .font(.largeTitle)
                    .symbolEffect(.pulse)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AGITATE NOW!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tap to acknowledge")
                        .font(.caption)
                        .foregroundColor(.yellow.opacity(0.8))
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.yellow.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.yellow, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Phase List View
    
    private var phaseListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Development Phases")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(Array(session.timerManager.phases.enumerated()), id: \.element.id) { index, phase in
                    PhaseRow(
                        phase: phase,
                        index: index,
                        isCurrent: index == session.timerManager.currentPhaseIndex,
                        isCompleted: index < session.timerManager.currentPhaseIndex
                    )
                }
            }
        }
    }
    
    // MARK: - Session Info View
    
    private var sessionInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Film", value: session.filmName)
                InfoRow(label: "ISO", value: "\(session.iso)")
                InfoRow(label: "Developer", value: session.recipe?.developerName.rawValue ?? "Custom")
                InfoRow(label: "Dilution", value: session.recipe?.dilution.rawValue ?? "-")
                InfoRow(label: "Temperature", value: String(format: "%.1f°C", session.actualTemperature))
                InfoRow(label: "Zone System", value: session.recipe?.zoneSystem.rawValue ?? "N")
                InfoRow(label: "Total Time", value: session.formattedTotalTime)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Play/Pause Button
                Button(action: {
                    if session.isRunning {
                        session.pause()
                    } else if session.isPaused {
                        session.resume()
                    } else {
                        session.start()
                    }
                }) {
                    Image(systemName: session.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(session.isRunning ? .orange : .green)
                }
                
                // Stop Button
                Button(action: {
                    showCancelConfirmation = true
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }
                .disabled(!session.isRunning && !session.isPaused)
                .opacity((!session.isRunning && !session.isPaused) ? 0.5 : 1)
            }
            
            HStack(spacing: 16) {
                // Previous Phase
                Button(action: {
                    session.timerManager.skipToPreviousPhase()
                }) {
                    Label("Previous", systemImage: "backward.fill")
                        .font(.subheadline)
                }
                .disabled(session.timerManager.currentPhaseIndex == 0)
                
                // Agitation Guide
                Button(action: {
                    showAgitationGuide = true
                }) {
                    Label("Agitation", systemImage: "arrow.2.circlepath")
                        .font(.subheadline)
                }
                
                // Next Phase
                Button(action: {
                    showPhaseSkipConfirmation = true
                }) {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.subheadline)
                }
                .disabled(session.timerManager.isLastPhase)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .confirmationDialog(
            "Skip Phase?",
            isPresented: $showPhaseSkipConfirmation
        ) {
            Button("Skip to Next Phase") {
                session.skipToNextPhase()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Live Activity
    
    private func setupLiveActivity() {
        guard session.isRunning || session.isPaused else { return }
        
        liveActivity.startActivity(
            sessionType: .filmDevelopment,
            currentPhase: session.currentPhaseName,
            totalPhases: session.timerManager.phases.count,
            currentPhaseIndex: session.timerManager.currentPhaseIndex,
            totalDuration: session.totalEstimatedTime,
            remainingTime: session.timerManager.remainingTime
        )
    }
    
    private func updateLiveActivity() {
        liveActivity.updateActivity(
            currentPhase: session.currentPhaseName,
            currentPhaseIndex: session.timerManager.currentPhaseIndex,
            remainingTime: session.timerManager.remainingTime,
            progress: session.timerManager.progress,
            isAgitationRequired: session.timerManager.isAgitationRequired,
            agitationCountdown: session.timerManager.agitationCountdown
        )
        
        if session.isCompleted {
            liveActivity.endActivity()
        }
    }
}

// MARK: - Phase Row

struct PhaseRow: View {
    let phase: TimerPhase
    let index: Int
    let isCurrent: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 28, height: 28)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                } else if isCurrent {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            
            // Phase info
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.name)
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .semibold : .regular)
                
                if let description = phase.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(phase.duration))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrent ? phase.type.color.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrent ? phase.type.color : Color.clear, lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return phase.type.color
        }
        return Color(.systemGray5)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Agitation Guide View

struct AgitationGuideView: View {
    let style: AgitationStyle
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding()
                
                // Title
                Text(style.rawValue)
                    .font(.title)
                    .fontWeight(.bold)
                
                // Description
                Text(style.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Schedule details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Schedule")
                        .font(.headline)
                    
                    let schedule = style.agitationSchedule
                    
                    if let initial = schedule.initialContinuousSeconds {
                        HStack {
                            Image(systemName: "1.circle.fill")
                            Text("Initial: \(initial) seconds continuous")
                        }
                        
                        HStack {
                            Image(systemName: "2.circle.fill")
                            Text("Then: Every minute for \(schedule.durationPerAgitation)s")
                        }
                    } else {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Continuous throughout development")
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
            }
            .padding()
            .navigationTitle("Agitation Guide")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TimerControlView(session: FilmDevelopmentSession.quickStartHP5PlusD76())
    }
}
