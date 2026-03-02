import Foundation
import SwiftUI
import CoreImage

// MARK: - Mock Exposure Metering Service

@MainActor
public final class MockExposureMeteringService: ExposureMeteringProtocol {
    public var meteringMode: MeteringMode = .spot
    public var iso: Int = 400
    
    public init() {}
    
    public func calculateEV(fromLux lux: Double) async throws -> ExposureValue {
        let evValue = Int(log2(lux / 2.5))
        let clampedEV = max(-6, min(21, evValue))
        return ExposureValue(rawValue: clampedEV) ?? .ev0
    }
    
    public func mapToZone(ev: ExposureValue, placementZone: Zone) -> Zone {
        let offset = ev.rawValue - 12
        let zoneValue = placementZone.rawValue + offset
        let clampedZone = max(0, min(10, zoneValue))
        return Zone(rawValue: clampedZone) ?? .zone5
    }
    
    public func exposureCompensation(forTargetZone target: Zone, measuredZone: Zone) -> Double {
        Double(target.rawValue - measuredZone.rawValue)
    }
    
    public func recommendedSettings(forZone zone: Zone, baseEV: ExposureValue) -> ExposureSettings {
        let compensation = Double(zone.rawValue - 5)
        let adjustedEV = baseEV.rawValue + Int(compensation)
        let clampedEV = max(-6, min(21, adjustedEV))
        let finalEV = ExposureValue(rawValue: clampedEV) ?? .ev0
        
        return ExposureSettings(
            aperture: 8.0,
            shutterSpeed: 1.0 / pow(2.0, Double(finalEV.rawValue)),
            iso: iso,
            ev: finalEV,
            zonePlacement: zone
        )
    }
}

// MARK: - Mock Zone Mapping Service

@MainActor
public final class MockZoneMappingService: ZoneMappingProtocol {
    public init() {}
    
    public func generateZoneMap(from image: CIImage) async throws -> ZoneMap {
        let zoneData: [Zone: CGRect] = [
            .zone3: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3),
            .zone5: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
            .zone7: CGRect(x: 0.7, y: 0.7, width: 0.2, height: 0.2)
        ]
        
        let histogram: [Zone: Double] = [
            .zone0: 0.02, .zone1: 0.03, .zone2: 0.05, .zone3: 0.10,
            .zone4: 0.15, .zone5: 0.20, .zone6: 0.15, .zone7: 0.12,
            .zone8: 0.08, .zone9: 0.05, .zone10: 0.05
        ]
        
        return ZoneMap(image: image, zoneData: zoneData, histogram: histogram)
    }
    
    public func applyZonePlacement(to image: CIImage, zoneMap: ZoneMap, placement: ZonePlacement) async throws -> CIImage {
        return image
    }
    
    public func zoneHistogram(from image: CIImage) async throws -> [Zone: Double] {
        return [
            .zone0: 0.02, .zone1: 0.03, .zone2: 0.05, .zone3: 0.10,
            .zone4: 0.15, .zone5: 0.20, .zone6: 0.15, .zone7: 0.12,
            .zone8: 0.08, .zone9: 0.05, .zone10: 0.05
        ]
    }
    
    public func findOptimalExposure(for image: CIImage, keyZone: Zone, targetValue: Double) async throws -> ExposureAdjustment {
        let settings = ExposureSettings(
            aperture: 8.0,
            shutterSpeed: 1.0 / 125.0,
            iso: 400,
            ev: .ev12,
            zonePlacement: keyZone
        )
        
        return ExposureAdjustment(
            stops: 0.5,
            newEV: .ev13,
            recommendedSettings: settings
        )
    }
}

// MARK: - Mock Emulsion Physics Service

@MainActor
public final class MockEmulsionPhysicsService: EmulsionPhysicsProtocol {
    public var emulsion: FilmEmulsion = .ilfordHP5
    
    public init() {}
    
    public func characteristicCurve(forEmulsion emulsion: FilmEmulsion) -> CharacteristicCurve {
        let points = (0..<20).map { i in
            CurvePoint(
                logE: Double(i) * 0.3 - 3.0,
                density: min(2.5, max(0.1, Double(i) * 0.12))
            )
        }
        
        return CharacteristicCurve(
            emulsion: emulsion,
            points: points,
            gamma: emulsion.contrastIndex,
            dMax: 2.5,
            dMin: 0.15
        )
    }
    
