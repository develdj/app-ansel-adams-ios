import Foundation

// MARK: - Film Stock (Value Type)
/// Rappresenta una marca e tipo di pellicola fotografica
struct FilmStock: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var manufacturer: FilmManufacturer
    var name: String
    var iso: Int
    var format: FilmFormat
    var type: FilmType
    var description: String
    var characteristics: FilmCharacteristics
    
    init(
        id: UUID = UUID(),
        manufacturer: FilmManufacturer,
        name: String,
        iso: Int,
        format: FilmFormat,
        type: FilmType,
        description: String = "",
        characteristics: FilmCharacteristics = FilmCharacteristics()
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.name = name
        self.iso = iso
        self.format = format
        self.type = type
        self.description = description
        self.characteristics = characteristics
    }
    
    /// Pellicole predefinite comuni
    static let predefinedStocks: [FilmStock] = [
        // Ilford
        FilmStock(manufacturer: .ilford, name: "HP5 Plus", iso: 400, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN versatile, grana fine, ampia latitudine",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .medium, latitude: .wide)),
        FilmStock(manufacturer: .ilford, name: "FP4 Plus", iso: 125, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN a bassa sensibilità, grana molto fine",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .medium, latitude: .wide)),
        FilmStock(manufacturer: .ilford, name: "Delta 100", iso: 100, format: .mm35, type: .blackWhite,
                 description: "Pellicola T-grain moderna, massima nitidezza",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .mediumHigh, latitude: .normal)),
        FilmStock(manufacturer: .ilford, name: "Delta 400", iso: 400, format: .mm35, type: .blackWhite,
                 description: "Pellicola T-grain ad alta sensibilità",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .mediumHigh, latitude: .normal)),
        FilmStock(manufacturer: .ilford, name: "Delta 3200", iso: 3200, format: .mm35, type: .blackWhite,
                 description: "Pellicola T-grain per condizioni di luce estrema",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .high, latitude: .narrow)),
        FilmStock(manufacturer: .ilford, name: "Pan F Plus", iso: 50, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN a bassissima sensibilità, grana invisibile",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .high, latitude: .narrow)),
        FilmStock(manufacturer: .ilford, name: "SFX 200", iso: 200, format: .mm35, type: .blackWhite,
                 description: "Pellicola sensibile agli infrarossi",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .high, latitude: .normal)),
        
        // Kodak
        FilmStock(manufacturer: .kodak, name: "Tri-X 400", iso: 400, format: .mm35, type: .blackWhite,
                 description: "Classico giornalistico, grana caratteristica",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .mediumHigh, latitude: .wide)),
        FilmStock(manufacturer: .kodak, name: "T-Max 100", iso: 100, format: .mm35, type: .blackWhite,
                 description: "Pellicola T-grain, grana invisibile",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .medium, latitude: .normal)),
        FilmStock(manufacturer: .kodak, name: "T-Max 400", iso: 400, format: .mm35, type: .blackWhite,
                 description: "Pellicola T-grain ad alta sensibilità",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .medium, latitude: .normal)),
        FilmStock(manufacturer: .kodak, name: "T-Max P3200", iso: 3200, format: .mm35, type: .blackWhite,
                 description: "Pellicola T-grain per condizioni di luce estrema",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .high, latitude: .narrow)),
        FilmStock(manufacturer: .kodak, name: "Portra 160", iso: 160, format: .mm35, type: .colorNegative,
                 description: "Pellicola colore professionale, toni pelle naturali",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .low, latitude: .veryWide)),
        FilmStock(manufacturer: .kodak, name: "Portra 400", iso: 400, format: .mm35, type: .colorNegative,
                 description: "Pellicola colore professionale versatile",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .low, latitude: .veryWide)),
        FilmStock(manufacturer: .kodak, name: "Portra 800", iso: 800, format: .mm35, type: .colorNegative,
                 description: "Pellicola colore ad alta sensibilità",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .low, latitude: .wide)),
        FilmStock(manufacturer: .kodak, name: "Ektar 100", iso: 100, format: .mm35, type: .colorNegative,
                 description: "Pellicola colore vivida, saturazione elevata",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .mediumHigh, latitude: .normal)),
        FilmStock(manufacturer: .kodak, name: "Gold 200", iso: 200, format: .mm35, type: .colorNegative,
                 description: "Pellicola colore consumer, versatile",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .medium, latitude: .normal)),
        FilmStock(manufacturer: .kodak, name: "ColorPlus 200", iso: 200, format: .mm35, type: .colorNegative,
                 description: "Pellicola colore economica, toni caldi",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .medium, latitude: .normal)),
        FilmStock(manufacturer: .kodak, name: "Ektachrome E100", iso: 100, format: .mm35, type: .colorSlide,
                 description: "Diapositiva colore professionale",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .high, latitude: .narrow)),
        
        // Fujifilm
        FilmStock(manufacturer: .fujifilm, name: "Acros 100 II", iso: 100, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN con risposta straordinaria alle luci",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .medium, latitude: .wide)),
        FilmStock(manufacturer: .fujifilm, name: "Superia X-tra 400", iso: 400, format: .mm35, type: .colorNegative,
                 description: "Pellicola colore consumer versatile",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .medium, latitude: .normal)),
        FilmStock(manufacturer: .fujifilm, name: "Pro 400H", iso: 400, format: .mm35, type: .colorNegative,
                 description: "Pellicola colore professionale, toni pelle eccellenti",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .low, latitude: .veryWide)),
        FilmStock(manufacturer: .fujifilm, name: "Velvia 50", iso: 50, format: .mm35, type: .colorSlide,
                 description: "Diapositiva con saturazione estrema",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .veryHigh, latitude: .narrow)),
        FilmStock(manufacturer: .fujifilm, name: "Provia 100F", iso: 100, format: .mm35, type: .colorSlide,
                 description: "Diapositiva colore professionale bilanciata",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .mediumHigh, latitude: .normal)),
        
        // Foma
        FilmStock(manufacturer: .foma, name: "Fomapan 100", iso: 100, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN economica, grana tradizionale",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .medium, latitude: .normal)),
        FilmStock(manufacturer: .foma, name: "Fomapan 200", iso: 200, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN versatile, buon rapporto qualità/prezzo",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .medium, latitude: .normal)),
        FilmStock(manufacturer: .foma, name: "Fomapan 400", iso: 400, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN ad alta sensibilità, economica",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .mediumHigh, latitude: .normal)),
        FilmStock(manufacturer: .foma, name: "Retropan 320", iso: 320, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN effetto vintage",
                 characteristics: FilmCharacteristics(grain: .coarse, contrast: .high, latitude: .narrow)),
        
        // Adox
        FilmStock(manufacturer: .adox, name: "Silvermax 100", iso: 100, format: .mm35, type: .blackWhite,
                 description: "Pellicola con emulsione antica, alta risoluzione",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .mediumHigh, latitude: .normal)),
        FilmStock(manufacturer: .adox, name: "HR-50", iso: 50, format: .mm35, type: .blackWhite,
                 description: "Pellicola a bassissima sensibilità, grana invisibile",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .medium, latitude: .normal)),
        
        // Rollei
        FilmStock(manufacturer: .rollei, name: "Retro 80S", iso: 80, format: .mm35, type: .blackWhite,
                 description: "Pellicola effetto vintage, sensibilità spettrale estesa",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .high, latitude: .normal)),
        FilmStock(manufacturer: .rollei, name: "Retro 400S", iso: 400, format: .mm35, type: .blackWhite,
                 description: "Pellicola ad alta sensibilità, effetto vintage",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .high, latitude: .normal)),
        FilmStock(manufacturer: .rollei, name: "Ortho 25", iso: 25, format: .mm35, type: .blackWhite,
                 description: "Pellicola ortocromatica, sensibile solo a blu e verde",
                 characteristics: FilmCharacteristics(grain: .veryFine, contrast: .veryHigh, latitude: .narrow)),
        
        // Cinestill
        FilmStock(manufacturer: .cinestill, name: "800T", iso: 800, format: .mm35, type: .colorNegative,
                 description: "Pellicola da cinema tungsteno, halation caratteristico",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .medium, latitude: .wide)),
        FilmStock(manufacturer: .cinestill, name: "400D", iso: 400, format: .mm35, type: .colorNegative,
                 description: "Pellicola da cinema daylight",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .medium, latitude: .wide)),
        
        // Kentmere
        FilmStock(manufacturer: .kentmere, name: "400", iso: 400, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN economica, versatile",
                 characteristics: FilmCharacteristics(grain: .medium, contrast: .medium, latitude: .normal)),
        FilmStock(manufacturer: .kentmere, name: "100", iso: 100, format: .mm35, type: .blackWhite,
                 description: "Pellicola BN economica a bassa sensibilità",
                 characteristics: FilmCharacteristics(grain: .fine, contrast: .medium, latitude: .normal)),
    ]
    
    var displayName: String {
        "\(manufacturer.rawValue) \(name)"
    }
    
    var fullDescription: String {
        "\(displayName) ISO \(iso) - \(format.rawValue) - \(type.displayName)"
    }
}

