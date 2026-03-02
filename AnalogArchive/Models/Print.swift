import Foundation
import SwiftData

// MARK: - Print (SwiftData Model)
/// Rappresenta una stampa analogica da un negativo
@Model
final class Print {
    // MARK: - Identificazione
    @Attribute(.unique) var id: UUID
    var printNumber: String // Numero identificativo della stampa
    var title: String
    var notes: String
    
    // MARK: - Relazione con Exposure
    var exposure: Exposure?
    
    // MARK: - Data
    var datePrinted: Date
    var printSessionId: UUID? // Per raggruppare stampe della stessa sessione
    
    // MARK: - Attrezzatura stampa
    var enlargerBrand: String
    var enlargerModel: String
    var enlargerLens: String
    var enlargerLensFocalLength: Int? // mm
    
    // MARK: - Ingrandimento
    var magnification: Double // 1.0 = ingrandimento 1:1
    var negativeCarrier: String?
    
    // MARK: - Carta
    var paperBrand: String
    var paperModel: String
    var paperType: PaperType
    var paperGrade: PaperGrade
    var paperSize: PaperSize
    
    // MARK: - Filtri
    var filterSet: String? // Multigrade, etc.
    var filterValues: String? // Es. "2.5" o "M 35 Y 15"
    var splitGrade: Bool
    var splitGradeLow: String?
    var splitGradeHigh: String?
    var splitGradeTimes: (low: TimeInterval, high: TimeInterval)?
    
    // MARK: - Esposizione carta
    var baseExposureTime: TimeInterval
    var testStripExposure: TimeInterval?
    var aperture: Double // f-stop dell'ingranditore
    var lensHeight: Double? // cm
    
    // MARK: - Sviluppo carta
    var developerName: String
    var developerDilution: String
    var developmentTime: TimeInterval
    var developmentTemperature: Double? // Celsius
    
    // MARK: - Stop, fissaggio, lavaggio
    var stopBathTime: TimeInterval?
    var fixerName: String
    var fixerTime: TimeInterval
    var washTime: TimeInterval
    var hypoClearTime: TimeInterval?
    var wettingAgent: String?
    
    // MARK: - Dodge e Burn
    @Relationship(deleteRule: .cascade)
    var dodgeBurnOperations: [DodgeBurnOperation]?
    
    // MARK: - Valutazione
    var printRating: PrintRating
    var isFinalPrint: Bool
    var isToned: Bool
    var tonerName: String?
    var tonerTime: TimeInterval?
    
    // MARK: - Archiviazione
    var printLocation: String?
    var isMounted: Bool
    var mountSize: String?
    var isSigned: Bool
    var editionNumber: String? // "1/10", etc.
    
    // MARK: - Metadati
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool
    
