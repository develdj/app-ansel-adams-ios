import Foundation
import SwiftData
import ZoneSystemCore

// MARK: - Film Roll Model

@Model
final class FilmRollModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var formatRaw: String
    var emulsionRaw: String
    var iso: Int
    var dateLoaded: Date
    var dateCompleted: Date?
    var notes: String
    var isDeveloped: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \ExposureRecordModel.roll)
    var exposures: [ExposureRecordModel]?
    
    @Relationship(deleteRule: .nullify)
    var developmentInfo: DevelopmentInfoModel?
    
    init(
        id: UUID = UUID(),
        name: String,
        format: FilmFormat,
        emulsion: FilmEmulsion,
        iso: Int,
        dateLoaded: Date = Date(),
        dateCompleted: Date? = nil,
        notes: String = "",
        isDeveloped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.formatRaw = format.rawValue
        self.emulsionRaw = emulsion.rawValue
        self.iso = iso
        self.dateLoaded = dateLoaded
        self.dateCompleted = dateCompleted
        self.notes = notes
        self.isDeveloped = isDeveloped
    }
    
    var format: FilmFormat {
        get { FilmFormat(rawValue: formatRaw) ?? .mm35 }
        set { formatRaw = newValue.rawValue }
    }
    
    var emulsion: FilmEmulsion {
        get { FilmEmulsion(rawValue: emulsionRaw) ?? .ilfordHP5 }
        set { emulsionRaw = newValue.rawValue }
    }
    
    func toFilmRoll() -> FilmRoll {
        FilmRoll(
            id: id,
            name: name,
            format: format,
            emulsion: emulsion,
            iso: iso,
            dateLoaded: dateLoaded,
            dateCompleted: dateCompleted,
            exposures: (exposures ?? []).map { $0.toExposureRecord() },
            notes: notes,
            isDeveloped: isDeveloped,
            developmentInfo: developmentInfo?.toDevelopmentInfo()
        )
    }
    
    static func from(_ roll: FilmRoll) -> FilmRollModel {
        FilmRollModel(
            id: roll.id,
            name: roll.name,
            format: roll.format,
            emulsion: roll.emulsion,
            iso: roll.iso,
            dateLoaded: roll.dateLoaded,
            dateCompleted: roll.dateCompleted,
            notes: roll.notes,
            isDeveloped: roll.isDeveloped
        )
    }
}

// MARK: - Exposure Record Model

@Model
final class ExposureRecordModel {
    @Attribute(.unique) var id: UUID
    var frameNumber: Int
    var date: Date
    var aperture: Double
    var shutterSpeed: Double
    var ev: Int
    var zonePlacementRaw: Int
    var subjectDescription: String
    var notes: String
    var imageData: Data?
    
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var locationName: String?
    
    @Relationship(inverse: \FilmRollModel.exposures)
    var roll: FilmRollModel?
    
    init(
        id: UUID = UUID(),
        frameNumber: Int,
        date: Date = Date(),
        aperture: Double,
        shutterSpeed: Double,
        ev: Int,
        zonePlacement: Zone,
        subjectDescription: String = "",
        notes: String = "",
        imageData: Data? = nil,
        location: LocationData? = nil
    ) {
        self.id = id
        self.frameNumber = frameNumber
        self.date = date
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.ev = ev
        self.zonePlacementRaw = zonePlacement.rawValue
        self.subjectDescription = subjectDescription
        self.notes = notes
        self.imageData = imageData
        
        self.latitude = location?.latitude
        self.longitude = location?.longitude
        self.altitude = location?.altitude
        self.locationName = location?.locationName
    }
    
    var zonePlacement: Zone {
        get { Zone(rawValue: zonePlacementRaw) ?? .zone5 }
        set { zonePlacementRaw = newValue.rawValue }
    }
    
    var location: LocationData? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return LocationData(
            latitude: lat,
            longitude: lon,
            altitude: altitude,
            locationName: locationName
        )
    }
    
    func toExposureRecord() -> ExposureRecord {
        ExposureRecord(
            id: id,
            frameNumber: frameNumber,
            date: date,
            aperture: aperture,
            shutterSpeed: shutterSpeed,
            ev: ev,
            zonePlacement: zonePlacement,
            subjectDescription: subjectDescription,
            location: location,
            notes: notes,
            imageData: imageData
        )
    }
    
    static func from(_ record: ExposureRecord) -> ExposureRecordModel {
        ExposureRecordModel(
            id: record.id,
            frameNumber: record.frameNumber,
            date: record.date,
            aperture: record.aperture,
            shutterSpeed: record.shutterSpeed,
            ev: record.ev,
            zonePlacement: record.zonePlacement,
            subjectDescription: record.subjectDescription,
            notes: record.notes,
            imageData: record.imageData,
            location: record.location
        )
    }
}

