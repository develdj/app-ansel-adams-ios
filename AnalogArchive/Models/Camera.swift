import Foundation

// MARK: - Camera (Value Type)
/// Rappresenta una macchina fotografica
struct Camera: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var brand: String
    var model: String
    var type: CameraType
    var mount: LensMount
    var format: FilmFormat
    var year: Int?
    var serialNumber: String?
    var description: String
    var isActive: Bool
    var dateAdded: Date
    
    init(
        id: UUID = UUID(),
        brand: String,
        model: String,
        type: CameraType,
        mount: LensMount,
        format: FilmFormat,
        year: Int? = nil,
        serialNumber: String? = nil,
        description: String = "",
        isActive: Bool = true,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.type = type
        self.mount = mount
        self.format = format
        self.year = year
        self.serialNumber = serialNumber
        self.description = description
        self.isActive = isActive
        self.dateAdded = dateAdded
    }
    
    var displayName: String {
        "\(brand) \(model)"
    }
    
    var fullDescription: String {
        var desc = "\(displayName)"
        if let year = year {
            desc += " (\(year))"
        }
        desc += " - \(format.rawValue)"
        return desc
    }
}

// MARK: - Camera Type
enum CameraType: String, Codable, CaseIterable, Sendable {
    case slr = "Reflex"
    case rangefinder = "Telemetro"
    case viewCamera = "Banco ottico"
    case twinLens = "Bifocale"
    case pointShoot = "Point & Shoot"
    case panoramic = "Panoramica"
    case halfFrame = "Mezzo formato"
    case pinhole = "Foro stenopeico"
    case instant = "Istantanea"
    case mediumFormatSLR = "Medio formato Reflex"
    case folding = "Soffietto"
    case box = "Box"
    case other = "Altro"
    
    var icon: String {
        switch self {
        case .slr: return "camera.fill"
        case .rangefinder: return "viewfinder.rectangular"
        case .viewCamera: return "rectangle.on.rectangle"
        case .twinLens: return "camera.on.rectangle"
        case .pointShoot: return "camera.circle"
        case .panoramic: return "panorama.fill"
        case .halfFrame: return "square.split.2x1"
        case .pinhole: return "circle.dashed"
        case .instant: return "photo.stack"
        case .mediumFormatSLR: return "camera.badge.clock"
        case .folding: return "rectangle.compress.vertical"
        case .box: return "square.fill"
        case .other: return "camera"
        }
    }
}

// MARK: - Lens Mount
enum LensMount: String, Codable, CaseIterable, Sendable {
    // 35mm
    case canonFD = "Canon FD"
    case canonEF = "Canon EF"
    case canonRF = "Canon RF"
    case nikonF = "Nikon F"
    case nikonZ = "Nikon Z"
    case sonyE = "Sony E"
    case sonyA = "Sony A"
    case leicaM = "Leica M"
    case leicaR = "Leica R"
    case leicaL = "Leica L"
    case m42 = "M42"
    case pentaxK = "Pentax K"
    case pentax645 = "Pentax 645"
    case pentax67 = "Pentax 67"
    case olympusOM = "Olympus OM"
    case minoltaMD = "Minolta MD"
    case contaxYashica = "Contax/Yashica"
    case contaxG = "Contax G"
    case contax645 = "Contax 645"
    case hasselbladV = "Hasselblad V"
    case hasselbladX = "Hasselblad X"
    case mamiya645 = "Mamiya 645"
    case mamiyaRB = "Mamiya RB"
    case mamiyaRZ = "Mamiya RZ"
    case bronicaSQ = "Bronica SQ"
    case bronicaGS = "Bronica GS"
    case bronicaETR = "Bronica ETR"
    case fujiGX = "Fuji GX"
    case plaubelMakina = "Plaubel Makina"
    case rolleiSL66 = "Rollei SL66"
    case rolleiSLX = "Rollei SLX"
    case exakta = "Exakta"
    case praktica = "Praktica"
    case kyocera = "Kyocera"
    case fixed = "Obiettivo fisso"
    case interchangeable = "Intercambiabile (vario)"
    case largeFormat = "Grande formato"
    case other = "Altro"
    
    var isFixed: Bool {
        self == .fixed
    }
    
    var isLargeFormat: Bool {
        self == .largeFormat
    }
}