    // MARK: - Computed Properties
    var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        return "Stampa #\(printNumber)"
    }
    
    var magnificationDisplay: String {
        if magnification == 1.0 {
            return "1:1 (Contatto)"
        } else if magnification < 1.0 {
            return String(format: "1:%.1f", 1.0 / magnification)
        } else {
            return String(format: "%.1fx", magnification)
        }
    }
    
    var paperFullName: String {
        "\(paperBrand) \(paperModel) \(paperGrade.displayName)"
    }
    
    var totalWetTime: TimeInterval {
        var total = developmentTime + fixerTime + washTime
        if let stop = stopBathTime { total += stop }
        if let hypo = hypoClearTime { total += hypo }
        return total
    }
    
    var totalWetTimeFormatted: String {
        let minutes = Int(totalWetTime) / 60
        let seconds = Int(totalWetTime) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var baseExposureFormatted: String {
        let seconds = Int(baseExposureTime)
        if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            return "\(mins)m \(secs)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var hasDodgeBurn: Bool {
        guard let ops = dodgeBurnOperations else { return false }
        return !ops.isEmpty
    }
    
    var dodgeBurnCount: Int {
        dodgeBurnOperations?.count ?? 0
    }
    
    var splitGradeDisplay: String {
        if !splitGrade {
            return "Stampa singolo grado"
        }
        guard let low = splitGradeLow, let high = splitGradeHigh else {
            return "Split grade"
        }
        return "Split: \(low) / \(high)"
    }
    
    var isArchival: Bool {
        washTime >= 1800 // 30 minuti
    }
    
    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        printNumber: String = "",
        exposure: Exposure? = nil,
        title: String = "",
        datePrinted: Date = Date(),
        printSessionId: UUID? = nil,
        enlargerBrand: String = "",
        enlargerModel: String = "",
        enlargerLens: String = "",
        enlargerLensFocalLength: Int? = nil,
        magnification: Double = 2.0,
        negativeCarrier: String? = nil,
        paperBrand: String = "Ilford",
        paperModel: String = "Multigrade IV",
        paperType: PaperType = .rc,
        paperGrade: PaperGrade = .grade2,
        paperSize: PaperSize = .a4,
        filterSet: String? = "Multigrade",
        filterValues: String? = nil,
        splitGrade: Bool = false,
        splitGradeLow: String? = nil,
        splitGradeHigh: String? = nil,
        splitGradeTimes: (low: TimeInterval, high: TimeInterval)? = nil,
        baseExposureTime: TimeInterval = 10,
        testStripExposure: TimeInterval? = nil,
        aperture: Double = 5.6,
        lensHeight: Double? = nil,
        developerName: String = "Ilford Multigrade",
        developerDilution: String = "1+9",
        developmentTime: TimeInterval = 60,
        developmentTemperature: Double? = 20.0,
        stopBathTime: TimeInterval? = 10,
        fixerName: String = "Ilford Rapid Fixer",
        fixerTime: TimeInterval = 60,
        washTime: TimeInterval = 1800,
        hypoClearTime: TimeInterval? = 120,
        wettingAgent: String? = "Ilford Ilfotol",
        printRating: PrintRating = .workPrint,
        isFinalPrint: Bool = false,
        isToned: Bool = false,
        tonerName: String? = nil,
        tonerTime: TimeInterval? = nil,
        printLocation: String? = nil,
        isMounted: Bool = false,
        mountSize: String? = nil,
        isSigned: Bool = false,
        editionNumber: String? = nil,
        notes: String = "",
        isFavorite: Bool = false
    ) {
        self.id = id
        self.printNumber = printNumber
        self.exposure = exposure
        self.title = title
        self.datePrinted = datePrinted
        self.printSessionId = printSessionId
        self.enlargerBrand = enlargerBrand
        self.enlargerModel = enlargerModel
        self.enlargerLens = enlargerLens
        self.enlargerLensFocalLength = enlargerLensFocalLength
        self.magnification = magnification
        self.negativeCarrier = negativeCarrier
        self.paperBrand = paperBrand
        self.paperModel = paperModel
        self.paperType = paperType
        self.paperGrade = paperGrade
        self.paperSize = paperSize
        self.filterSet = filterSet
        self.filterValues = filterValues
        self.splitGrade = splitGrade
        self.splitGradeLow = splitGradeLow
        self.splitGradeHigh = splitGradeHigh
        self.splitGradeTimes = splitGradeTimes
        self.baseExposureTime = baseExposureTime
        self.testStripExposure = testStripExposure
        self.aperture = aperture
        self.lensHeight = lensHeight
        self.developerName = developerName
        self.developerDilution = developerDilution
        self.developmentTime = developmentTime
        self.developmentTemperature = developmentTemperature
        self.stopBathTime = stopBathTime
        self.fixerName = fixerName
        self.fixerTime = fixerTime
        self.washTime = washTime
        self.hypoClearTime = hypoClearTime
        self.wettingAgent = wettingAgent
        self.printRating = printRating
        self.isFinalPrint = isFinalPrint
        self.isToned = isToned
        self.tonerName = tonerName
        self.tonerTime = tonerTime
        self.printLocation = printLocation
        self.isMounted = isMounted
        self.mountSize = mountSize
        self.isSigned = isSigned
        self.editionNumber = editionNumber
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isFavorite = isFavorite
    }
    
    // MARK: - Methods
    func updateTimestamp() {
        updatedAt = Date()
    }
    
    func addDodgeBurn(_ operation: DodgeBurnOperation) {
        if dodgeBurnOperations == nil {
            dodgeBurnOperations = []
        }
        dodgeBurnOperations?.append(operation)
        operation.print = self
        updateTimestamp()
    }
    
    func removeDodgeBurn(_ operation: DodgeBurnOperation) {
        dodgeBurnOperations?.removeAll { $0.id == operation.id }
        updateTimestamp()
    }
    
    func calculatePrintSize() -> (width: Double, height: Double)? {
        guard let exposure = exposure else { return nil }
        
        let format = exposure.roll?.format ?? .mm35
        let (negWidth, negHeight): (Double, Double)
        
        switch format {
        case .mm35:
            negWidth = 36.0
            negHeight = 24.0
        case .mm120:
            // Assume 6x6
            negWidth = 56.0
            negHeight = 56.0
        case .sheet4x5:
            negWidth = 102.0
            negHeight = 127.0
        default:
            negWidth = 36.0
            negHeight = 24.0
        }
        
        let printWidth = negWidth * magnification
        let printHeight = negHeight * magnification
        
        return (width: printWidth, height: printHeight)
    }
}

