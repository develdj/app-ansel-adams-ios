import Foundation
import SwiftUI
import CoreImage
import Photos
import CoreLocation

// MARK: - Exposure Metering Protocol

/// Protocol for exposure metering and zone calculation
public protocol ExposureMeteringProtocol: Sendable {
    /// Current metering mode
    var meteringMode: MeteringMode { get set }
    
    /// Current ISO setting
    var iso: Int { get set }
    
    /// Calculate exposure value from camera/lux reading
    func calculateEV(fromLux lux: Double) async throws -> ExposureValue
    
    /// Map a measured value to a zone
    func mapToZone(ev: ExposureValue, placementZone: Zone) -> Zone
    
    /// Calculate exposure compensation for zone placement
    func exposureCompensation(forTargetZone target: Zone, measuredZone: Zone) -> Double
    
    /// Get recommended settings for zone placement
    func recommendedSettings(forZone zone: Zone, baseEV: ExposureValue) -> ExposureSettings
}

// MARK: - Zone Mapping Protocol

/// Protocol for zone mapping and visualization
public protocol ZoneMappingProtocol: Sendable {
    /// Generate zone map from image
    func generateZoneMap(from image: CIImage) async throws -> ZoneMap
    
    /// Apply zone placement to image
    func applyZonePlacement(to image: CIImage, zoneMap: ZoneMap, placement: ZonePlacement) async throws -> CIImage
    
    /// Get zone histogram
    func zoneHistogram(from image: CIImage) async throws -> [Zone: Double]
    
    /// Find optimal exposure based on zone placement
    func findOptimalExposure(for image: CIImage, keyZone: Zone, targetValue: Double) async throws -> ExposureAdjustment
}

// MARK: - Emulsion Physics Protocol

/// Protocol for film emulsion physics simulation
public protocol EmulsionPhysicsProtocol: Sendable {
    /// Current emulsion type
    var emulsion: FilmEmulsion { get set }
    
    /// Calculate characteristic curve (H&D curve)
    func characteristicCurve(forEmulsion emulsion: FilmEmulsion) -> CharacteristicCurve
    
    /// Simulate exposure on emulsion
    func simulateExposure(logExposure: Double, developmentTime: TimeInterval) -> Density
    
    /// Calculate development time for target contrast
    func developmentTime(forTargetContrast contrast: Double, temperature: Double) -> TimeInterval
    
    /// Get film speed adjustment for development time
    func filmSpeedAdjustment(forDevelopmentTime time: TimeInterval) -> Double
    
    /// Simulate push/pull processing
    func simulatePushPull(stops: Int, baseTime: TimeInterval) -> ProcessingParameters
}

// MARK: - Darkroom Timer Protocol

/// Protocol for darkroom timing and process management
public protocol DarkroomTimerProtocol: Sendable {
    /// Current active phase
    var currentPhase: DarkroomPhase? { get }
    
    /// Timer state
    var timerState: TimerState { get }
    
    /// Start a darkroom phase
    func startPhase(_ phase: DarkroomPhase, duration: TimeInterval) async
    
    /// Pause current timer
    func pause() async
    
    /// Resume current timer
    func resume() async
    
    /// Stop and reset timer
    func stop() async
    
    /// Get recommended times for film/developer combination
    func recommendedTimes(film: FilmEmulsion, developer: DeveloperType, iso: Int, temperature: Double) -> PhaseTimes
    
    /// Stream of timer updates
    var timerUpdates: AsyncStream<TimerUpdate> { get }
}

// MARK: - Paper Simulation Protocol

/// Protocol for darkroom paper simulation
public protocol PaperSimulationProtocol: Sendable {
    /// Current paper type
    var paperType: PaperType { get set }
    
    /// Current contrast grade (0-5)
    var contrastGrade: Int { get set }
    
    /// Simulate print exposure
    func simulatePrint(from negative: CIImage, exposureTime: TimeInterval, aperture: Double) async throws -> CIImage
    
    /// Apply dodge and burn
    func applyDodgeBurn(to image: CIImage, masks: [DodgeBurnMask]) async throws -> CIImage
    
    /// Simulate split-grade printing
    func simulateSplitGrade(from negative: CIImage, softExposure: Double, hardExposure: Double) async throws -> CIImage
    
    /// Get paper characteristic curve
    func paperCurve(forGrade grade: Int) -> PaperCharacteristicCurve
}

