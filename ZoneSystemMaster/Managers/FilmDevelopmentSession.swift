import Foundation
import Combine
import SwiftData

// MARK: - Film Development Session

/// Manages a complete film development session with all phases
/// Follows Ansel Adams' standard darkroom procedures
@MainActor
final class FilmDevelopmentSession: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var timerManager: DarkroomTimerManager
    @Published var recipe: DeveloperRecipe?
    @Published var filmName: String = ""
    @Published var iso: Int = 400
    @Published var actualTemperature: Double = 20.0
    @Published var notes: String = ""
    @Published var sessionHistory: DevelopmentSession?
    
    // Development settings
    @Published var useStopBath: Bool = true
    @Published var useHardener: Bool = false
    @Published var washTimeMinutes: Int = 15
    @Published var stopBathTimeSeconds: Int = 30
    @Published var fixerTimeMinutes: Int = 5
    
    // Session state
    @Published var isConfigured: Bool = false
    @Published var canStart: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    
    // MARK: - Computed Properties
    
    var totalEstimatedTime: TimeInterval {
        let devTime = Double(recipe?.adjustedTimeSeconds ?? 0)
        let stopTime = useStopBath ? Double(stopBathTimeSeconds) : 0
        let fixTime = Double(fixerTimeMinutes * 60)
        let washTime = Double(washTimeMinutes * 60)
        return devTime + stopTime + fixTime + washTime
    }
    
    var formattedTotalTime: String {
        let minutes = Int(totalEstimatedTime) / 60
        let seconds = Int(totalEstimatedTime) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var currentPhaseName: String {
        timerManager.currentPhase?.name ?? "Ready"
    }
    
    var isRunning: Bool {
        timerManager.state.isRunning
    }
    
    var isPaused: Bool {
        timerManager.state.isPaused
    }
    
    var isCompleted: Bool {
        if case .completed = timerManager.state { return true }
        return false
    }
    
    var progress: Double {
        timerManager.sessionProgress
    }
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext? = nil) {
        self.timerManager = DarkroomTimerManager()
        self.modelContext = modelContext
        
        setupSubscriptions()
    }
    
    // MARK: - Setup
    
    private func setupSubscriptions() {
        timerManager.$state
            .sink { [weak self] state in
                if case .completed = state {
                    self?.saveSessionHistory(success: true)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Configuration
    
    func configure(with recipe: DeveloperRecipe, context: ModelContext? = nil) {
        self.recipe = recipe
        self.filmName = recipe.filmName
        self.iso = recipe.iso
        self.actualTemperature = recipe.temperatureCelsius
        self.modelContext = context
        
        // Adjust times based on temperature if needed
        let adjustedDevTime = calculateAdjustedTime(
            baseTime: recipe.adjustedTimeSeconds,
            targetTemp: recipe.temperatureCelsius,
            actualTemp: actualTemperature
        )
        
        // Build phases
        let phases = buildPhases(developmentTime: adjustedDevTime)
        
        // Setup agitation scheduler
        let agitationSchedule = recipe.agitationStyle.agitationSchedule
        
        timerManager.setupPhases(phases, agitationScheduler: agitationSchedule)
        
        isConfigured = true
        canStart = true
    }
    
    func configureCustom(
        filmName: String,
        iso: Int,
        developerName: DeveloperType,
        developmentTimeSeconds: Int,
        temperature: Double = 20.0,
        agitationStyle: AgitationStyle = .standard,
        useStopBath: Bool = true,
        stopBathSeconds: Int = 30,
        fixerMinutes: Int = 5,
        washMinutes: Int = 15,
        context: ModelContext? = nil
    ) {
        self.filmName = filmName
        self.iso = iso
        self.actualTemperature = temperature
        self.useStopBath = useStopBath
        self.stopBathTimeSeconds = stopBathSeconds
        self.fixerTimeMinutes = fixerMinutes
        self.washTimeMinutes = washMinutes
        self.modelContext = context
        
        let phases = buildPhases(developmentTime: developmentTimeSeconds)
        let agitationSchedule = agitationStyle.agitationSchedule
        
        timerManager.setupPhases(phases, agitationScheduler: agitationSchedule)
        
        isConfigured = true
        canStart = true
    }
    
    // MARK: - Phase Building
    
    private func buildPhases(developmentTime: Int) -> [TimerPhase] {
        var phases: [TimerPhase] = []
        
        // 1. Developer Phase
        let devPhase = TimerPhase(
            name: "Developer",
            duration: TimeInterval(developmentTime),
            type: .developer,
            description: recipe.map { "\($0.developerName.rawValue) \($0.dilution.rawValue)" } ?? "Development"
        )
        phases.append(devPhase)
        
        // 2. Stop Bath Phase (optional)
        if useStopBath {
            let stopPhase = TimerPhase(
                name: "Stop Bath",
                duration: TimeInterval(stopBathTimeSeconds),
                type: .stopBath,
                description: "Stop development immediately"
            )
            phases.append(stopPhase)
        }
        
        // 3. Fixer Phase
        let fixPhase = TimerPhase(
            name: "Fixer",
            duration: TimeInterval(fixerTimeMinutes * 60),
            type: .fixer,
            description: "Rapid fixer or standard fixer"
        )
        phases.append(fixPhase)
        
        // 4. Optional Hardening Bath
        if useHardener {
            let hardenerPhase = TimerPhase(
                name: "Hardening Bath",
                duration: TimeInterval(120),
                type: .hardener,
                description: "Optional hardening treatment",
                isOptional: true
            )
            phases.append(hardenerPhase)
        }
        
        // 5. Wash Phase
        let washPhase = TimerPhase(
            name: "Final Wash",
            duration: TimeInterval(washTimeMinutes * 60),
            type: .wash,
            description: "Running water wash"
        )
        phases.append(washPhase)
        
        return phases
    }
    
    // MARK: - Temperature Adjustment
    
    /// Adjusts development time based on temperature difference
    /// Uses the rule of thumb: ±1°C = ±10% time adjustment
    private func calculateAdjustedTime(baseTime: Int, targetTemp: Double, actualTemp: Double) -> Int {
        let tempDifference = actualTemp - targetTemp
        let adjustmentFactor = 1.0 + (tempDifference * 0.1)
        return Int(Double(baseTime) * adjustmentFactor)
    }
    
    // MARK: - Session Control
    
    func start() {
        guard canStart else { return }
        
        // Create session history record
        sessionHistory = DevelopmentSession(
            recipeID: recipe?.id,
            filmName: filmName,
            developerName: recipe?.developerName.rawValue ?? "Custom",
            temperatureActual: actualTemperature
        )
        
        timerManager.start()
    }
    
    func pause() {
        timerManager.pause()
    }
    
    func resume() {
        timerManager.start() // Will resume from paused state
    }
    
    func stop() {
        timerManager.stop()
        saveSessionHistory(success: false)
    }
    
    func reset() {
        timerManager.reset()
        sessionHistory = nil
        isConfigured = false
        canStart = false
    }
    
    func skipToNextPhase() {
        timerManager.skipToNextPhase()
    }
    
    func acknowledgeAgitation() {
        timerManager.acknowledgeAgitation()
    }
    
    // MARK: - History
    
    private func saveSessionHistory(success: Bool) {
        guard var session = sessionHistory else { return }
        
        session.completedAt = Date()
        session.wasSuccessful = success
        session.notes = notes
        
        if let context = modelContext {
            context.insert(session)
            try? context.save()
        }
    }
    
    // MARK: - Quick Start Presets
    
    static func quickStartHP5PlusD76() -> FilmDevelopmentSession {
        let session = FilmDevelopmentSession()
        let recipe = DeveloperRecipe(
            name: "HP5+ in D-76",
            developerName: .d76,
            filmName: "Ilford HP5+",
            iso: 400,
            dilution: .stock,
            baseTimeSeconds: 480, // 8 minutes at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Standard development for HP5+"
        )
        session.configure(with: recipe)
        return session
    }
    
    static func quickStartTriXHC110() -> FilmDevelopmentSession {
        let session = FilmDevelopmentSession()
        let recipe = DeveloperRecipe(
            name: "Tri-X in HC-110",
            developerName: .hc110DilB,
            filmName: "Kodak Tri-X",
            iso: 400,
            dilution: .dilutionB,
            baseTimeSeconds: 300, // 5 minutes at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Classic Tri-X look"
        )
        session.configure(with: recipe)
        return session
    }
    
    static func quickStartDelta3200() -> FilmDevelopmentSession {
        let session = FilmDevelopmentSession()
        let recipe = DeveloperRecipe(
            name: "Delta 3200 in Microphen",
            developerName: .microphen,
            filmName: "Ilford Delta 3200",
            iso: 3200,
            dilution: .stock,
            baseTimeSeconds: 540, // 9 minutes at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Push processing for high speed"
        )
        session.configure(with: recipe)
        return session
    }
}

// MARK: - Development Session Extensions

extension FilmDevelopmentSession {
    
    /// Returns a summary of the current session
    var sessionSummary: String {
        let phaseInfo = timerManager.phases.enumerated().map { index, phase in
            let status = index < timerManager.currentPhaseIndex ? "✓" :
                        index == timerManager.currentPhaseIndex ? "▶" : "○"
            return "\(status) \(phase.name)"
        }.joined(separator: "\n")
        
        return """
        Film: \(filmName) @ ISO \(iso)
        Developer: \(recipe?.developerName.rawValue ?? "Custom")
        Temperature: \(String(format: "%.1f", actualTemperature))°C
        
        Phases:
        \(phaseInfo)
        """
    }
    
    /// Estimated completion time
    var estimatedCompletionTime: Date? {
        guard let startTime = timerManager.sessionStartTime else { return nil }
        return startTime.addingTimeInterval(totalEstimatedTime)
    }
    
    var formattedCompletionTime: String {
        guard let completionTime = estimatedCompletionTime else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: completionTime)
    }
}
