import SwiftData
import Foundation

// MARK: - Zone System Development Models
// Based on Ansel Adams' techniques from "The Negative" and "The Print"

/// Represents a complete film development recipe
@Model
final class DeveloperRecipe {
    @Attribute(.unique) var id: UUID
    var name: String
    var developerName: DeveloperType
    var filmName: String
    var iso: Int
    var dilution: DilutionRatio
    var baseTimeSeconds: Int
    var temperatureCelsius: Double
    var agitationStyle: AgitationStyle
    var zoneSystem: ZoneSystemDevelopment
    var notes: String?
    var createdAt: Date
    var isFavorite: Bool
    var lastUsed: Date?
    
    // Computed development time based on zone system
    var adjustedTimeSeconds: Int {
        let multiplier = zoneSystem.timeMultiplier
        return Int(Double(baseTimeSeconds) * multiplier)
    }
    
    init(
        name: String,
        developerName: DeveloperType,
        filmName: String,
        iso: Int,
        dilution: DilutionRatio,
        baseTimeSeconds: Int,
        temperatureCelsius: Double = 20.0,
        agitationStyle: AgitationStyle = .standard,
        zoneSystem: ZoneSystemDevelopment = .normal,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.developerName = developerName
        self.filmName = filmName
        self.iso = iso
        self.dilution = dilution
        self.baseTimeSeconds = baseTimeSeconds
        self.temperatureCelsius = temperatureCelsius
        self.agitationStyle = agitationStyle
        self.zoneSystem = zoneSystem
        self.notes = notes
        self.createdAt = Date()
        self.isFavorite = false
    }
}

/// Zone System development variations (N, N+, N-)
enum ZoneSystemDevelopment: String, Codable, CaseIterable {
    case minus2 = "N-2"  // -30% time, significant compression
    case minus1 = "N-1"  // -15% time, slight compression
    case normal = "N"    // Standard time
    case plus1 = "N+1"   // +25% time, slight expansion
    case plus2 = "N+2"   // +50% time, significant expansion
    
    var timeMultiplier: Double {
        switch self {
        case .minus2: return 0.70
        case .minus1: return 0.85
        case .normal: return 1.0
        case .plus1: return 1.25
        case .plus2: return 1.50
        }
    }
    
    var description: String {
        switch self {
        case .minus2: return "N-2: High contrast scene compression"
        case .minus1: return "N-1: Slight compression"
        case .normal: return "N: Normal development"
        case .plus1: return "N+1: Slight expansion"
        case .plus2: return "N+2: Low contrast scene expansion"
        }
    }
    
    var icon: String {
        switch self {
        case .minus2: return "minus.circle.fill"
        case .minus1: return "minus.circle"
        case .normal: return "circle"
        case .plus1: return "plus.circle"
        case .plus2: return "plus.circle.fill"
        }
    }
}

/// Common black and white film developers
enum DeveloperType: String, Codable, CaseIterable {
    case d76 = "D-76"
    case d76Stock = "D-76 Stock"
    case d76OnePlusOne = "D-76 1+1"
    case hc110 = "HC-110"
    case hc110DilB = "HC-110 Dil B"
    case hc110DilH = "HC-110 Dil H"
    case rodinal = "Rodinal"
    case rodinalOnePlusTwentyFive = "Rodinal 1+25"
    case rodinalOnePlusFifty = "Rodinal 1+50"
    case ilfosol3 = "Ilfosol 3"
    case perceptol = "Perceptol"
    case microphen = "Microphen"
    case tmax = "T-Max Developer"
    case xtoll = "X-Tol"
    case pyrocat = "Pyrocat-HD"
    case caffenol = "Caffenol"
    case custom = "Custom"
    