// MARK: - AI Critique Protocol

/// Protocol for AI-powered image analysis and critique
public protocol AICritiqueProtocol: Sendable {
    /// Analyze image using Apple Intelligence
    func analyzeImage(_ image: CIImage) async throws -> ImageAnalysis
    
    /// Get zone-based critique
    func zoneCritique(for image: CIImage, zoneMap: ZoneMap) async throws -> ZoneCritique
    
    /// Generate improvement suggestions
    func suggestImprovements(for analysis: ImageAnalysis) async throws -> [ImprovementSuggestion]
    
    /// Chat with Ansel Adams AI persona
    func chatWithAnsel(message: String, context: ChatContext?) async throws -> AnselResponse
    
    /// Check if AI features are available
    var isAIAvailable: Bool { get }
}

// MARK: - Analog Archive Protocol

/// Protocol for film roll and exposure management
public protocol AnalogArchiveProtocol: Sendable {
    /// Create new film roll
    func createFilmRoll(format: FilmFormat, emulsion: FilmEmulsion, iso: Int) async throws -> FilmRoll
    
    /// Add exposure to roll
    func addExposure(to rollID: UUID, exposure: ExposureRecord) async throws
    
    /// Get all rolls
    func getAllRolls() async throws -> [FilmRoll]
    
    /// Get roll by ID
    func getRoll(id: UUID) async throws -> FilmRoll?
    
    /// Search rolls
    func searchRolls(query: String, filters: ArchiveFilters?) async throws -> [FilmRoll]
    
    /// Export roll data
    func exportRoll(id: UUID, format: ExportFormat) async throws -> Data
    
    /// Import roll data
    func importRoll(from data: Data) async throws -> FilmRoll
}

// MARK: - Instax BLE Protocol

/// Protocol for Instax printer communication
public protocol InstaxBLEProtocol: Sendable {
    /// Scan for Instax printers
    func scanForPrinters() async -> AsyncStream<InstaxPrinter>
    
    /// Connect to printer
    func connect(to printer: InstaxPrinter) async throws
    
    /// Disconnect from printer
    func disconnect() async
    
    /// Print image
    func printImage(_ image: CIImage, settings: PrintSettings) async throws -> PrintJob
    
    /// Get printer status
    func getPrinterStatus() async throws -> PrinterStatus
    
    /// Get connected printer
    var connectedPrinter: InstaxPrinter? { get }
    
    /// Connection state
    var connectionState: ConnectionState { get }
}

// MARK: - Panoramic Composition Protocol

/// Protocol for panoramic composition assistance
public protocol PanoramicCompositionProtocol: Sendable {
    /// Get composition guides for format
    func compositionGuides(for format: FilmFormat) -> [CompositionGuide]
    
    /// Calculate overlap for panorama stitching
    func calculateOverlap(frameCount: Int, format: FilmFormat) -> Double
    
    /// Generate panorama preview
    func generatePreview(from images: [CIImage], format: FilmFormat) async throws -> CIImage
    
    /// Get recommended rotation for format
    func recommendedRotation(for format: FilmFormat) -> RotationRecommendation
}

// MARK: - Store Protocol

/// Protocol for in-app purchase management
public protocol StoreProtocol: Sendable {
    /// PRO product
    var proProduct: Product? { get }
    
    /// Check if user has PRO
    var isProUnlocked: Bool { get }
    
    /// Purchase PRO
    func purchasePro() async throws -> PurchaseResult
    
    /// Restore purchases
    func restorePurchases() async throws -> Bool
    
    /// Check feature availability
    func isFeatureAvailable(_ feature: AppFeature) -> Bool
    
    /// Product updates stream
    var productUpdates: AsyncStream<StoreUpdate> { get }
}

// MARK: - Settings Protocol

/// Protocol for app settings management
public protocol SettingsProtocol: Sendable {
    /// Current theme
    var theme: AppTheme { get set }
    
    /// User experience level
    var experienceLevel: UserExperienceLevel { get set }
    
    /// Default film format
    var defaultFormat: FilmFormat { get set }
    
    /// Default emulsion
    var defaultEmulsion: FilmEmulsion { get set }
    
    /// Temperature unit
    var temperatureUnit: TemperatureUnit { get set }
    
    /// Enable haptic feedback
    var hapticFeedbackEnabled: Bool { get set }
    