    public func simulateExposure(logExposure: Double, developmentTime: TimeInterval) -> Density {
        let baseDensity = 0.15
        let growthRate = 0.5
        let maxDensity = 2.5
        
        let density = baseDensity + (maxDensity - baseDensity) * (1 - exp(-growthRate * logExposure * developmentTime / 600.0))
        return min(maxDensity, max(baseDensity, density))
    }
    
    public func developmentTime(forTargetContrast contrast: Double, temperature: Double) -> TimeInterval {
        let baseTime: TimeInterval = 600.0
        let contrastFactor = contrast / emulsion.contrastIndex
        let tempFactor = pow(1.1, (20.0 - temperature) / 2.0)
        
        return baseTime * contrastFactor * tempFactor
    }
    
    public func filmSpeedAdjustment(forDevelopmentTime time: TimeInterval) -> Double {
        let baseTime: TimeInterval = 600.0
        return sqrt(baseTime / time)
    }
    
    public func simulatePushPull(stops: Int, baseTime: TimeInterval) -> ProcessingParameters {
        let timeMultiplier = pow(1.4, Double(stops))
        let adjustedTime = baseTime * timeMultiplier
        
        return ProcessingParameters(
            developmentTime: adjustedTime,
            temperature: 20.0,
            agitation: stops > 0 ? .continuous : .minimal,
            dilution: stops > 1 ? "1+1" : "Stock"
        )
    }
}

// MARK: - Mock Darkroom Timer Service

@MainActor
public final class MockDarkroomTimerService: DarkroomTimerProtocol {
    public private(set) var currentPhase: DarkroomPhase?
    public private(set) var timerState: TimerState = .idle
    
    private var continuation: AsyncStream<TimerUpdate>.Continuation?
    
    public init() {}
    
    public var timerUpdates: AsyncStream<TimerUpdate> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    public func startPhase(_ phase: DarkroomPhase, duration: TimeInterval) async {
        currentPhase = phase
        timerState = .running
        
        let update = TimerUpdate(
            phase: phase,
            remaining: duration,
            total: duration,
            state: .running
        )
        continuation?.yield(update)
    }
    
    public func pause() async {
        timerState = .paused
        if let phase = currentPhase {
            let update = TimerUpdate(
                phase: phase,
                remaining: 300,
                total: 600,
                state: .paused
            )
            continuation?.yield(update)
        }
    }
    
    public func resume() async {
        timerState = .running
        if let phase = currentPhase {
            let update = TimerUpdate(
                phase: phase,
                remaining: 300,
                total: 600,
                state: .running
            )
            continuation?.yield(update)
        }
    }
    
    public func stop() async {
        currentPhase = nil
        timerState = .idle
    }
    
    public func recommendedTimes(film: FilmEmulsion, developer: DeveloperType, iso: Int, temperature: Double) -> PhaseTimes {
        return PhaseTimes(
            development: 600.0,
            stopBath: 30.0,
            fixer: 300.0,
            wash: 600.0,
            hypoClear: 120.0,
            finalWash: 600.0
        )
    }
}

// MARK: - Mock Paper Simulation Service

@MainActor
public final class MockPaperSimulationService: PaperSimulationProtocol {
    public var paperType: PaperType = .ilfordMultigradeIV
    public var contrastGrade: Int = 2
    
    public init() {}
    
    public func simulatePrint(from negative: CIImage, exposureTime: TimeInterval, aperture: Double) async throws -> CIImage {
        return negative
    }
    
    public func applyDodgeBurn(to image: CIImage, masks: [DodgeBurnMask]) async throws -> CIImage {
        return image
    }
    
    public func simulateSplitGrade(from negative: CIImage, softExposure: Double, hardExposure: Double) async throws -> CIImage {
        return negative
    }
    
    public func paperCurve(forGrade grade: Int) -> PaperCharacteristicCurve {
        let points = (0..<15).map { i in
            CurvePoint(
                logE: Double(i) * 0.2 - 1.5,
                density: min(2.0, max(0.05, Double(i) * 0.13))
            )
        }
        
        return PaperCharacteristicCurve(
            grade: grade,
            points: points,
            exposureScale: 1.0...2.5
        )
    }
}

// MARK: - Mock AI Critique Service

@MainActor
public final class MockAICritiqueService: AICritiqueProtocol {
    public init() {}
    