    var typicalDilutions: [DilutionRatio] {
        switch self {
        case .d76, .d76Stock:
            return [.stock]
        case .d76OnePlusOne:
            return [.onePlusOne]
        case .hc110:
            return [.dilutionB, .dilutionH]
        case .hc110DilB:
            return [.dilutionB]
        case .hc110DilH:
            return [.dilutionH]
        case .rodinal, .rodinalOnePlusTwentyFive:
            return [.onePlusTwentyFive]
        case .rodinalOnePlusFifty:
            return [.onePlusFifty]
        case .ilfosol3:
            return [.onePlusNine, .onePlusFourteen]
        case .perceptol, .microphen:
            return [.stock, .onePlusOne, .onePlusTwo]
        case .tmax:
            return [.onePlusFour, .onePlusNine]
        case .xtoll:
            return [.stock, .onePlusOne]
        case .pyrocat:
            return [.onePlusOnePlusOneHundred]
        case .caffenol:
            return [.standard]
        case .custom:
            return DilutionRatio.allCases
        }
    }
    
    var category: String {
        switch self {
        case .d76, .d76Stock, .d76OnePlusOne, .xtoll:
            return "Fine Grain"
        case .hc110, .hc110DilB, .hc110DilH:
            return "High Acutance"
        case .rodinal, .rodinalOnePlusTwentyFive, .rodinalOnePlusFifty:
            return "High Acutance"
        case .ilfosol3, .perceptol:
            return "Fine Grain"
        case .microphen, .tmax:
            return "Speed Enhancing"
        case .pyrocat:
            return "Staining"
        case .caffenol:
            return "Alternative"
        case .custom:
            return "Custom"
        }
    }
}

/// Dilution ratios for developers
enum DilutionRatio: String, Codable, CaseIterable {
    case stock = "Stock"
    case onePlusOne = "1+1"
    case onePlusTwo = "1+2"
    case onePlusThree = "1+3"
    case onePlusFour = "1+4"
    case onePlusNine = "1+9"
    case onePlusFourteen = "1+14"
    case onePlusTwentyFive = "1+25"
    case onePlusFifty = "1+50"
    case dilutionB = "Dil B (1+31)"
    case dilutionH = "Dil H (1+63)"
    case onePlusOnePlusOneHundred = "1+1+100"
    case standard = "Standard"
    
    var ratio: (developer: Double, water: Double)? {
        switch self {
        case .stock: return (1, 0)
        case .onePlusOne: return (1, 1)
        case .onePlusTwo: return (1, 2)
        case .onePlusThree: return (1, 3)
        case .onePlusFour: return (1, 4)
        case .onePlusNine: return (1, 9)
        case .onePlusFourteen: return (1, 14)
        case .onePlusTwentyFive: return (1, 25)
        case .onePlusFifty: return (1, 50)
        case .dilutionB: return (1, 31)
        case .dilutionH: return (1, 63)
        case .onePlusOnePlusOneHundred: return (1, 101)
        case .standard: return nil
        }
    }
}

/// Agitation styles based on Ansel Adams recommendations
enum AgitationStyle: String, Codable, CaseIterable {
    case continuous = "Continuous"
    case standard = "Standard (Ansel Adams)"
    case minimal = "Minimal"
    case ilford = "Ilford Method"
    case rotary = "Rotary Processor"
    
    var description: String {
        switch self {
        case .continuous:
            return "Constant agitation throughout development"
        case .standard:
            return "1st minute continuous, then 10-15 sec every minute"
        case .minimal:
            return "1st minute continuous, then 5 sec every 2 minutes"
        case .ilford:
            return "First 10 sec each minute (inversions)"
        case .rotary:
            return "Continuous rotary agitation"
        }
    }
    
    /// Returns intervals in seconds for agitation notifications
    var agitationSchedule: AgitationSchedule {
        switch self {
        case .continuous:
            return AgitationSchedule(
                initialContinuousSeconds: nil, // Continuous throughout
                intervals: [],
                durationPerAgitation: 0
            )
        case .standard:
            return AgitationSchedule(
                initialContinuousSeconds: 60,
                intervals: Array(stride(from: 120, through: 3600, by: 60)),
                durationPerAgitation: 15
            )
        case .minimal:
            return AgitationSchedule(
                initialContinuousSeconds: 60,
                intervals: Array(stride(from: 180, through: 3600, by: 120)),
                durationPerAgitation: 5
            )
        case .ilford:
            return AgitationSchedule(
                initialContinuousSeconds: 10,
                intervals: Array(stride(from: 70, through: 3600, by: 60)),
                durationPerAgitation: 10
            )
        case .rotary:
            return AgitationSchedule(
                initialContinuousSeconds: nil,
                intervals: [],
                durationPerAgitation: 0
            )
        }
    }
}

