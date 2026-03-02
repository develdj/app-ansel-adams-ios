import Foundation
import SwiftData
import CoreLocation

// MARK: - Exposure (SwiftData Model)
/// Rappresenta una singola esposizione/foto su un rullino
@Model
final class Exposure {
    // MARK: - Identificazione
    @Attribute(.unique) var id: UUID
    var frameNumber: Int
    var title: String
    var notes: String
    
    // MARK: - Relazione con Roll
    var roll: Roll?
    
    // MARK: - Data e ora
    var dateTaken: Date
    var timeZone: TimeZone?
    
    // MARK: - Camera e Obiettivo
    var cameraId: UUID?
    var cameraBrand: String
    var cameraModel: String
    var lensId: UUID?
    var lensBrand: String
    var lensModel: String
    var focalLength: Int // mm
    var focalLength35mm: Int? // equivalente 35mm
    
    // MARK: - Esposizione
    var shutterSpeedRaw: Double
    var apertureRaw: Double
    var isoUsed: Int
    
    // MARK: - Messa a fuoco
    var focusDistance: Double? // metri
    var focusDistanceInFeet: Double? // piedi
    var isHyperfocal: Bool
    var isInfinity: Bool
    
    // MARK: - Filtri
    var filterName: String?
    var filterTypeRaw: String?
    var filterStops: Double
    
    // MARK: - Luce e condizioni
    var lightConditionRaw: String
    var meteringMode: MeteringMode
    var meteredEV: Double?
    var actualEV: Double?
    
    // MARK: - Geolocalizzazione
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var locationName: String?
    var locationNotes: String?
    
    // MARK: - Valutazione
    var rating: ExposureRating
    var keepers: Bool
    var needsReprint: Bool
    
    // MARK: - Note tecniche
    var zonePlacement: Int? // Sistema Zona (0-10)
    var subjectBrightnessRange: String?
    var reciprocityCorrection: String?
    
    // MARK: - Collegamento digitale
    var linkedPhotoAssetId: String? // ID da Photo Library
    var scannedImagePath: String?
    var thumbnailPath: String?
    
    // MARK: - Relazioni
    @Relationship(deleteRule: .cascade, inverse: \Print.exposure)
    var prints: [Print]?
    
    // MARK: - Metadati
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    
    // MARK: - Computed Properties
    var shutterSpeed: ShutterSpeed {
        get { ShutterSpeed(seconds: shutterSpeedRaw) }
        set { shutterSpeedRaw = newValue.seconds }
    }
    
    var aperture: Aperture {
        get { Aperture(fStop: apertureRaw) }
        set { apertureRaw = newValue.fStop }
    }
    
    var lightCondition: LightCondition {
        get { LightCondition(rawValue: lightConditionRaw) ?? .other }
        set { lightConditionRaw = newValue.rawValue }
    }
    
    var filterType: FilterType? {
        get {
            guard let raw = filterTypeRaw else { return nil }
            return FilterType(rawValue: raw)
        }
        set { filterTypeRaw = newValue?.rawValue }
    }
    
    var coordinates: CLLocationCoordinate2D? {
        get {
            guard let lat = latitude, let lon = longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }
    
    var hasGPS: Bool {
        latitude != nil && longitude != nil
    }
    
    var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        if let location = locationName {
            return location
        }
        return "Foto #\(frameNumber)"
    }
    
    var exposureValue: Double? {
        guard shutterSpeedRaw > 0 else { return nil }
        let ev = log2(apertureRaw * apertureRaw / shutterSpeedRaw)
        return ev
    }
    
    var exposureSettings: String {
        "\(shutterSpeed.displayString) f/\(aperture.displayString)"
    }
    
    var cameraDisplayName: String {
        if cameraBrand.isEmpty && cameraModel.isEmpty {
            return "Camera non specificata"
        }
        return "\(cameraBrand) \(cameraModel)".trimmingCharacters(in: .whitespaces)
    }
    
    var lensDisplayName: String {
        if lensBrand.isEmpty && lensModel.isEmpty {
            return "Obiettivo non specificato"
        }
        var name = "\(lensBrand) \(lensModel)".trimmingCharacters(in: .whitespaces)
        if focalLength > 0 {
            name += " \(focalLength)mm"
        }
        return name
    }
    