// MARK: - Development Info Model

@Model
final class DevelopmentInfoModel {
    var developerRaw: String
    var dilution: String
    var temperature: Double
    var developmentTime: TimeInterval
    var agitationRaw: String
    var notes: String
    
    @Relationship(inverse: \FilmRollModel.developmentInfo)
    var roll: FilmRollModel?
    
    init(
        developer: DeveloperType,
        dilution: String,
        temperature: Double,
        developmentTime: TimeInterval,
        agitation: AgitationPattern,
        notes: String = ""
    ) {
        self.developerRaw = developer.rawValue
        self.dilution = dilution
        self.temperature = temperature
        self.developmentTime = developmentTime
        self.agitationRaw = agitation.rawValue
        self.notes = notes
    }
    
    var developer: DeveloperType {
        get { DeveloperType(rawValue: developerRaw) ?? .ilfordID11 }
        set { developerRaw = newValue.rawValue }
    }
    
    var agitation: AgitationPattern {
        get { AgitationPattern(rawValue: agitationRaw) ?? .standard }
        set { agitationRaw = newValue.rawValue }
    }
    
    func toDevelopmentInfo() -> DevelopmentInfo {
        DevelopmentInfo(
            developer: developer,
            dilution: dilution,
            temperature: temperature,
            developmentTime: developmentTime,
            agitation: agitation,
            notes: notes
        )
    }
    
    static func from(_ info: DevelopmentInfo) -> DevelopmentInfoModel {
        DevelopmentInfoModel(
            developer: info.developer,
            dilution: info.dilution,
            temperature: info.temperature,
            developmentTime: info.developmentTime,
            agitation: info.agitation,
            notes: info.notes
        )
    }
}

// MARK: - User Preferences Model

@Model
final class UserPreferencesModel {
    @Attribute(.unique) var id: String = "default"
    
    var themeRaw: String
    var experienceLevelRaw: String
    var defaultFormatRaw: String
    var defaultEmulsionRaw: String
    var temperatureUnitRaw: String
    var hapticFeedbackEnabled: Bool
    var soundEffectsEnabled: Bool
    var darkroomSafeColorRaw: String
    
    var isProUnlocked: Bool
    var proPurchaseDate: Date?
    
    init(
        theme: AppTheme = .system,
        experienceLevel: UserExperienceLevel = .beginner,
        defaultFormat: FilmFormat = .mm35,
        defaultEmulsion: FilmEmulsion = .ilfordHP5,
        temperatureUnit: TemperatureUnit = .celsius,
        hapticFeedbackEnabled: Bool = true,
        soundEffectsEnabled: Bool = true,
        darkroomSafeColor: DarkroomSafeColor = .red,
        isProUnlocked: Bool = false,
        proPurchaseDate: Date? = nil
    ) {
        self.themeRaw = theme.rawValue
        self.experienceLevelRaw = experienceLevel.rawValue
        self.defaultFormatRaw = defaultFormat.rawValue
        self.defaultEmulsionRaw = defaultEmulsion.rawValue
        self.temperatureUnitRaw = temperatureUnit.rawValue
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.soundEffectsEnabled = soundEffectsEnabled
        self.darkroomSafeColorRaw = darkroomSafeColor.rawValue
        self.isProUnlocked = isProUnlocked
        self.proPurchaseDate = proPurchaseDate
    }
    
    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }
    
    var experienceLevel: UserExperienceLevel {
        get { UserExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner }
        set { experienceLevelRaw = newValue.rawValue }
    }
    
    var defaultFormat: FilmFormat {
        get { FilmFormat(rawValue: defaultFormatRaw) ?? .mm35 }
        set { defaultFormatRaw = newValue.rawValue }
    }
    
    var defaultEmulsion: FilmEmulsion {
        get { FilmEmulsion(rawValue: defaultEmulsionRaw) ?? .ilfordHP5 }
        set { defaultEmulsionRaw = newValue.rawValue }
    }
    
    var temperatureUnit: TemperatureUnit {
        get { TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius }
        set { temperatureUnitRaw = newValue.rawValue }
    }
    
    var darkroomSafeColor: DarkroomSafeColor {
        get { DarkroomSafeColor(rawValue: darkroomSafeColorRaw) ?? .red }
        set { darkroomSafeColorRaw = newValue.rawValue }
    }
}