/// Defines when agitation should occur
struct AgitationSchedule: Codable {
    let initialContinuousSeconds: Int? // nil = continuous throughout
    let intervals: [Int] // Seconds from start when agitation should occur
    let durationPerAgitation: Int // How long each agitation should last
}

// MARK: - Print Development Models

/// Print development recipe for darkroom printing
@Model
final class PrintRecipe {
    @Attribute(.unique) var id: UUID
    var name: String
    var paperType: PaperType
    var developerName: PrintDeveloper
    var dilution: DilutionRatio
    var developmentTimeSeconds: Int
    var temperatureCelsius: Double
    var notes: String?
    var createdAt: Date
    var isFavorite: Bool
    
    init(
        name: String,
        paperType: PaperType,
        developerName: PrintDeveloper,
        dilution: DilutionRatio,
        developmentTimeSeconds: Int,
        temperatureCelsius: Double = 20.0,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.paperType = paperType
        self.developerName = developerName
        self.dilution = dilution
        self.developmentTimeSeconds = developmentTimeSeconds
        self.temperatureCelsius = temperatureCelsius
        self.notes = notes
        self.createdAt = Date()
        self.isFavorite = false
    }
}

enum PrintDeveloper: String, Codable, CaseIterable {
    case dektol = "Dektol"
    case selectolSoft = "Selectol Soft"
    case selectol = "Selectol"
    case ilfordMultigrade = "Ilford Multigrade"
    case moerschEco = "Moersch Eco"
    case ansco130 = "Ansco 130"
    case amidol = "Amidol"
    
    var typicalTimeRange: ClosedRange<Int> {
        switch self {
        case .dektol: return 60...120
        case .selectolSoft: return 90...180
        case .selectol: return 90...180
        case .ilfordMultigrade: return 60...90
        case .moerschEco: return 60...120
        case .ansco130: return 90...150
        case .amidol: return 45...90
        }
    }
}

enum PaperType: String, Codable, CaseIterable {
    case fiberGlossy = "Fiber Glossy"
    case fiberMatte = "Fiber Matte"
    case fiberPearl = "Fiber Pearl"
    case rcGlossy = "RC Glossy"
    case rcMatte = "RC Matte"
    case rcPearl = "RC Pearl"
    case rcSatin = "RC Satin"
    
    var washTimeMinutes: Int {
        switch self {
        case .fiberGlossy, .fiberMatte, .fiberPearl:
            return 60 // Fiber needs longer wash
        case .rcGlossy, .rcMatte, .rcPearl, .rcSatin:
            return 4 // RC papers wash quickly
        }
    }
}

// MARK: - Split Grade Printing

/// Split grade printing configuration
struct SplitGradeConfig: Codable {
    var lowContrastExposure: Double // Seconds with filter 00 or 0
    var highContrastExposure: Double // Seconds with filter 5
    var baseFilter: Int // 0-5 for base exposure
    
    var totalExposure: Double {
        lowContrastExposure + highContrastExposure
    }
}

// MARK: - Session History

@Model
final class DevelopmentSession {
    @Attribute(.unique) var id: UUID
    var recipeID: UUID?
    var filmName: String
    var developerName: String
    var startedAt: Date
    var completedAt: Date?
    var wasSuccessful: Bool?
    var notes: String?
    var temperatureActual: Double?
    
    init(
        recipeID: UUID? = nil,
        filmName: String,
        developerName: String,
        temperatureActual: Double? = nil
    ) {
        self.id = UUID()
        self.recipeID = recipeID
        self.filmName = filmName
        self.developerName = developerName
        self.startedAt = Date()
        self.temperatureActual = temperatureActual
    }
}