// MARK: - Paper Type
enum PaperType: String, Codable, CaseIterable, Sendable {
    case rc = "RC (Resina)"
    case fiber = "FB (Baritata)"
    case rcPearl = "RC Perlata"
    case rcGlossy = "RC Lucida"
    case rcMatte = "RC Opaca"
    case fiberGlossy = "FB Lucida"
    case fiberMatte = "FB Opaca"
    case fiberSatin = "FB Satinata"
    case fiberPearl = "FB Perlata"
    case warmTone = "Tono caldo"
    case coolTone = "Tono freddo"
    case variable = "Tono variabile"
    
    var isFiber: Bool {
        switch self {
        case .fiber, .fiberGlossy, .fiberMatte, .fiberSatin, .fiberPearl:
            return true
        default:
            return false
        }
    }
    
    var requiresLongerWash: Bool {
        isFiber
    }
}

// MARK: - Paper Grade
enum PaperGrade: String, Codable, CaseIterable, Sendable {
    case grade00 = "00"
    case grade0 = "0"
    case grade05 = "0.5"
    case grade1 = "1"
    case grade15 = "1.5"
    case grade2 = "2"
    case grade25 = "2.5"
    case grade3 = "3"
    case grade35 = "3.5"
    case grade4 = "4"
    case grade45 = "4.5"
    case grade5 = "5"
    case multigrade = "Multigrade"
    case variable = "Variabile"
    
    var displayName: String {
        rawValue
    }
    
    var contrastLevel: String {
        switch self {
        case .grade00, .grade0:
            return "Molto morbido"
        case .grade05, .grade1:
            return "Morbido"
        case .grade15, .grade2:
            return "Normale"
        case .grade25, .grade3:
            return "Contrastato"
        case .grade35, .grade4:
            return "Molto contrastato"
        case .grade45, .grade5:
            return "Durissimo"
        default:
            return "Variabile"
        }
    }
    
    var filterValue: String? {
        switch self {
        case .grade00: return "M 180 Y 190"
        case .grade0: return "M 130 Y 140"
        case .grade05: return "M 100 Y 115"
        case .grade1: return "M 75 Y 90"
        case .grade15: return "M 55 Y 70"
        case .grade2: return "M 35 Y 50"
        case .grade25: return "M 20 Y 35"
        case .grade3: return "M 15 Y 15"
        case .grade35: return "M 35 C 5"
        case .grade4: return "M 65"
        case .grade45: return "M 100"
        case .grade5: return "M 150"
        default: return nil
        }
    }
}

// MARK: - Paper Size
enum PaperSize: String, Codable, CaseIterable, Sendable {
    case a6 = "10×15 cm (A6)"
    case a5 = "15×21 cm (A5)"
    case a4 = "21×29.7 cm (A4)"
    case a3 = "29.7×42 cm (A3)"
    case a2 = "42×59.4 cm (A2)"
    case a1 = "59.4×84 cm (A1)"
    case size9x12 = "9×12 cm"
    case size10x12 = "10×12 cm"
    case size13x18 = "13×18 cm"
    case size18x24 = "18×24 cm"
    case size20x25 = "20×25 cm (8×10)"
    case size24x30 = "24×30 cm"
    case size30x40 = "30×40 cm"
    case size40x50 = "40×50 cm"
    case size50x60 = "50×60 cm"
    case size60x80 = "60×80 cm"
    case strip = "Striscia test"
    case custom = "Personalizzato"
    
    var dimensions: (width: Double, height: Double)? {
        switch self {
        case .a6: return (10, 15)
        case .a5: return (15, 21)
        case .a4: return (21, 29.7)
        case .a3: return (29.7, 42)
        case .a2: return (42, 59.4)
        case .a1: return (59.4, 84)
        case .size9x12: return (9, 12)
        case .size10x12: return (10, 12)
        case .size13x18: return (13, 18)
        case .size18x24: return (18, 24)
        case .size20x25: return (20, 25)
        case .size24x30: return (24, 30)
        case .size30x40: return (30, 40)
        case .size40x50: return (40, 50)
        case .size50x60: return (50, 60)
        case .size60x80: return (60, 80)
        default: return nil
        }
    }
}

// MARK: - Print Rating
enum PrintRating: String, Codable, CaseIterable, Sendable {
    case workPrint = "Stampa di lavoro"
    case testPrint = "Stampa test"
    case proof = "Proof"
    case good = "Buona"
    case veryGood = "Molto buona"
    case excellent = "Eccellente"
    case final = "Stampa finale"
    case exhibition = "Da esposizione"
    
    var isExhibitionQuality: Bool {
        self == .exhibition || self == .final || self == .excellent
    }
}

// MARK: - DodgeBurn Operation (Embedded Model)
@Model
final class DodgeBurnOperation {
    @Attribute(.unique) var id: UUID
    var print: Print?
    