    var focusDistanceDisplay: String {
        if isInfinity {
            return "∞"
        }
        if isHyperfocal {
            return "Iperfocale"
        }
        guard let distance = focusDistance else {
            return "Non specificata"
        }
        if distance < 1 {
            return String(format: "%.0f cm", distance * 100)
        } else {
            return String(format: "%.2f m", distance)
        }
    }
    
    var zoneSystemDisplay: String {
        guard let zone = zonePlacement else { return "Non specificato" }
        return "Zona \(zone)"
    }
    
    var printCount: Int {
        prints?.count ?? 0
    }
    
    var sortedPrints: [Print] {
        guard let prints = prints else { return [] }
        return prints.sorted { $0.datePrinted < $1.datePrinted }
    }
    
    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        frameNumber: Int,
        roll: Roll? = nil,
        title: String = "",
        dateTaken: Date = Date(),
        timeZone: TimeZone? = nil,
        camera: Camera? = nil,
        lens: Lens? = nil,
        focalLength: Int = 50,
        focalLength35mm: Int? = nil,
        shutterSpeed: ShutterSpeed = ShutterSpeed(fraction: 125),
        aperture: Aperture = Aperture(fStop: 8),
        isoUsed: Int = 400,
        focusDistance: Double? = nil,
        focusDistanceInFeet: Double? = nil,
        isHyperfocal: Bool = false,
        isInfinity: Bool = false,
        filter: Filter? = nil,
        filterStops: Double = 0,
        lightCondition: LightCondition = .other,
        meteringMode: MeteringMode = .matrix,
        meteredEV: Double? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        locationName: String? = nil,
        locationNotes: String? = nil,
        rating: ExposureRating = .unrated,
        keepers: Bool = false,
        needsReprint: Bool = false,
        zonePlacement: Int? = nil,
        subjectBrightnessRange: String? = nil,
        reciprocityCorrection: String? = nil,
        linkedPhotoAssetId: String? = nil,
        scannedImagePath: String? = nil,
        thumbnailPath: String? = nil,
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.frameNumber = frameNumber
        self.roll = roll
        self.title = title
        self.dateTaken = dateTaken
        self.timeZone = timeZone
        self.cameraId = camera?.id
        self.cameraBrand = camera?.brand ?? ""
        self.cameraModel = camera?.model ?? ""
        self.lensId = lens?.id
        self.lensBrand = lens?.brand ?? ""
        self.lensModel = lens?.model ?? ""
        self.focalLength = focalLength
        self.focalLength35mm = focalLength35mm
        self.shutterSpeedRaw = shutterSpeed.seconds
        self.apertureRaw = aperture.fStop
        self.isoUsed = isoUsed
        self.focusDistance = focusDistance
        self.focusDistanceInFeet = focusDistanceInFeet
        self.isHyperfocal = isHyperfocal
        self.isInfinity = isInfinity
        self.filterName = filter?.displayName
        self.filterTypeRaw = filter?.type.rawValue
        self.filterStops = filterStops
        self.lightConditionRaw = lightCondition.rawValue
        self.meteringMode = meteringMode
        self.meteredEV = meteredEV
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.locationName = locationName
        self.locationNotes = locationNotes
        self.rating = rating
        self.keepers = keepers
        self.needsReprint = needsReprint
        self.zonePlacement = zonePlacement
        self.subjectBrightnessRange = subjectBrightnessRange
        self.reciprocityCorrection = reciprocityCorrection
        self.linkedPhotoAssetId = linkedPhotoAssetId
        self.scannedImagePath = scannedImagePath
        self.thumbnailPath = thumbnailPath
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isFavorite = isFavorite
    }
    
    // MARK: - Methods
    func updateTimestamp() {
        updatedAt = Date()
    }
    
    func addPrint(_ print: Print) {
        if prints == nil {
            prints = []
        }
        prints?.append(print)
        print.exposure = self
        updateTimestamp()
    }
    
    func removePrint(_ print: Print) {
        prints?.removeAll { $0.id == print.id }
        updateTimestamp()
    }
    
    func calculateEV() -> Double? {
        guard shutterSpeedRaw > 0 else { return nil }
        return log2(apertureRaw * apertureRaw / shutterSpeedRaw)
    }
    
    func suggestedExposure(atISO iso: Int) -> (aperture: Aperture, shutterSpeed: ShutterSpeed)? {
        guard let ev = calculateEV() else { return nil }
        let adjustedEV = ev + log2(Double(isoUsed) / Double(iso))
        // Simplified - would need proper exposure calculation
        let newAperture = Aperture(fStop: 8)
        let newShutter = ShutterSpeed(seconds: pow(2, -adjustedEV) * 64)
        return (newAperture, newShutter)
    }
}