    /// Enable sound effects
    var soundEffectsEnabled: Bool { get set }
    
    /// Darkroom safe color
    var darkroomSafeColor: DarkroomSafeColor { get set }
    
    /// Reset to defaults
    func resetToDefaults() async
}

// MARK: - Supporting Types

public struct ExposureSettings: Sendable, Equatable {
    public let aperture: Double
    public let shutterSpeed: Double
    public let iso: Int
    public let ev: ExposureValue
    public let zonePlacement: Zone
    
    public init(aperture: Double, shutterSpeed: Double, iso: Int, ev: ExposureValue, zonePlacement: Zone) {
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.iso = iso
        self.ev = ev
        self.zonePlacement = zonePlacement
    }
}

public struct ZoneMap: Sendable, Equatable {
    public let image: CIImage
    public let zoneData: [Zone: CGRect]
    public let histogram: [Zone: Double]
    
    public init(image: CIImage, zoneData: [Zone: CGRect], histogram: [Zone: Double]) {
        self.image = image
        self.zoneData = zoneData
        self.histogram = histogram
    }
}

public struct ZonePlacement: Sendable, Equatable {
    public let measuredZone: Zone
    public let targetZone: Zone
    public let compensation: Double
    
    public init(measuredZone: Zone, targetZone: Zone, compensation: Double) {
        self.measuredZone = measuredZone
        self.targetZone = targetZone
        self.compensation = compensation
    }
}

public struct ExposureAdjustment: Sendable, Equatable {
    public let stops: Double
    public let newEV: ExposureValue
    public let recommendedSettings: ExposureSettings
    
    public init(stops: Double, newEV: ExposureValue, recommendedSettings: ExposureSettings) {
        self.stops = stops
        self.newEV = newEV
        self.recommendedSettings = recommendedSettings
    }
}

public struct CharacteristicCurve: Sendable, Equatable {
    public let emulsion: FilmEmulsion
    public let points: [CurvePoint]
    public let gamma: Double
    public let dMax: Double
    public let dMin: Double
    
    public init(emulsion: FilmEmulsion, points: [CurvePoint], gamma: Double, dMax: Double, dMin: Double) {
        self.emulsion = emulsion
        self.points = points
        self.gamma = gamma
        self.dMax = dMax
        self.dMin = dMin
    }
}

public struct CurvePoint: Sendable, Equatable {
    public let logE: Double
    public let density: Double
    
    public init(logE: Double, density: Double) {
        self.logE = logE
        self.density = density
    }
}

public typealias Density = Double

public struct ProcessingParameters: Sendable, Equatable {
    public let developmentTime: TimeInterval
    public let temperature: Double
    public let agitation: AgitationPattern
    public let dilution: String
    
    public init(developmentTime: TimeInterval, temperature: Double, agitation: AgitationPattern, dilution: String) {
        self.developmentTime = developmentTime
        self.temperature = temperature
        self.agitation = agitation
        self.dilution = dilution
    }
}

@frozen
public enum AgitationPattern: String, Sendable, CaseIterable {
    case standard = "Standard"
    case minimal = "Minimal"
    case continuous = "Continuous"
    case stand = "Stand"
}

public struct PhaseTimes: Sendable, Equatable {
    public let development: TimeInterval
    public let stopBath: TimeInterval
    public let fixer: TimeInterval
    public let wash: TimeInterval
    public let hypoClear: TimeInterval
    public let finalWash: TimeInterval
    
    public init(development: TimeInterval, stopBath: TimeInterval, fixer: TimeInterval, wash: TimeInterval, hypoClear: TimeInterval, finalWash: TimeInterval) {
        self.development = development
        self.stopBath = stopBath
        self.fixer = fixer
        self.wash = wash
        self.hypoClear = hypoClear
        self.finalWash = finalWash
    }
}

@frozen
public enum TimerState: String, Sendable {
    case idle = "Idle"
    case running = "Running"
    case paused = "Paused"
    case completed = "Completed"
}

public struct TimerUpdate: Sendable {
    public let phase: DarkroomPhase
    public let remaining: TimeInterval
    public let total: TimeInterval
    public let state: TimerState
    
    public init(phase: DarkroomPhase, remaining: TimeInterval, total: TimeInterval, state: TimerState) {
        self.phase = phase
        self.remaining = remaining
        self.total = total
        self.state = state
    }
}