    var type: DodgeBurnType
    var tool: DodgeBurnTool
    var area: String // Descrizione dell'area
    var exposurePercentage: Double // % del tempo base
    var duration: TimeInterval // secondi effettivi
    var shape: String? // "circle", "oval", etc.
    var size: String? // "small", "medium", "large"
    var notes: String
    var order: Int // Ordine di applicazione
    
    init(
        id: UUID = UUID(),
        type: DodgeBurnType,
        tool: DodgeBurnTool,
        area: String,
        exposurePercentage: Double,
        duration: TimeInterval,
        shape: String? = nil,
        size: String? = nil,
        notes: String = "",
        order: Int = 0
    ) {
        self.id = id
        self.type = type
        self.tool = tool
        self.area = area
        self.exposurePercentage = exposurePercentage
        self.duration = duration
        self.shape = shape
        self.size = size
        self.notes = notes
        self.order = order
    }
    
    var displayDescription: String {
        let action = type == .dodge ? "Dodge" : "Burn"
        return "\(action): \(area) (\(Int(exposurePercentage))%)"
    }
}

enum DodgeBurnType: String, Codable, CaseIterable, Sendable {
    case dodge = "Dodge"
    case burn = "Burn"
    
    var description: String {
        switch self {
        case .dodge:
            return "Schiarire un'area (tenere la luce)"
        case .burn:
            return "Oscurare un'area (aggiungere luce)"
        }
    }
    
    var icon: String {
        switch self {
        case .dodge: return "sun.max"
        case .burn: return "moon.fill"
        }
    }
}

enum DodgeBurnTool: String, Codable, CaseIterable, Sendable {
    case hand = "Mano"
    case card = "Cartoncino"
    case paddle = "Palette"
    case wand = "Bacchetta"
    case template = "Maschera"
    
    var description: String {
        switch self {
        case .hand:
            return "Forma con le dita"
        case .card:
            return "Cartoncino nero tagliato"
        case .paddle:
            return "Palette professionali"
        case .wand:
            return "Bacchetta sottile"
        case .template:
            return "Maschera precisa"
        }
    }
}

// MARK: - Print Session
struct PrintSession: Identifiable, Codable, Sendable {
    let id: UUID
    var date: Date
    var location: String
    var enlarger: String
    var paperBatch: String
    var developerBatch: String
    var notes: String
    var printIds: [UUID]
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        location: String = "",
        enlarger: String = "",
        paperBatch: String = "",
        developerBatch: String = "",
        notes: String = "",
        printIds: [UUID] = []
    ) {
        self.id = id
        self.date = date
        self.location = location
        self.enlarger = enlarger
        self.paperBatch = paperBatch
        self.developerBatch = developerBatch
        self.notes = notes
        self.printIds = printIds
    }
}

// MARK: - Print Presets
struct PrintPreset: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var paperBrand: String
    var paperModel: String
    var paperType: PaperType
    var developerName: String
    var developerDilution: String
    var developmentTime: TimeInterval
    var description: String
    
    init(
        id: UUID = UUID(),
        name: String,
        paperBrand: String,
        paperModel: String,
        paperType: PaperType,
        developerName: String,
        developerDilution: String,
        developmentTime: TimeInterval,
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.paperBrand = paperBrand
        self.paperModel = paperModel
        self.paperType = paperType
        self.developerName = developerName
        self.developerDilution = developerDilution
        self.developmentTime = developmentTime
        self.description = description
    }
    
    static let presets: [PrintPreset] = [
        PrintPreset(
            name: "Ilford Multigrade RC Standard",
            paperBrand: "Ilford",
            paperModel: "Multigrade IV RC",
            paperType: .rc,
            developerName: "Ilford Multigrade",
            developerDilution: "1+9",
            developmentTime: 60,
            description: "Sviluppo standard per carta RC"
        ),
        PrintPreset(
            name: "Ilford Multigrade FB Standard",
            paperBrand: "Ilford",
            paperModel: "Multigrade IV FB",
            paperType: .fiber,
            developerName: "Ilford Multigrade",
            developerDilution: "1+9",
            developmentTime: 90,
            description: "Sviluppo per carta baritata"
        ),
        PrintPreset(
            name: "Kodak Dektol RC",
            paperBrand: "Kodak",
            paperModel: "Polymax",
            paperType: .rc,
            developerName: "Kodak Dektol",
            developerDilution: "1+2",
            developmentTime: 60,
            description: "Sviluppo con Dektol"
        ),
        PrintPreset(
            name: "Moersch Easy Lith",
            paperBrand: "Vari",
            paperModel: "Carta lith",
            paperType: .rc,
            developerName: "Moersch Easy Lith",
            developerDilution: "A+B 1+20",
            developmentTime: 180,
            description: "Sviluppo lith per effetto particolare"
        ),
    ]
}