// MARK: - Exposure Rating
enum ExposureRating: String, Codable, CaseIterable, Sendable {
    case unrated = "Non valutata"
    case reject = "Scartare"
    case oneStar = "★"
    case twoStars = "★★"
    case threeStars = "★★★"
    case fourStars = "★★★★"
    case fiveStars = "★★★★★"
    
    var stars: Int {
        switch self {
        case .unrated: return 0
        case .reject: return 0
        case .oneStar: return 1
        case .twoStars: return 2
        case .threeStars: return 3
        case .fourStars: return 4
        case .fiveStars: return 5
        }
    }
    
    var isKeeper: Bool {
        stars >= 3
    }
    
    var color: String {
        switch self {
        case .unrated: return "gray"
        case .reject: return "red"
        case .oneStar: return "orange"
        case .twoStars: return "yellow"
        case .threeStars: return "green"
        case .fourStars: return "blue"
        case .fiveStars: return "purple"
        }
    }
}

// MARK: - Metering Mode
enum MeteringMode: String, Codable, CaseIterable, Sendable {
    case spot = "Spot"
    case centerWeighted = "Centro-pesata"
    case matrix = "Matriciale/Evaluativa"
    case partial = "Parziale"
    case highlight = "Highlight-weighted"
    case incident = "Incidente"
    case sunny16 = "Sunny 16"
    case zoneSystem = "Sistema Zona"
    case guess = "Stima"
    case other = "Altro"
    
    var description: String {
        switch self {
        case .spot:
            return "Misurazione su area molto ristretta (1-5%)"
        case .centerWeighted:
            return "Priorità all'area centrale"
        case .matrix:
            return "Valutazione multi-zona dell'intera scena"
        case .partial:
            return "Misurazione su area centrale (~10-15%)"
        case .highlight:
            return "Priorità alla protezione delle alte luci"
        case .incident:
            return "Misurazione della luce incidente con esposimetro"
        case .sunny16:
            return "Regola del Sunny 16"
        case .zoneSystem:
            return "Esposizione basata sul Sistema Zona di Ansel Adams"
        case .guess:
            return "Stima visiva senza esposimetro"
        case .other:
            return "Altro metodo"
        }
    }
}

// MARK: - Exposure Helpers
struct ExposureCalculator {
    /// Calcola il tempo di esposizione corretto per reciprocità
    static func reciprocityAdjustedTime(baseTime: Double, filmType: FilmType) -> Double {
        switch filmType {
        case .blackWhite:
            // Semplificazione per pellicole BN
            if baseTime < 1 {
                return baseTime
            } else if baseTime < 10 {
                return baseTime * 1.5
            } else if baseTime < 100 {
                return baseTime * 2
            } else {
                return baseTime * 3
            }
        case .colorNegative:
            // C-41 ha buona reciprocità
            return baseTime
        case .colorSlide:
            // E-6 richiede più correzione
            if baseTime > 1 {
                return baseTime * 1.5
            }
            return baseTime
        default:
            return baseTime
        }
    }
    
    /// Calcola la profondità di campo approssimativa
    static func depthOfField(
        aperture: Aperture,
        focalLength: Int,
        focusDistance: Double,
        circleOfConfusion: Double = 0.03 // mm per 35mm
    ) -> (near: Double, far: Double, total: Double) {
        let f = Double(focalLength)
        let N = aperture.fStop
        let c = circleOfConfusion
        let s = focusDistance * 1000 // convert to mm
        
        let hyperfocal = (f * f) / (N * c) + f
        
        let near = (hyperfocal * s) / (hyperfocal + (s - f))
        let far = (hyperfocal * s) / (hyperfocal - (s - f))
        
        let nearM = near / 1000
        let farM = far / 1000
        
        return (near: nearM, far: farM, total: farM - nearM)
    }
    
    /// Calcola l'EV per condizioni di luce standard
    static func sunny16EV(brightness: LightCondition) -> Int {
        brightness.ev100
    }
}