// MARK: - Custom Emulsion Model (PRO Feature)

@Model
final class CustomEmulsionModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var iso: Int
    var contrastIndex: Double
    var dMax: Double
    var dMin: Double
    var curvePointsData: Data
    var notes: String
    var dateCreated: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        iso: Int,
        contrastIndex: Double,
        dMax: Double = 2.5,
        dMin: Double = 0.15,
        curvePoints: [CurvePoint] = [],
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.iso = iso
        self.contrastIndex = contrastIndex
        self.dMax = dMax
        self.dMin = dMin
        self.notes = notes
        self.dateCreated = Date()
        
        // Encode curve points
        let encoder = JSONEncoder()
        self.curvePointsData = (try? encoder.encode(curvePoints)) ?? Data()
    }
    
    var curvePoints: [CurvePoint] {
        get {
            let decoder = JSONDecoder()
            return (try? decoder.decode([CurvePoint].self, from: curvePointsData)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            curvePointsData = (try? encoder.encode(newValue)) ?? Data()
        }
    }
    
    func toCharacteristicCurve() -> CharacteristicCurve {
        CharacteristicCurve(
            emulsion: .ilfordHP5, // Placeholder
            points: curvePoints,
            gamma: contrastIndex,
            dMax: dMax,
            dMin: dMin
        )
    }
}

// MARK: - Print Profile Model (PRO Feature)

@Model
final class PrintProfileModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var paperTypeRaw: String
    var contrastGrade: Int
    var exposureTime: TimeInterval
    var aperture: Double
    var dodgeBurnMasksData: Data
    var notes: String
    var dateCreated: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        paperType: PaperType,
        contrastGrade: Int,
        exposureTime: TimeInterval,
        aperture: Double,
        dodgeBurnMasks: [DodgeBurnMask] = [],
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.paperTypeRaw = paperType.rawValue
        self.contrastGrade = contrastGrade
        self.exposureTime = exposureTime
        self.aperture = aperture
        self.notes = notes
        self.dateCreated = Date()
        
        // Encode masks
        let encoder = JSONEncoder()
        self.dodgeBurnMasksData = (try? encoder.encode(dodgeBurnMasks)) ?? Data()
    }
    
    var paperType: PaperType {
        get { PaperType(rawValue: paperTypeRaw) ?? .ilfordMultigradeIV }
        set { paperTypeRaw = newValue.rawValue }
    }
    
    var dodgeBurnMasks: [DodgeBurnMask] {
        get {
            let decoder = JSONDecoder()
            return (try? decoder.decode([DodgeBurnMask].self, from: dodgeBurnMasksData)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            dodgeBurnMasksData = (try? encoder.encode(newValue)) ?? Data()
        }
    }
}

// MARK: - Codable Extensions

extension CurvePoint: Codable {
    enum CodingKeys: String, CodingKey {
        case logE
        case density
    }
}

extension DodgeBurnMask: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case rect
        case intensity
        case isDodge
        case feather
    }
}

extension CGRect: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let width = try container.decode(Double.self, forKey: .width)
        let height = try container.decode(Double.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
    
    enum CodingKeys: String, CodingKey {
        case x
        case y
        case width
        case height
    }
}

// MARK: - Model Context Extensions

extension ModelContext {
    func fetchFilmRolls() throws -> [FilmRollModel] {
        let descriptor = FetchDescriptor<FilmRollModel>(
            sortBy: [SortDescriptor(\.dateLoaded, order: .reverse)]
        )
        return try fetch(descriptor)
    }
    
    func fetchRoll(by id: UUID) throws -> FilmRollModel? {
        let descriptor = FetchDescriptor<FilmRollModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try fetch(descriptor).first
    }
    
    func fetchUserPreferences() throws -> UserPreferencesModel? {
        let descriptor = FetchDescriptor<UserPreferencesModel>(
            predicate: #Predicate { $0.id == "default" }
        )
        return try fetch(descriptor).first
    }
    
    func saveUserPreferences(_ preferences: UserPreferencesModel) throws {
        insert(preferences)
        try save()
    }
}