public struct DodgeBurnMask: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let rect: CGRect
    public let intensity: Double
    public let isDodge: Bool
    public let feather: Double
    
    public init(id: UUID = UUID(), rect: CGRect, intensity: Double, isDodge: Bool, feather: Double) {
        self.id = id
        self.rect = rect
        self.intensity = intensity
        self.isDodge = isDodge
        self.feather = feather
    }
}

public struct PaperCharacteristicCurve: Sendable, Equatable {
    public let grade: Int
    public let points: [CurvePoint]
    public let exposureScale: ClosedRange<Double>
    
    public init(grade: Int, points: [CurvePoint], exposureScale: ClosedRange<Double>) {
        self.grade = grade
        self.points = points
        self.exposureScale = exposureScale
    }
}

public struct ImageAnalysis: Sendable {
    public let overallRating: Double
    public let zoneDistribution: [Zone: Double]
    public let contrast: Double
    public let sharpness: Double
    public let compositionScore: Double
    public let technicalIssues: [TechnicalIssue]
    public let strengths: [String]
    
    public init(overallRating: Double, zoneDistribution: [Zone: Double], contrast: Double, sharpness: Double, compositionScore: Double, technicalIssues: [TechnicalIssue], strengths: [String]) {
        self.overallRating = overallRating
        self.zoneDistribution = zoneDistribution
        self.contrast = contrast
        self.sharpness = sharpness
        self.compositionScore = compositionScore
        self.technicalIssues = technicalIssues
        self.strengths = strengths
    }
}

public struct ZoneCritique: Sendable {
    public let zoneAnalysis: [Zone: ZoneAnalysis]
    public let recommendations: [String]
    public let optimalPlacement: ZonePlacement?
    
    public init(zoneAnalysis: [Zone: ZoneAnalysis], recommendations: [String], optimalPlacement: ZonePlacement?) {
        self.zoneAnalysis = zoneAnalysis
        self.recommendations = recommendations
        self.optimalPlacement = optimalPlacement
    }
}

public struct ZoneAnalysis: Sendable {
    public let zone: Zone
    public let coverage: Double
    public let hasDetail: Bool
    public let isBlocked: Bool
    public let isBlown: Bool
    
    public init(zone: Zone, coverage: Double, hasDetail: Bool, isBlocked: Bool, isBlown: Bool) {
        self.zone = zone
        self.coverage = coverage
        self.hasDetail = hasDetail
        self.isBlocked = isBlocked
        self.isBlown = isBlown
    }
}

public struct TechnicalIssue: Sendable, Identifiable {
    public let id: UUID
    public let type: IssueType
    public let severity: Severity
    public let description: String
    public let affectedZones: [Zone]
    
    public init(id: UUID = UUID(), type: IssueType, severity: Severity, description: String, affectedZones: [Zone]) {
        self.id = id
        self.type = type
        self.severity = severity
        self.description = description
        self.affectedZones = affectedZones
    }
}

@frozen
public enum IssueType: String, Sendable {
    case blockedShadows = "Blocked Shadows"
    case blownHighlights = "Blown Highlights"
    case lowContrast = "Low Contrast"
    case excessiveContrast = "Excessive Contrast"
    case poorComposition = "Poor Composition"
    case cameraShake = "Camera Shake"
    case incorrectExposure = "Incorrect Exposure"
}

@frozen
public enum Severity: String, Sendable, Comparable {
    case minor = "Minor"
    case moderate = "Moderate"
    case severe = "Severe"
    case critical = "Critical"
    
    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        let order: [Severity] = [.minor, .moderate, .severe, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}

public struct ImprovementSuggestion: Sendable, Identifiable {
    public let id: UUID
    public let category: SuggestionCategory
    public let description: String
    public let expectedImprovement: String
    public let difficulty: Difficulty
    
    public init(id: UUID = UUID(), category: SuggestionCategory, description: String, expectedImprovement: String, difficulty: Difficulty) {
        self.id = id
        self.category = category
        self.description = description
        self.expectedImprovement = expectedImprovement
        self.difficulty = difficulty
    }
}

@frozen
public enum SuggestionCategory: String, Sendable {
    case exposure = "Exposure"
    case development = "Development"
    case printing = "Printing"
    case composition = "Composition"
    case equipment = "Equipment"
}

@frozen
public enum Difficulty: String, Sendable {
    case easy = "Easy"
    case moderate = "Moderate"
    case advanced = "Advanced"
    case expert = "Expert"
}

public struct ChatContext: Sendable {
    public let currentImage: CIImage?
    public let currentZoneMap: ZoneMap?
    public let recentExposures: [ExposureRecord]
    public let userLevel: UserExperienceLevel
    
