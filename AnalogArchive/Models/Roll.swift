import Foundation
import SwiftData

// MARK: - Roll (SwiftData Model)
/// Rappresenta un rullino di pellicola caricato in camera
@Model
final class Roll {
    // MARK: - Identificazione
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    
    // MARK: - Pellicola
    var filmStockId: UUID?
    var filmManufacturerRaw: String
    var filmName: String
    var nominalISO: Int
    var effectiveISO: Int
    var formatRaw: String
    var filmTypeRaw: String
    
    // MARK: - Date
    var dateLoaded: Date
    var dateDeveloped: Date?
    var dateScanned: Date?
    
    // MARK: - Sviluppo
    var developerName: String
    var dilution: String
    var developmentTime: TimeInterval?
    var developmentTemperature: Double? // Celsius
    var developmentAgitation: AgitationType
    var developmentNotes: String
    
    // MARK: - Stato
    var status: RollStatus
    var isPushPull: Bool
    var pushPullStops: Double // Positivo = push, negativo = pull
    
    // MARK: - Relazioni
    @Relationship(deleteRule: .cascade, inverse: \Exposure.roll)
    var exposures: [Exposure]?
    
    // MARK: - Metadati
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    var rating: Int // 0-5
    
    // MARK: - Archiviazione fisica
    var storageLocation: String?
    var negativePage: Int?
    var negativeSleeveNumber: String?
    
    // MARK: - Computed Properties
    var filmManufacturer: FilmManufacturer {
        get { FilmManufacturer(rawValue: filmManufacturerRaw) ?? .other }
        set { filmManufacturerRaw = newValue.rawValue }
    }
    
    var format: FilmFormat {
        get { FilmFormat(rawValue: formatRaw) ?? .mm35 }
        set { formatRaw = newValue.rawValue }
    }
    
    var filmType: FilmType {
        get { FilmType(rawValue: filmTypeRaw) ?? .blackWhite }
        set { filmTypeRaw = newValue.rawValue }
    }
    
    var displayName: String {
        if name.isEmpty {
            return "\(filmManufacturer.rawValue) \(filmName)"
        }
        return name
    }
    
    var fullFilmName: String {
        "\(filmManufacturer.rawValue) \(filmName)"
    }
    
    var exposureCount: Int {
        exposures?.count ?? 0
    }
    
    var expectedFrameCount: Int {
        format.framesPerRoll ?? 36
    }
    
    var isComplete: Bool {
        guard let exposures = exposures else { return false }
        return exposures.count >= expectedFrameCount
    }
    
    var pushPullDescription: String {
        if !isPushPull || pushPullStops == 0 {
            return "Box speed"
        }
        let stops = abs(pushPullStops)
        let direction = pushPullStops > 0 ? "Push" : "Pull"
        let plural = stops == 1 ? "" : "s"
        return "\(direction) +\(String(format: "%.1f", stops)) stop\(plural)"
    }
    