// MARK: - Lens (Value Type)
/// Rappresenta un obiettivo fotografico
struct Lens: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var brand: String
    var model: String
    var mount: LensMount
    var focalLength: FocalLength
    var maxAperture: Aperture
    var minAperture: Aperture
    var hasApertureRing: Bool
    var isManualFocus: Bool
    var hasImageStabilization: Bool
    var filterThread: Int? // mm
    var weight: Int? // grams
    var year: Int?
    var serialNumber: String?
    var description: String
    var isActive: Bool
    var dateAdded: Date
    
    init(
        id: UUID = UUID(),
        brand: String,
        model: String,
        mount: LensMount,
        focalLength: FocalLength,
        maxAperture: Aperture,
        minAperture: Aperture = Aperture(fStop: 22),
        hasApertureRing: Bool = true,
        isManualFocus: Bool = true,
        hasImageStabilization: Bool = false,
        filterThread: Int? = nil,
        weight: Int? = nil,
        year: Int? = nil,
        serialNumber: String? = nil,
        description: String = "",
        isActive: Bool = true,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.mount = mount
        self.focalLength = focalLength
        self.maxAperture = maxAperture
        self.minAperture = minAperture
        self.hasApertureRing = hasApertureRing
        self.isManualFocus = isManualFocus
        self.hasImageStabilization = hasImageStabilization
        self.filterThread = filterThread
        self.weight = weight
        self.year = year
        self.serialNumber = serialNumber
        self.description = description
        self.isActive = isActive
        self.dateAdded = dateAdded
    }
    
    var displayName: String {
        "\(brand) \(model)"
    }
    
    var fullDescription: String {
        "\(displayName) \(focalLength.displayString) f/\(maxAperture.displayString)"
    }
}

// MARK: - Focal Length
struct FocalLength: Codable, Hashable, Sendable {
    var min: Int
    var max: Int?
    
    init(min: Int, max: Int? = nil) {
        self.min = min
        self.max = max
    }
    
    init(fixed: Int) {
        self.min = fixed
        self.max = nil
    }
    
    var isZoom: Bool {
        max != nil
    }
    
    var displayString: String {
        if let max = max {
            return "\(min)-\(max)mm"
        } else {
            return "\(min)mm"
        }
    }
    
    var equivalent35mm: Int {
        min // Simplified - would need crop factor
    }
}

// MARK: - Aperture
struct Aperture: Codable, Hashable, Sendable, Comparable {
    var fStop: Double
    
    init(fStop: Double) {
        self.fStop = fStop
    }
    
    var displayString: String {
        if fStop == floor(fStop) {
            return String(format: "%.0f", fStop)
        } else {
            return String(format: "%.1f", fStop)
        }
    }
    
    static func < (lhs: Aperture, rhs: Aperture) -> Bool {
        lhs.fStop < rhs.fStop
    }
    
    /// Standard f-stop values
    static let standardStops: [Double] = [1.0, 1.2, 1.4, 1.8, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0, 32.0, 45.0, 64.0]
    
    /// Full stop increments
    static let fullStops: [Aperture] = [1.4, 2, 2.8, 4, 5.6, 8, 11, 16, 22].map { Aperture(fStop: $0) }
    
    /// Half stop increments
    static let halfStops: [Aperture] = [1.4, 1.7, 2, 2.4, 2.8, 3.3, 4, 4.8, 5.6, 6.7, 8, 9.5, 11, 13, 16, 19, 22].map { Aperture(fStop: $0) }
    
    /// Third stop increments
    static let thirdStops: [Aperture] = [1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5, 4, 4.5, 5.0, 5.6, 6.3, 7.1, 8, 9, 10, 11, 13, 14, 16, 18, 20, 22].map { Aperture(fStop: $0) }
}

// MARK: - Shutter Speed
struct ShutterSpeed: Codable, Hashable, Sendable, Comparable {
    var seconds: Double
    
    init(seconds: Double) {
        self.seconds = seconds
    }
    
    init(fraction: Int) {
        self.seconds = 1.0 / Double(fraction)
    }
    
    var isFraction: Bool {
        seconds < 1.0 && seconds > 0
    }
    
    var displayString: String {
        if seconds >= 1.0 {
            if seconds == floor(seconds) {
                return String(format: "%.0f\"", seconds)
            } else {
                return String(format: "%.1f\"", seconds)
            }
        } else if seconds == 0 {
            return "Bulb"
        } else {
            let fraction = Int(round(1.0 / seconds))
            return "1/\(fraction)"
        }
    }
    
    var isHandholdable: Bool {
        seconds >= 1.0 / 60.0
    }
    
    static func < (lhs: ShutterSpeed, rhs: ShutterSpeed) -> Bool {
        lhs.seconds < rhs.seconds
    }
    