    public init(currentImage: CIImage?, currentZoneMap: ZoneMap?, recentExposures: [ExposureRecord], userLevel: UserExperienceLevel) {
        self.currentImage = currentImage
        self.currentZoneMap = currentZoneMap
        self.recentExposures = recentExposures
        self.userLevel = userLevel
    }
}

public struct AnselResponse: Sendable {
    public let message: String
    public let suggestions: [String]
    public let relatedTopics: [String]
    public let confidence: Double
    
    public init(message: String, suggestions: [String], relatedTopics: [String], confidence: Double) {
        self.message = message
        self.suggestions = suggestions
        self.relatedTopics = relatedTopics
        self.confidence = confidence
    }
}

public struct FilmRoll: Sendable, Identifiable, Codable {
    public let id: UUID
    public var name: String
    public let format: FilmFormat
       public let emulsion: FilmEmulsion
    public let iso: Int
    public let dateLoaded: Date
    public var dateCompleted: Date?
    public var exposures: [ExposureRecord]
    public var notes: String
    public var isDeveloped: Bool
    public var developmentInfo: DevelopmentInfo?
    
    public init(id: UUID = UUID(), name: String, format: FilmFormat, emulsion: FilmEmulsion, iso: Int, dateLoaded: Date = Date(), dateCompleted: Date? = nil, exposures: [ExposureRecord] = [], notes: String = "", isDeveloped: Bool = false, developmentInfo: DevelopmentInfo? = nil) {
        self.id = id
        self.name = name
        self.format = format
        self.emulsion = emulsion
        self.iso = iso
        self.dateLoaded = dateLoaded
        self.dateCompleted = dateCompleted
        self.exposures = exposures
        self.notes = notes
        self.isDeveloped = isDeveloped
        self.developmentInfo = developmentInfo
    }
}

public struct ExposureRecord: Sendable, Identifiable, Codable {
    public let id: UUID
    public let frameNumber: Int
    public let date: Date
    public let aperture: Double
    public let shutterSpeed: Double
    public let ev: Int
    public let zonePlacement: Zone
    public let subjectDescription: String
    public let location: LocationData?
    public let notes: String
    public var imageData: Data?
    
    public init(id: UUID = UUID(), frameNumber: Int, date: Date = Date(), aperture: Double, shutterSpeed: Double, ev: Int, zonePlacement: Zone, subjectDescription: String = "", location: LocationData? = nil, notes: String = "", imageData: Data? = nil) {
        self.id = id
        self.frameNumber = frameNumber
        self.date = date
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.ev = ev
        self.zonePlacement = zonePlacement
        self.subjectDescription = subjectDescription
        self.location = location
        self.notes = notes
        self.imageData = imageData
    }
}

public struct LocationData: Sendable, Codable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let locationName: String?
    
    public init(latitude: Double, longitude: Double, altitude: Double? = nil, locationName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.locationName = locationName
    }
}

public struct DevelopmentInfo: Sendable, Codable {
    public let developer: DeveloperType
    public let dilution: String
    public let temperature: Double
    public let developmentTime: TimeInterval
    public let agitation: AgitationPattern
    public let notes: String
    
    public init(developer: DeveloperType, dilution: String, temperature: Double, developmentTime: TimeInterval, agitation: AgitationPattern, notes: String = "") {
        self.developer = developer
        self.dilution = dilution
        self.temperature = temperature
        self.developmentTime = developmentTime
        self.agitation = agitation
        self.notes = notes
    }
}

public struct ArchiveFilters: Sendable {
    public let format: FilmFormat?
    public let emulsion: FilmEmulsion?
    public let dateRange: ClosedRange<Date>?
    public let isDeveloped: Bool?
    public let searchText: String?
    
    public init(format: FilmFormat? = nil, emulsion: FilmEmulsion? = nil, dateRange: ClosedRange<Date>? = nil, isDeveloped: Bool? = nil, searchText: String? = nil) {
        self.format = format
        self.emulsion = emulsion
        self.dateRange = dateRange
        self.isDeveloped = isDeveloped
        self.searchText = searchText
    }
}