// MARK: - Film Manufacturer
enum FilmManufacturer: String, Codable, CaseIterable, Sendable {
    case ilford = "Ilford"
    case kodak = "Kodak"
    case fujifilm = "Fujifilm"
    case foma = "Foma"
    case adox = "Adox"
    case rollei = "Rollei"
    case cinestill = "Cinestill"
    case kentmere = "Kentmere"
    case agfa = "Agfa"
    case lomography = "Lomography"
    case bergger = "Bergger"
    case jch = "JCH"
    case orwo = "ORWO"
    case other = "Altro"
}

// MARK: - Film Format
enum FilmFormat: String, Codable, CaseIterable, Sendable {
    case mm35 = "35mm"
    case mm120 = "120"
    case mm220 = "220"
    case sheet4x5 = "4x5"
    case sheet5x7 = "5x7"
    case sheet8x10 = "8x10"
    case sheet11x14 = "11x14"
    case halfFrame = "Half Frame"
    case panoramic = "Panoramic"
    case disc = "Disc"
    case aps = "APS"
    case minox = "Minox"
    case other = "Altro"
    
    var framesPerRoll: Int? {
        switch self {
        case .mm35: return 36
        case .mm120: return 12
        case .mm220: return 24
        case .halfFrame: return 72
        case .aps: return 25
        default: return nil
        }
    }
    