    public var isAIAvailable: Bool {
        // Check for Apple Intelligence availability
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    public func analyzeImage(_ image: CIImage) async throws -> ImageAnalysis {
        return ImageAnalysis(
            overallRating: 7.5,
            zoneDistribution: [
                .zone3: 0.15, .zone4: 0.20, .zone5: 0.25,
                .zone6: 0.20, .zone7: 0.15, .zone8: 0.05
            ],
            contrast: 0.72,
            sharpness: 0.85,
            compositionScore: 0.78,
            technicalIssues: [],
            strengths: [
                "Good tonal range in midtones",
                "Excellent sharpness",
                "Well-balanced composition"
            ]
        )
    }
    
    public func zoneCritique(for image: CIImage, zoneMap: ZoneMap) async throws -> ZoneCritique {
        let zoneAnalysis: [Zone: ZoneAnalysis] = [
            .zone3: ZoneAnalysis(zone: .zone3, coverage: 0.15, hasDetail: true, isBlocked: false, isBlown: false),
            .zone5: ZoneAnalysis(zone: .zone5, coverage: 0.25, hasDetail: true, isBlocked: false, isBlown: false),
            .zone7: ZoneAnalysis(zone: .zone7, coverage: 0.15, hasDetail: true, isBlocked: false, isBlown: false)
        ]
        
        return ZoneCritique(
            zoneAnalysis: zoneAnalysis,
            recommendations: [
                "Consider placing shadows in Zone III for better detail",
                "Highlights could benefit from slight compression"
            ],
            optimalPlacement: ZonePlacement(
                measuredZone: .zone5,
                targetZone: .zone5,
                compensation: 0.0
            )
        )
    }
    
    public func suggestImprovements(for analysis: ImageAnalysis) async throws -> [ImprovementSuggestion] {
        return [
            ImprovementSuggestion(
                category: .exposure,
                description: "Expose for Zone III shadows to retain detail",
                expectedImprovement: "Better shadow detail with full tonal range",
                difficulty: .moderate
            ),
            ImprovementSuggestion(
                category: .development,
                description: "Reduce development time by 10% for lower contrast",
                expectedImprovement: "More printable negative with better highlight control",
                difficulty: .easy
            )
        ]
    }
    
    public func chatWithAnsel(message: String, context: ChatContext?) async throws -> AnselResponse {
        let responses = [
            "The Zone System is not just about exposure—it's about visualization. Before you press the shutter, you must see the final print in your mind's eye.",
            "Remember: expose for the shadows, develop for the highlights. This is the foundation of the Zone System.",
            "A good negative is one that contains all the information you need to make the print you visualized.",
            "The camera is a tool for translating your vision into reality. Master the technical, but never let it overshadow the artistic.",
            "Zone V is middle gray—18% reflectance. Everything else flows from this reference point."
        ]
        
        return AnselResponse(
            message: responses.randomElement() ?? responses[0],
            suggestions: ["Learn about Zone Placement", "Study characteristic curves", "Practice visualization"],
            relatedTopics: ["Exposure", "Development", "Visualization"],
            confidence: 0.92
        )
    }
}

// MARK: - Mock Analog Archive Service

@MainActor
public final class MockAnalogArchiveService: AnalogArchiveProtocol {
    private var rolls: [FilmRoll] = []
    
    public init() {
        // Create sample data
        rolls = [
            FilmRoll(
                name: "Yosemite Trip",
                format: .mm4x5,
                emulsion: .ilfordFP4,
                iso: 125,
                dateLoaded: Date().addingTimeInterval(-86400 * 30),
                isDeveloped: true,
                developmentInfo: DevelopmentInfo(
                    developer: .ilfordDDX,
                    dilution: "1+4",
                    temperature: 20.0,
                    developmentTime: 540.0,
                    agitation: .standard
                )
            ),
            FilmRoll(
                name: "Street Photography",
                format: .mm35,
                emulsion: .kodakTriX,
                iso: 400,
                dateLoaded: Date().addingTimeInterval(-86400 * 7),
                isDeveloped: false
            )
        ]
    }
    
    public func createFilmRoll(format: FilmFormat, emulsion: FilmEmulsion, iso: Int) async throws -> FilmRoll {
        let roll = FilmRoll(
            name: "New Roll",
            format: format,
            emulsion: emulsion,
            iso: iso
        )
        rolls.append(roll)
        return roll
    }
    
    public func addExposure(to rollID: UUID, exposure: ExposureRecord) async throws {
        if let index = rolls.firstIndex(where: { $0.id == rollID }) {
            rolls[index].exposures.append(exposure)
        }
    }
    
    public func getAllRolls() async throws -> [FilmRoll] {
        return rolls
    }
    
    public func getRoll(id: UUID) async throws -> FilmRoll? {
        return rolls.first { $0.id == id }
    }
    
    public func searchRolls(query: String, filters: ArchiveFilters?) async throws -> [FilmRoll] {
        return rolls.filter { roll in
            roll.name.localizedCaseInsensitiveContains(query) ||
            roll.emulsion.rawValue.localizedCaseInsensitiveContains(query)
        }
    }
    