@frozen
public enum ExportFormat: String, Sendable {
    case json = "JSON"
    case csv = "CSV"
    case pdf = "PDF"
}

public struct InstaxPrinter: Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let model: String
    public let rssi: Int
    public let batteryLevel: Int?
    
    public init(id: UUID, name: String, model: String, rssi: Int, batteryLevel: Int?) {
        self.id = id
        self.name = name
        self.model = model
        self.rssi = rssi
        self.batteryLevel = batteryLevel
    }
}

public struct PrintSettings: Sendable {
    public let brightness: Double
    public let contrast: Double
    public let cropMode: CropMode
    
    public init(brightness: Double = 0, contrast: Double = 0, cropMode: CropMode = .fit) {
        self.brightness = brightness
        self.contrast = contrast
        self.cropMode = cropMode
    }
}

@frozen
public enum CropMode: String, Sendable {
    case fit = "Fit"
    case fill = "Fill"
    case original = "Original"
}

public struct PrintJob: Sendable, Identifiable {
    public let id: UUID
    public let status: PrintJobStatus
    public let progress: Double
    public let estimatedCompletion: Date?
    
    public init(id: UUID, status: PrintJobStatus, progress: Double, estimatedCompletion: Date?) {
        self.id = id
        self.status = status
        self.progress = progress
        self.estimatedCompletion = estimatedCompletion
    }
}

@frozen
public enum PrintJobStatus: String, Sendable {
    case queued = "Queued"
    case printing = "Printing"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

public struct PrinterStatus: Sendable {
    public let isReady: Bool
    public let filmCount: Int
    public let batteryLevel: Int
    public let temperature: Double
    public let errorMessage: String?
    
    public init(isReady: Bool, filmCount: Int, batteryLevel: Int, temperature: Double, errorMessage: String?) {
        self.isReady = isReady
        self.filmCount = filmCount
        self.batteryLevel = batteryLevel
        self.temperature = temperature
        self.errorMessage = errorMessage
    }
}

@frozen
public enum ConnectionState: String, Sendable {
    case disconnected = "Disconnected"
    case scanning = "Scanning"
    case connecting = "Connecting"
    case connected = "Connected"
    case error = "Error"
}

public struct CompositionGuide: Sendable, Identifiable {
    public let id: UUID
    public let type: GuideType
    public let rect: CGRect
    public let color: String
    
    public init(id: UUID = UUID(), type: GuideType, rect: CGRect, color: String) {
        self.id = id
        self.type = type
        self.rect = rect
        self.color = color
    }
}

@frozen
public enum GuideType: String, Sendable {
    case ruleOfThirds = "Rule of Thirds"
    case goldenRatio = "Golden Ratio"
    case goldenSpiral = "Golden Spiral"
    case diagonal = "Diagonal"
    case center = "Center"
    case panoramicOverlap = "Panoramic Overlap"
}

public struct RotationRecommendation: Sendable {
    public let angle: Double
    public let confidence: Double
    public let reason: String
    
    public init(angle: Double, confidence: Double, reason: String) {
        self.angle = angle
        self.confidence = confidence
        self.reason = reason
    }
}

@frozen
public enum TemperatureUnit: String, Sendable, CaseIterable {
    case celsius = "Celsius"
    case fahrenheit = "Fahrenheit"
}

@frozen
public enum DarkroomSafeColor: String, Sendable, CaseIterable {
    case red = "Red"
    case amber = "Amber"
    case green = "Green"
    case dim = "Dim White"
}

public struct Product: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let price: Decimal
    public let currency: String
    
    public init(id: String, title: String, description: String, price: Decimal, currency: String) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.currency = currency
    }
}

@frozen
public enum PurchaseResult: String, Sendable {
    case success = "Success"
    case pending = "Pending"
    case cancelled = "Cancelled"
    case failed = "Failed"
}

public struct StoreUpdate: Sendable {
    public let type: UpdateType
    public let message: String?
    
    public init(type: UpdateType, message: String? = nil) {
        self.type = type
        self.message = message
    }
}

@frozen
public enum UpdateType: String, Sendable {
    case productLoaded = "Product Loaded"
    case purchaseCompleted = "Purchase Completed"
    case purchaseFailed = "Purchase Failed"
    case restored = "Restored"
    case proStatusChanged = "PRO Status Changed"
}