    var frameSize: String {
        switch self {
        case .mm35: return "24×36mm"
        case .mm120: return "6×6cm / 6×7cm"
        case .mm220: return "6×6cm / 6×7cm"
        case .sheet4x5: return "4×5 inch"
        case .sheet5x7: return "5×7 inch"
        case .sheet8x10: return "8×10 inch"
        case .halfFrame: return "18×24mm"
        default: return "Variabile"
        }
    }
}

// MARK: - Film Type
enum FilmType: String, Codable, CaseIterable, Sendable {
    case blackWhite = "BN"
    case colorNegative = "Colore Negativo"
    case colorSlide = "Diapositiva"
    case infrared = "Infrarosso"
    case orthochromatic = "Ortocromatica"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .blackWhite: return "circle.righthalf.filled"
        case .colorNegative: return "photo.fill"
        case .colorSlide: return "film.fill"
        case .infrared: return "eye.slash.fill"
        case .orthochromatic: return "circle.lefthalf.filled"
        }
    }
    
    var color: String {
        switch self {
        case .blackWhite: return "gray"
        case .colorNegative: return "orange"
        case .colorSlide: return "blue"
        case .infrared: return "purple"
        case .orthochromatic: return "cyan"
        }
    }
}

// MARK: - Film Characteristics
struct FilmCharacteristics: Codable, Hashable, Sendable {
    var grain: GrainSize
    var contrast: ContrastLevel
    var latitude: ExposureLatitude
    
    init(grain: GrainSize = .medium, contrast: ContrastLevel = .medium, latitude: ExposureLatitude = .normal) {
        self.grain = grain
        self.contrast = contrast
        self.latitude = latitude
    }
}

enum GrainSize: String, Codable, CaseIterable, Sendable {
    case veryFine = "Invisibile"
    case fine = "Fine"
    case medium = "Media"
    case coarse = "Grana grossa"
    case veryCoarse = "Molto granulosa"
}

enum ContrastLevel: String, Codable, CaseIterable, Sendable {
    case veryLow = "Molto basso"
    case low = "Basso"
    case medium = "Medio"
    case mediumHigh = "Medio-alto"
    case high = "Alto"
    case veryHigh = "Molto alto"
}

enum ExposureLatitude: String, Codable, CaseIterable, Sendable {
    case veryWide = "Ampissima (+/- 3 stop)"
    case wide = "Ampia (+/- 2 stop)"
    case normal = "Normale (+/- 1 stop)"
    case narrow = "Ridotta (+/- 0.5 stop)"
    case veryNarrow = "Molto ridotta"
}
