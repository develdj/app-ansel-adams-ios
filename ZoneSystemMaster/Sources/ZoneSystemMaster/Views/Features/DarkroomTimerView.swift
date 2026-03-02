import SwiftUI
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Darkroom Timer View

@MainActor
struct DarkroomTimerView: View {
    
    @State private var viewModel = DarkroomTimerViewModel()
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Darkroom safe background when timer is running
                if viewModel.isRunning {
                    LiquidGlassTheme.Colors.darkroomRed
                        .opacity(0.1)
                        .ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(spacing: LiquidGlassTheme.Spacing.xl) {
                        // Timer Display
                        TimerDisplayCard(viewModel: viewModel)
                        
                        // Phase Selection
                        PhaseSelectionView(
                            phases: viewModel.phases,
                            currentPhase: viewModel.currentPhase,
                            onSelect: { phase in
                                viewModel.selectPhase(phase)
                            }
                        )
                        
                        // Film & Developer Selection
                        FilmDeveloperPanel(viewModel: viewModel)
                        
                        // Control Buttons
                        ControlButtons(viewModel: viewModel)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Darkroom Timer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                TimerSettingsSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Timer Display Card

struct TimerDisplayCard: View {
    @Bindable var viewModel: DarkroomTimerViewModel
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.lg) {
            // Phase indicator
            if let phase = viewModel.currentPhase {
                HStack {
                    Image(systemName: phase.icon)
                    Text(phase.rawValue)
                }
                .font(LiquidGlassTheme.Typography.title2)
                .foregroundColor(Color(hex: phase.color))
            } else {
                Text("Ready")
                    .font(LiquidGlassTheme.Typography.title2)
                    .foregroundColor(.secondary)
            }
            
            // Timer display
            Text(formattedTime(viewModel.remainingTime))
                .font(.system(size: 80, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(viewModel.isRunning ? .primary : .secondary)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LiquidGlassTheme.Colors.glassThin)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(viewModel.currentPhase.map { Color(hex: $0.color) } ?? LiquidGlassTheme.Colors.primary)
                        .frame(width: progressWidth(in: geometry), height: 8)
                        .animation(.linear(duration: 0.1), value: viewModel.remainingTime)
                }
            }
            .frame(height: 8)
            
            // Total time
            if viewModel.totalTime > 0 {
                Text("of \(formattedTime(viewModel.totalTime))")
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .liquidGlassCard()
        .padding(.horizontal)
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
    
    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        guard viewModel.totalTime > 0 else { return 0 }
        let progress = 1.0 - (viewModel.remainingTime / viewModel.totalTime)
        return geometry.size.width * CGFloat(progress)
    }
}

// MARK: - Phase Selection View

struct PhaseSelectionView: View {
    let phases: [TimerPhase]
    let currentPhase: DarkroomPhase?
    let onSelect: (DarkroomPhase) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.md) {
            Text("Phases")
                .font(LiquidGlassTheme.Typography.body.weight(.medium))
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LiquidGlassTheme.Spacing.sm) {
                    ForEach(phases) { phase in
                        PhaseButton(
                            phase: phase,
                            isSelected: currentPhase == phase.phase,
                            isCompleted: phase.isCompleted
                        ) {
                            onSelect(phase.phase)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Phase Button

struct PhaseButton: View {
    let phase: TimerPhase
    let isSelected: Bool
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: LiquidGlassTheme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : Color(hex: phase.phase.color).opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: phase.phase.icon)
                            .foregroundColor(Color(hex: phase.phase.color))
                    }
                }
                
                Text(phase.phase.rawValue)
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.vertical, LiquidGlassTheme.Spacing.xs)
            .padding(.horizontal, LiquidGlassTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md)
                    .fill(isSelected ? LiquidGlassTheme.Colors.glassRegular : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Film & Developer Panel

struct FilmDeveloperPanel: View {
    @Bindable var viewModel: DarkroomTimerViewModel
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.md) {
            // Film selection
            HStack {
                Text("Film")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                Spacer()
                
                Picker("Film", selection: $viewModel.selectedFilm) {
                    ForEach(FilmEmulsion.allCases) { film in
                        Text(film.rawValue).tag(film)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // Developer selection
            HStack {
                Text("Developer")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                Spacer()
                
                Picker("Developer", selection: $viewModel.selectedDeveloper) {
                    ForEach(DeveloperType.allCases) { dev in
                        Text(dev.rawValue).tag(dev)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // Temperature
            HStack {
                Text("Temperature")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(Int(viewModel.temperature))°C")
                        .font(LiquidGlassTheme.Typography.mono)
                    
                    Stepper("", value: $viewModel.temperature, in: 15...30, step: 0.5)
                        .labelsHidden()
                }
            }
            
            // Recommended times button
            Button {
                viewModel.loadRecommendedTimes()
            } label: {
                Label("Load Recommended Times", systemImage: "arrow.clockwise")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, LiquidGlassTheme.Spacing.sm)
        }
        .padding()
        .liquidGlassCard()
        .padding(.horizontal)
    }
}

// MARK: - Control Buttons

struct ControlButtons: View {
    @Bindable var viewModel: DarkroomTimerViewModel
    
    var body: some View {
        HStack(spacing: LiquidGlassTheme.Spacing.md) {
            // Reset button
            Button {
                viewModel.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2)
                    .frame(width: 60, height: 60)
                    .background(LiquidGlassTheme.Colors.glassRegular)
                    .foregroundColor(.primary)
                    .clipShape(Circle())
            }
            
            // Play/Pause button
            Button {
                viewModel.toggleTimer()
            } label: {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .frame(width: 80, height: 80)
                    .background(viewModel.isRunning ? LiquidGlassTheme.Colors.warning : LiquidGlassTheme.Colors.success)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(color: (viewModel.isRunning ? LiquidGlassTheme.Colors.warning : LiquidGlassTheme.Colors.success).opacity(0.4), radius: 12)
            }
            
            // Skip button
            Button {
                viewModel.skipToNextPhase()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
                    .background(LiquidGlassTheme.Colors.glassRegular)
                    .foregroundColor(.primary)
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Timer Settings Sheet

struct TimerSettingsSheet: View {
    @Bindable var viewModel: DarkroomTimerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sound") {
                    Toggle("Enable Sounds", isOn: $viewModel.soundEnabled)
                    Toggle("Voice Announcements", isOn: $viewModel.voiceEnabled)
                }
                
                Section("Notifications") {
                    Toggle("Phase Complete Alert", isOn: $viewModel.phaseCompleteAlert)
                    Toggle("Background Timer", isOn: $viewModel.backgroundTimer)
                }
                
                Section("Display") {
                    Toggle("Darkroom Safe Mode", isOn: $viewModel.darkroomSafeMode)
                    Picker("Safe Color", selection: $viewModel.safeColor) {
                        ForEach(DarkroomSafeColor.allCases, id: \.self) { color in
                            Text(color.rawValue).tag(color)
                        }
                    }
                }
                
                Section("Custom Times") {
                    ForEach(DarkroomPhase.allCases) { phase in
                        HStack {
                            Text(phase.rawValue)
                            Spacer()
                            Text(formattedTime(viewModel.customTime(for: phase)))
                                .font(LiquidGlassTheme.Typography.mono)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Timer Phase Model

struct TimerPhase: Identifiable, Equatable {
    let id = UUID()
    let phase: DarkroomPhase
    var duration: TimeInterval
    var isCompleted: Bool
}

// MARK: - View Model

@Observable
@MainActor
final class DarkroomTimerViewModel {
    
    var phases: [TimerPhase] = DarkroomPhase.allCases.map { TimerPhase(phase: $0, duration: 0, isCompleted: false) }
    var currentPhase: DarkroomPhase?
    var remainingTime: TimeInterval = 0
    var totalTime: TimeInterval = 0
    var isRunning = false
    var showSettings = false
    
    var selectedFilm: FilmEmulsion = .ilfordHP5
    var selectedDeveloper: DeveloperType = .ilfordID11
    var temperature: Double = 20.0
    
    var soundEnabled = true
    var voiceEnabled = false
    var phaseCompleteAlert = true
    var backgroundTimer = true
    var darkroomSafeMode = false
    var safeColor: DarkroomSafeColor = .red
    
    private var timer: Timer?
    private var customTimes: [DarkroomPhase: TimeInterval] = [:]
    
    @ObservationIgnored
    @Inject(\.darkroomTimer) private var darkroomTimer
    
    func selectPhase(_ phase: DarkroomPhase) {
        guard !isRunning else { return }
        currentPhase = phase
        
        if let timerPhase = phases.first(where: { $0.phase == phase }) {
            remainingTime = timerPhase.duration
            totalTime = timerPhase.duration
        }
    }
    
    func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }
    
    func startTimer() {
        guard let phase = currentPhase else { return }
        
        isRunning = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        pauseTimer()
        currentPhase = nil
        remainingTime = 0
        totalTime = 0
        phases = phases.map { TimerPhase(phase: $0.phase, duration: $0.duration, isCompleted: false) }
    }
    
    func skipToNextPhase() {
        pauseTimer()
        
        guard let current = currentPhase,
              let currentIndex = phases.firstIndex(where: { $0.phase == current }),
              currentIndex < phases.count - 1 else {
            return
        }
        
        // Mark current as completed
        phases[currentIndex].isCompleted = true
        
        // Move to next
        let nextPhase = phases[currentIndex + 1]
        selectPhase(nextPhase.phase)
    }
    
    func loadRecommendedTimes() {
        Task {
            let times = await darkroomTimer.recommendedTimes(
                film: selectedFilm,
                developer: selectedDeveloper,
                iso: selectedFilm.iso,
                temperature: temperature
            )
            
            await MainActor.run {
                phases = [
                    TimerPhase(phase: .development, duration: times.development, isCompleted: false),
                    TimerPhase(phase: .stopBath, duration: times.stopBath, isCompleted: false),
                    TimerPhase(phase: .fixer, duration: times.fixer, isCompleted: false),
                    TimerPhase(phase: .wash, duration: times.wash, isCompleted: false),
                    TimerPhase(phase: .hypoClear, duration: times.hypoClear, isCompleted: false),
                    TimerPhase(phase: .finalWash, duration: times.finalWash, isCompleted: false)
                ]
            }
        }
    }
    
    func customTime(for phase: DarkroomPhase) -> TimeInterval {
        customTimes[phase] ?? 0
    }
    
    private func updateTimer() {
        remainingTime -= 0.1
        
        if remainingTime <= 0 {
            timerComplete()
        }
    }
    
    private func timerComplete() {
        pauseTimer()
        remainingTime = 0
        
        // Mark current phase as completed
        if let current = currentPhase,
           let index = phases.firstIndex(where: { $0.phase == current }) {
            phases[index].isCompleted = true
        }
        
        // Play completion sound
        if soundEnabled {
            // AudioServicesPlaySystemSound(1005) // System sound
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Preview

#Preview {
    DarkroomTimerView()
        .environment(DependencyContainer.preview())
}