    /// Standard shutter speeds
    static let standardSpeeds: [ShutterSpeed] = [
        ShutterSpeed(seconds: 1),
        ShutterSpeed(fraction: 2),
        ShutterSpeed(fraction: 4),
        ShutterSpeed(fraction: 8),
        ShutterSpeed(fraction: 15),
        ShutterSpeed(fraction: 30),
        ShutterSpeed(fraction: 60),
        ShutterSpeed(fraction: 125),
        ShutterSpeed(fraction: 250),
        ShutterSpeed(fraction: 500),
        ShutterSpeed(fraction: 1000),
        ShutterSpeed(fraction: 2000),
        ShutterSpeed(fraction: 4000),
        ShutterSpeed(fraction: 8000)
    ]
    
    static let bulb = ShutterSpeed(seconds: 0)
}

// MARK: - Filter
struct Filter: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var brand: String
    var model: String
    var type: FilterType
    var size: Int // mm
    var description: String
    
    init(
        id: UUID = UUID(),
        brand: String,
        model: String,
        type: FilterType,
        size: Int,
        description: String = ""
    ) {
        self.id = id
        self.brand = brand
        self.model = model
        self.type = type
        self.size = size
        self.description = description
    }
    
    var displayName: String {
        "\(brand) \(model) \(size)mm"
    }
}

enum FilterType: String, Codable, CaseIterable, Sendable {
    case uv = "UV"
    case skylight = "Skylight"
    case protection = "Protezione"
    case polarizer = "Polarizzatore"
    case nd = "ND"
    case ndGrad = "ND Graduato"
    case warming = "Riscaldante"
    case cooling = "Raffreddante"
    case red = "Rosso"
    case orange = "Arancio"
    case yellow = "Giallo"
    case green = "Verde"
    case blue = "Blu"
    case infrared = "Infrarosso"
    case diffusion = "Diffusione"
    case softFocus = "Soft Focus"
    case star = "Star"
    case closeUp = "Close-up"
    case other = "Altro"
    
    var displayName: String {
        rawValue
    }
    
    var affectsExposure: Bool {
        switch self {
        case .nd, .ndGrad, .polarizer, .red, .orange, .yellow, .green, .blue, .infrared:
            return true
        default:
            return false
        }
    }
    
    var typicalStops: Double {
        switch self {
        case .uv, .skylight, .protection:
            return 0
        case .polarizer:
            return 1.5
        case .nd:
            return 0 // Varies by strength
        case .ndGrad:
            return 0 // Varies by strength
        case .red:
            return 2
        case .orange:
            return 1.5
        case .yellow:
            return 1
        case .green:
            return 2
        case .blue:
            return 2
        case .infrared:
            return 4
        default:
            return 0
        }
    }
}

// MARK: - Light Condition
enum LightCondition: String, Codable, CaseIterable, Sendable {
    case brightSun = "Sole pieno"
    case hazySun = "Sole velato"
    case cloudyBright = "Nuvoloso luminoso"
    case cloudy = "Nuvoloso"
    case heavyOvercast = "Cielo coperto"
    case openShade = "Ombra aperta"
    case deepShade = "Ombra profonda"
    case sunset = "Tramonto"
    case twilight = "Crepuscolo"
    case night = "Notte"
    case indoorBright = "Interno luminoso"
    case indoorNormal = "Interno normale"
    case indoorDim = "Interno scarsamente illuminato"
    case stage = "Palcoscenico"
    case studio = "Studio"
    case other = "Altro"
    
    var ev100: Int {
        switch self {
        case .brightSun: return 15
        case .hazySun: return 14
        case .cloudyBright: return 13
        case .cloudy: return 12
        case .heavyOvercast: return 11
        case .openShade: return 11
        case .deepShade: return 10
        case .sunset: return 10
        case .twilight: return 8
        case .night: return 5
        case .indoorBright: return 10
        case .indoorNormal: return 8
        case .indoorDim: return 5
        case .stage: return 8
        case .studio: return 10
        case .other: return 10
        }
    }
    
    var icon: String {
        switch self {
        case .brightSun: return "sun.max.fill"
        case .hazySun: return "sun.min.fill"
        case .cloudyBright: return "cloud.sun.fill"
        case .cloudy: return "cloud.fill"
        case .heavyOvercast: return "cloud.rain.fill"
        case .openShade: return "cloud.sun.rain.fill"
        case .deepShade: return "cloud.moon.fill"
        case .sunset: return "sun.horizon.fill"
        case .twilight: return "moon.stars.fill"
        case .night: return "moon.fill"
        case .indoorBright, .indoorNormal, .indoorDim: return "lightbulb.fill"
        case .stage: return "theatermasks.fill"
        case .studio: return "camera.aperture"
        case .other: return "questionmark.circle"
        }
    }
}
