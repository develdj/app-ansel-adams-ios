import Foundation
import Combine
import SwiftData

// MARK: - Print Timer Session

/// Manages a complete darkroom printing session
/// Includes exposure timing, test strips, and split grade printing
@MainActor
final class PrintSession: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var timerManager: DarkroomTimerManager
    @Published var printRecipe: PrintRecipe?
    @Published var paperType: PaperType = .rcGlossy
    @Published var enlargerHeight: Double = 30.0 // cm
    @Published var aperture: String = "f/8"
    @Published var filterGrade: Int = 2 // 0-5 for multigrade
    @Published var notes: String = ""
    
    // Exposure settings
    @Published var baseExposureSeconds: Double = 10.0
    @Published var burnDodgeTimes: [BurnDodgeZone] = []
    
    // Split grade settings
    @Published var useSplitGrade: Bool = false
    @Published var lowContrastExposure: Double = 5.0
    @Published var highContrastExposure: Double = 5.0
    
    // Test strip settings
    @Published var testStripStepCount: Int = 5
    @Published var testStripStepSize: Double = 2.0 // seconds increment
    @Published var testStripResults: [TestStripStep] = []
    
    // Session state
    @Published var isConfigured: Bool = false
    @Published var currentMode: PrintMode = .fullPrint
    
    enum PrintMode {
        case testStrip
        case fullPrint
        case splitGrade
        case burningDodging
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?
    
    // MARK: - Computed Properties
    
    var totalExposureTime: Double {
        if useSplitGrade {
            return lowContrastExposure + highContrastExposure
        }
        return baseExposureSeconds + burnDodgeTimes.reduce(0) { $0 + $1.duration }
    }
    
    var formattedTotalExposure: String {
        String(format: "%.1f s", totalExposureTime)
    }
    
    var isRunning: Bool {
        timerManager.state.isRunning
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
                    self?.handleSessionComplete()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Configuration
    
    func configureForFullPrint(
        recipe: PrintRecipe,
        exposureSeconds: Double,
        filterGrade: Int = 2,
        context: ModelContext? = nil
    ) {
        self.printRecipe = recipe
        self.baseExposureSeconds = exposureSeconds
        self.filterGrade = filterGrade
        self.paperType = recipe.paperType
        self.modelContext = context
        self.currentMode = .fullPrint
        
        let phases = buildPrintPhases()
        timerManager.setupPhases(phases)
        
        isConfigured = true
    }
    
    func configureForTestStrip(
        recipe: PrintRecipe,
        baseExposure: Double,
        stepCount: Int = 5,
        stepSize: Double = 2.0,
        context: ModelContext? = nil
    ) {
        self.printRecipe = recipe
        self.baseExposureSeconds = baseExposure
        self.testStripStepCount = stepCount
        self.testStripStepSize = stepSize
        self.paperType = recipe.paperType
        self.modelContext = context
        self.currentMode = .testStrip
        
        // Test strip uses exposure timer only
        let phases = buildTestStripPhases()
        timerManager.setupPhases(phases)
        
        isConfigured = true
    }
    
    func configureForSplitGrade(
        recipe: PrintRecipe,
        lowContrastSecs: Double,
        highContrastSecs: Double,
        context: ModelContext? = nil
    ) {
        self.printRecipe = recipe
        self.lowContrastExposure = lowContrastSecs
        self.highContrastExposure = highContrastSecs
        self.useSplitGrade = true
        self.paperType = recipe.paperType
        self.modelContext = context
        self.currentMode = .splitGrade
        
        let phases = buildSplitGradePhases()
        timerManager.setupPhases(phases)
        
        isConfigured = true
    }
    
    // MARK: - Phase Building
    
    private func buildPrintPhases() -> [TimerPhase] {
        var phases: [TimerPhase] = []
        
        // 1. Exposure
        let exposurePhase = TimerPhase(
            name: "Exposure",
            duration: totalExposureTime,
            type: .exposure,
            description: "Enlarger on - Filter \(filterGrade)"
        )
        phases.append(exposurePhase)
        
        // 2. Development
        let devTime = printRecipe?.developmentTimeSeconds ?? 60
        let devPhase = TimerPhase(
            name: "Development",
            duration: TimeInterval(devTime),
            type: .printDev,
            description: printRecipe?.developerName.rawValue ?? "Developer"
        )
        phases.append(devPhase)
        
        // 3. Stop Bath (brief)
        let stopPhase = TimerPhase(
            name: "Stop Bath",
            duration: 10,
            type: .stopBath,
            description: "Quick stop"
        )
        phases.append(stopPhase)
        
        // 4. Fixer
        let fixPhase = TimerPhase(
            name: "Fixer",
            duration: 60,
            type: .fixer,
            description: "Rapid fixer"
        )
        phases.append(fixPhase)
        
        // 5. Wash
        let washTime = paperType.washTimeMinutes * 60
        let washPhase = TimerPhase(
            name: "Final Wash",
            duration: TimeInterval(washTime),
            type: .wash,
            description: "Running water"
        )
        phases.append(washPhase)
        
        return phases
    }
    
    private func buildTestStripPhases() -> [TimerPhase] {
        var phases: [TimerPhase] = []
        
        // Create phases for each test strip step
        for step in 0..<testStripStepCount {
            let exposureTime = baseExposureSeconds + (Double(step) * testStripStepSize)
            let phase = TimerPhase(
                name: "Test Strip #\(step + 1)",
                duration: testStripStepSize,
                type: .exposure,
                description: "Cumulative: \(String(format: "%.1f", exposureTime))s"
            )
            phases.append(phase)
        }
        
        // Add development phases
        let devTime = printRecipe?.developmentTimeSeconds ?? 60
        phases.append(TimerPhase(
            name: "Development",
            duration: TimeInterval(devTime),
            type: .printDev,
            description: "Develop test strip"
        ))
        
        phases.append(TimerPhase(
            name: "Quick Fix",
            duration: 30,
            type: .fixer,
            description: "Temporary fix"
        ))
        
        return phases
    }
    
    private func buildSplitGradePhases() -> [TimerPhase] {
        var phases: [TimerPhase] = []
        
        // 1. Low contrast exposure (Filter 00 or 0)
        let lowContrastPhase = TimerPhase(
            name: "Low Contrast (Filter 00)",
            duration: lowContrastExposure,
            type: .exposure,
            description: "Soft exposure"
        )
        phases.append(lowContrastPhase)
        
        // 2. High contrast exposure (Filter 5)
        let highContrastPhase = TimerPhase(
            name: "High Contrast (Filter 5)",
            duration: highContrastExposure,
            type: .exposure,
            description: "Hard exposure"
        )
        phases.append(highContrastPhase)
        
        // Add standard processing phases
        phases.append(contentsOf: buildPrintPhases().dropFirst()) // Skip regular exposure
        
        return phases
    }
    
    // MARK: - Session Control
    
    func startExposure() {
        guard isConfigured else { return }
        timerManager.start()
    }
    
    func pause() {
        timerManager.pause()
    }
    
    func resume() {
        timerManager.start()
    }
    
    func stop() {
        timerManager.stop()
    }
    
    func reset() {
        timerManager.reset()
        isConfigured = false
        testStripResults = []
    }
    
    // MARK: - Test Strip
    
    func recordTestStripResult(step: Int, rating: TestStripRating) {
        let exposureTime = baseExposureSeconds + (Double(step) * testStripStepSize)
        let result = TestStripStep(
            stepNumber: step,
            exposureTime: exposureTime,
            rating: rating
        )
        
        if let existingIndex = testStripResults.firstIndex(where: { $0.stepNumber == step }) {
            testStripResults[existingIndex] = result
        } else {
            testStripResults.append(result)
        }
    }
    
    func getBestExposure() -> Double? {
        let goodResults = testStripResults.filter { $0.rating == .good }
        return goodResults.first?.exposureTime
    }
    
    // MARK: - Burn & Dodge
    
    func addBurnDodgeZone(
        type: BurnDodgeType,
        area: String,
        duration: Double,
        toolSize: String = "standard"
    ) {
        let zone = BurnDodgeZone(
            type: type,
            area: area,
            duration: duration,
            toolSize: toolSize
        )
        burnDodgeTimes.append(zone)
    }
    
    func removeBurnDodgeZone(at index: Int) {
        guard index < burnDodgeTimes.count else { return }
        burnDodgeTimes.remove(at: index)
    }
    
    // MARK: - F-Stop Timer
    
    /// Calculate exposure adjustment in f-stops
    func calculateFStopAdjustment(stops: Double) -> Double {
        return baseExposureSeconds * pow(2, stops)
    }
    
    /// Get common f-stop adjustments
    func getFStopAdjustments() -> [(label: String, time: Double)] {
        return [
            ("-2 stops", calculateFStopAdjustment(stops: -2)),
            ("-1 stop", calculateFStopAdjustment(stops: -1)),
            ("-1/2 stop", calculateFStopAdjustment(stops: -0.5)),
            ("Base", baseExposureSeconds),
            ("+1/2 stop", calculateFStopAdjustment(stops: 0.5)),
            ("+1 stop", calculateFStopAdjustment(stops: 1)),
            ("+2 stops", calculateFStopAdjustment(stops: 2))
        ]
    }
    
    // MARK: - Private Methods
    
    private func handleSessionComplete() {
        // Play completion sound
        AudioHapticFeedback.shared.playSessionCompleteSound()
    }
}

// MARK: - Supporting Types

struct TestStripStep: Identifiable, Codable {
    let id = UUID()
    let stepNumber: Int
    let exposureTime: Double
    var rating: TestStripRating
}

enum TestStripRating: String, Codable, CaseIterable {
    case tooLight = "Too Light"
    case light = "Light"
    case good = "Good"
    case dark = "Dark"
    case tooDark = "Too Dark"
    
    var color: String {
        switch self {
        case .tooLight: return "white"
        case .light: return "lightgray"
        case .good: return "gray"
        case .dark: return "darkgray"
        case .tooDark: return "black"
        }
    }
    
    var icon: String {
        switch self {
        case .tooLight: return "sun.max"
        case .light: return "sun.min"
        case .good: return "checkmark.circle"
        case .dark: return "moon"
        case .tooDark: return "moon.fill"
        }
    }
}

struct BurnDodgeZone: Identifiable, Codable {
    let id = UUID()
    let type: BurnDodgeType
    let area: String
    let duration: Double
    let toolSize: String
    
    var description: String {
        "\(type.rawValue) \(area) for \(String(format: "%.1f", duration))s"
    }
}

enum BurnDodgeType: String, Codable {
    case burn = "Burn"
    case dodge = "Dodge"
}

// MARK: - Print Session Extensions

extension PrintSession {
    
    /// Returns a formatted print record
    var printRecord: String {
        """
        Print Record
        ============
        Paper: \(paperType.rawValue)
        Developer: \(printRecipe?.developerName.rawValue ?? "Unknown")
        Filter: \(filterGrade)
        Exposure: \(formattedTotalExposure)
        Aperture: \(aperture)
        Enlarger Height: \(enlargerHeight)cm
        
        Notes:
        \(notes)
        """
    }
    
    /// Save print settings as a new recipe
    func saveAsRecipe(name: String, context: ModelContext) {
        let recipe = PrintRecipe(
            name: name,
            paperType: paperType,
            developerName: printRecipe?.developerName ?? .dektol,
            dilution: printRecipe?.dilution ?? .stock,
            developmentTimeSeconds: printRecipe?.developmentTimeSeconds ?? 60,
            temperatureCelsius: printRecipe?.temperatureCelsius ?? 20.0,
            notes: notes
        )
        context.insert(recipe)
        try? context.save()
    }
}