    var developmentTimeFormatted: String {
        guard let time = developmentTime else { return "Non specificato" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var temperatureFormatted: String {
        guard let temp = developmentTemperature else { return "Non specificata" }
        return String(format: "%.1f°C", temp)
    }
    
    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        name: String = "",
        filmStock: FilmStock? = nil,
        filmManufacturer: FilmManufacturer = .ilford,
        filmName: String = "",
        nominalISO: Int = 400,
        effectiveISO: Int? = nil,
        format: FilmFormat = .mm35,
        filmType: FilmType = .blackWhite,
        dateLoaded: Date = Date(),
        dateDeveloped: Date? = nil,
        developerName: String = "",
        dilution: String = "1+1",
        developmentTime: TimeInterval? = nil,
        developmentTemperature: Double? = 20.0,
        developmentAgitation: AgitationType = .standard,
        developmentNotes: String = "",
        status: RollStatus = .loaded,
        isPushPull: Bool = false,
        pushPullStops: Double = 0,
        notes: String = "",
        isFavorite: Bool = false,
        rating: Int = 0,
        storageLocation: String? = nil,
        negativePage: Int? = nil,
        negativeSleeveNumber: String? = nil
    ) {
        self.id = id
        self.name = name
        self.filmStockId = filmStock?.id
        self.filmManufacturerRaw = filmStock?.manufacturer.rawValue ?? filmManufacturer.rawValue
        self.filmName = filmStock?.name ?? filmName
        self.nominalISO = filmStock?.iso ?? nominalISO
        self.effectiveISO = effectiveISO ?? filmStock?.iso ?? nominalISO
        self.formatRaw = filmStock?.format.rawValue ?? format.rawValue
        self.filmTypeRaw = filmStock?.type.rawValue ?? filmType.rawValue
        self.dateLoaded = dateLoaded
        self.dateDeveloped = dateDeveloped
        self.developerName = developerName
        self.dilution = dilution
        self.developmentTime = developmentTime
        self.developmentTemperature = developmentTemperature
        self.developmentAgitation = developmentAgitation
        self.developmentNotes = developmentNotes
        self.status = status
        self.isPushPull = isPushPull
        self.pushPullStops = pushPullStops
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isFavorite = isFavorite
        self.rating = rating
        self.storageLocation = storageLocation
        self.negativePage = negativePage
        self.negativeSleeveNumber = negativeSleeveNumber
    }
    
    // MARK: - Methods
    func updateTimestamp() {
        updatedAt = Date()
    }
    
    func addExposure(_ exposure: Exposure) {
        if exposures == nil {
            exposures = []
        }
        exposures?.append(exposure)
        exposure.roll = self
        updateTimestamp()
    }
    
    func removeExposure(_ exposure: Exposure) {
        exposures?.removeAll { $0.id == exposure.id }
        updateTimestamp()
    }
    
    func nextFrameNumber() -> Int {
        guard let exposures = exposures, !exposures.isEmpty else {
            return 1
        }
        return (exposures.map { $0.frameNumber }.max() ?? 0) + 1
    }
    
    func sortedExposures() -> [Exposure] {
        guard let exposures = exposures else { return [] }
        return exposures.sorted { $0.frameNumber < $1.frameNumber }
    }
    
    func exposuresByDate() -> [Exposure] {
        guard let exposures = exposures else { return [] }
        return exposures.sorted { $0.dateTaken < $1.dateTaken }
    }
}

// MARK: - Roll Status
enum RollStatus: String, Codable, CaseIterable, Sendable {
    case loaded = "Caricato"
    case inProgress = "In corso"
    case exposed = "Esposto"
    case developed = "Sviluppato"
    case scanned = "Scannerizzato"
    case archived = "Archiviato"
    case discarded = "Scartato"
    
    var icon: String {
        switch self {
        case .loaded: return "arrow.down.circle"
        case .inProgress: return "camera.fill"
        case .exposed: return "checkmark.circle"
        case .developed: return "drop.fill"
        case .scanned: return "scanner"
        case .archived: return "archivebox.fill"
        case .discarded: return "trash"
        }
    }
    
    var color: String {
        switch self {
        case .loaded: return "blue"
        case .inProgress: return "green"
        case .exposed: return "orange"
        case .developed: return "purple"
        case .scanned: return "cyan"
        case .archived: return "gray"
        case .discarded: return "red"
        }
    }
    
    var canAddExposures: Bool {
        self == .loaded || self == .inProgress
    }
    
    var isFinal: Bool {
        self == .archived || self == .discarded
    }
}

// MARK: - Agitation Type
enum AgitationType: String, Codable, CaseIterable, Sendable {
    case continuous = "Continua"
    case standard = "Standard (ogni 30s)"
    case minimal = "Minimale (ogni 60s)"
    case stand = "Stand (1x iniziale)"
    case semiStand = "Semi-stand (2x)"
    