    public func exportRoll(id: UUID, format: ExportFormat) async throws -> Data {
        return Data()
    }
    
    public func importRoll(from data: Data) async throws -> FilmRoll {
        return FilmRoll(name: "Imported", format: .mm35, emulsion: .ilfordHP5, iso: 400)
    }
}

// MARK: - Mock Instax BLE Service

@MainActor
public final class MockInstaxBLEService: InstaxBLEProtocol {
    public private(set) var connectedPrinter: InstaxPrinter?
    public private(set) var connectionState: ConnectionState = .disconnected
    
    public init() {}
    
    public func scanForPrinters() async -> AsyncStream<InstaxPrinter> {
        AsyncStream { continuation in
            let printers = [
                InstaxPrinter(id: UUID(), name: "INSTAX Mini Link 3", model: "Mini Link 3", rssi: -45, batteryLevel: 85),
                InstaxPrinter(id: UUID(), name: "INSTAX SQ Link", model: "SQ Link", rssi: -52, batteryLevel: 72)
            ]
            
            for printer in printers {
                continuation.yield(printer)
            }
            continuation.finish()
        }
    }
    
    public func connect(to printer: InstaxPrinter) async throws {
        connectionState = .connecting
        try await Task.sleep(for: .seconds(1))
        connectedPrinter = printer
        connectionState = .connected
    }
    
    public func disconnect() async {
        connectedPrinter = nil
        connectionState = .disconnected
    }
    
    public func printImage(_ image: CIImage, settings: PrintSettings) async throws -> PrintJob {
        return PrintJob(
            id: UUID(),
            status: .printing,
            progress: 0.0,
            estimatedCompletion: Date().addingTimeInterval(30)
        )
    }
    
    public func getPrinterStatus() async throws -> PrinterStatus {
        return PrinterStatus(
            isReady: true,
            filmCount: 8,
            batteryLevel: 85,
            temperature: 25.0,
            errorMessage: nil
        )
    }
}

// MARK: - Mock Panoramic Composition Service

@MainActor
public final class MockPanoramicCompositionService: PanoramicCompositionProtocol {
    public init() {}
    
    public func compositionGuides(for format: FilmFormat) -> [CompositionGuide] {
        return [
            CompositionGuide(
                type: .ruleOfThirds,
                rect: CGRect(x: 0.33, y: 0.33, width: 0.33, height: 0.33),
                color: "#FFFFFF"
            ),
            CompositionGuide(
                type: .panoramicOverlap,
                rect: CGRect(x: 0.7, y: 0, width: 0.3, height: 1.0),
                color: "#FF0000"
            )
        ]
    }
    
    public func calculateOverlap(frameCount: Int, format: FilmFormat) -> Double {
        return 0.30 // 30% overlap recommended
    }
    
    public func generatePreview(from images: [CIImage], format: FilmFormat) async throws -> CIImage {
        guard let first = images.first else {
            throw PanoramicError.noImages
        }
        return first
    }
    
    public func recommendedRotation(for format: FilmFormat) -> RotationRecommendation {
        return RotationRecommendation(
            angle: 0.0,
            confidence: 0.95,
            reason: "Level horizon recommended for panoramic composition"
        )
    }
}

public enum PanoramicError: Error {
    case noImages
    case insufficientOverlap
    case stitchingFailed
}

// MARK: - Mock Store Service

@MainActor
public final class MockStoreService: StoreProtocol {
    public var proProduct: Product?
    public private(set) var isProUnlocked: Bool
    
    private var continuation: AsyncStream<StoreUpdate>.Continuation?
    
    public init(proUnlocked: Bool = false) {
        self.isProUnlocked = proUnlocked
        self.proProduct = Product(
            id: "com.zonesystemmaster.pro",
            title: "Zone System Master PRO",
            description: "Unlock all professional features",
            price: 24.99,
            currency: "EUR"
        )
    }
    
    public var productUpdates: AsyncStream<StoreUpdate> {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }
    
    public func purchasePro() async throws -> PurchaseResult {
        isProUnlocked = true
        continuation?.yield(StoreUpdate(type: .proStatusChanged))
        return .success
    }
    
    public func restorePurchases() async throws -> Bool {
        isProUnlocked = true
        continuation?.yield(StoreUpdate(type: .restored))
        return true
    }
    
    public func isFeatureAvailable(_ feature: AppFeature) -> Bool {
        if feature.isProFeature {
            return isProUnlocked
        }
        return true
    }
}