    var description: String {
        switch self {
        case .continuous:
            return "Agitazione continua per tutto il tempo di sviluppo"
        case .standard:
            return "Agitazione continua per 30s, poi 10s ogni 30s"
        case .minimal:
            return "Agitazione continua per 60s, poi 10s ogni 60s"
        case .stand:
            return "Una sola agitazione iniziale di 30s"
        case .semiStand:
            return "Agitazione iniziale 30s, poi 10s a metà tempo"
        }
    }
}

// MARK: - Developer Preset
struct DeveloperPreset: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var dilution: String
    var description: String
    var typicalTemperature: Double
    var isBlackWhite: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        dilution: String,
        description: String = "",
        typicalTemperature: Double = 20.0,
        isBlackWhite: Bool = true
    ) {
        self.id = id
        self.name = name
        self.dilution = dilution
        self.description = description
        self.typicalTemperature = typicalTemperature
        self.isBlackWhite = isBlackWhite
    }
    
    static let presets: [DeveloperPreset] = [
        // Sviluppatori BN
        DeveloperPreset(name: "D-76", dilution: "1+1", description: "Sviluppatore classico, grana fine"),
        DeveloperPreset(name: "D-76", dilution: "Stock", description: "Sviluppatore classico stock"),
        DeveloperPreset(name: "ID-11", dilution: "1+1", description: "Equivalente Ilford del D-76"),
        DeveloperPreset(name: "ID-11", dilution: "Stock", description: "ID-11 stock"),
        DeveloperPreset(name: "HC-110", dilution: "Dil. B (1+31)", description: "Sviluppatore concentrato, grana fine"),
        DeveloperPreset(name: "HC-110", dilution: "Dil. A (1+15)", description: "HC-110 diluizione A"),
        DeveloperPreset(name: "Rodinal", dilution: "1+25", description: "Sviluppatore acutance, grana visibile"),
        DeveloperPreset(name: "Rodinal", dilution: "1+50", description: "Rodinal standard"),
        DeveloperPreset(name: "Rodinal", dilution: "1+100", description: "Rodinal stand/semi-stand"),
        DeveloperPreset(name: "X-Tol", dilution: "1+1", description: "Sviluppatore moderno, grana fine"),
        DeveloperPreset(name: "X-Tol", dilution: "Stock", description: "X-Tol stock"),
        DeveloperPreset(name: "Ilfosol 3", dilution: "1+9", description: "Sviluppatore liquido Ilford"),
        DeveloperPreset(name: "Perceptol", dilution: "1+1", description: "Sviluppatore fine grain"),
        DeveloperPreset(name: "Microphen", dilution: "1+1", description: "Sviluppatore speed enhancing"),
        DeveloperPreset(name: "DD-X", dilution: "1+4", description: "Sviluppatore liquido Ilford premium"),
        DeveloperPreset(name: "FX-39", dilution: "1+9", description: "Sviluppatore compensante"),
        DeveloperPreset(name: "Pyrocat-HD", dilution: "1+1+100", description: "Sviluppatore staining"),
        DeveloperPreset(name: "PMK Pyro", dilution: "1+2+100", description: "Sviluppatore staining classico"),
        DeveloperPreset(name: "Caffenol", dilution: "C-M", description: "Sviluppatore fatto in casa"),
        
        // Sviluppatori colore C-41
        DeveloperPreset(name: "C-41", dilution: "Kit", description: "Processo colore negativo", isBlackWhite: false),
        DeveloperPreset(name: "Tetenal C-41", dilution: "Kit", description: "Kit Tetenal C-41", isBlackWhite: false),
        DeveloperPreset(name: "Unicolor C-41", dilution: "Kit", description: "Kit Unicolor C-41", isBlackWhite: false),
        DeveloperPreset(name: "Bellini C-41", dilution: "Kit", description: "Kit Bellini C-41", isBlackWhite: false),
        
        // Sviluppatori diapositive E-6
        DeveloperPreset(name: "E-6", dilution: "Kit", description: "Processo diapositiva", isBlackWhite: false),
        DeveloperPreset(name: "Tetenal E-6", dilution: "Kit", description: "Kit Tetenal E-6", isBlackWhite: false),
        DeveloperPreset(name: "Ars-Imago E-6", dilution: "Kit", description: "Kit Ars-Imago E-6", isBlackWhite: false),
        
        // Sviluppatori ECN-2
        DeveloperPreset(name: "ECN-2", dilution: "Kit", description: "Processo pellicola cinema", isBlackWhite: false),
        DeveloperPreset(name: "Cinestill C-41", dilution: "Kit", description: "C-41 modificato per cinema", isBlackWhite: false),
    ]
}
