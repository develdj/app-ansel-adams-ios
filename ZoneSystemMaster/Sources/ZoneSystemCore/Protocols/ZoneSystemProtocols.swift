import Foundation
import SwiftUI
import CoreImage
import Photos

// MARK: - Zone System Core Types

/// Represents the 11 zones of Ansel Adams' Zone System (0-10)
@frozen
public enum Zone: Int, CaseIterable, Sendable, Comparable, Identifiable {
    case zone0 = 0   // Pure black
    case zone1 = 1   // Near black, slight tonality
    case zone2 = 2   // Dark gray, distinct texture
    case zone3 = 3   // Dark gray, excellent detail
    case zone4 = 4   // Medium-dark gray
    case zone5 = 5   // Middle gray (18% reflectance)
    case zone6 = 6   // Medium-light gray
    case zone7 = 7   // Light gray, excellent detail
    case zone8 = 8   // Very light gray
    case zone9 = 9   // Near white, slight tonality
    case zone10 = 10 // Pure white
    
    public var id: Int { rawValue }
    
    public var description: String {
        switch self {
        case .zone0: return "Zone 0 - Pure Black"
        case .zone1: return "Zone 1 - Near Black"
        case .zone2: return "Zone 2 - Dark Gray"
        case .zone3: return "Zone 3 - Dark Gray (Detail)"
        case .zone4: return "Zone 4 - Medium-Dark Gray"
        case .zone5: return "Zone 5 - Middle Gray (18%)"
        case .zone6: return "Zone 6 - Medium-Light Gray"
        case .zone7: return "Zone 7 - Light Gray (Detail)"
        case .zone8: return "Zone 8 - Very Light Gray"
        case .zone9: return "Zone 9 - Near White"
        case .zone10: return "Zone 10 - Pure White"
        }
    }
    
    public var reflectance: Double {
        // Based on 18% gray at Zone 5
        let baseReflectance = 0.18
        let stops = Double(rawValue - 5)
        return baseReflectance * pow(2.0, stops)
    }
    
    public var luminanceValue: Double {
        // Convert reflectance to perceptual luminance (0-1)
        min(max(reflectance, 0.0), 1.0)
    }
    
    public static func < (lhs: Zone, rhs: Zone) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Film Format Types

@frozen
public enum FilmFormat: String, CaseIterable, Sendable, Identifiable {
    case mm35 = "35mm"
    case mm6x6 = "6x6"
    case mm6x7 = "6x7"
    case mm4x5 = "4x5"
    case mm8x10 = "8x10"
    case xPan = "X-Pan"
    
    public var id: String { rawValue }
    
    public var aspectRatio: Double {
        switch self {
        case .mm35: return 3.0 / 2.0
        case .mm6x6: return 1.0
        case .mm6x7: return 7.0 / 6.0
        case .mm4x5: return 5.0 / 4.0
        case .mm8x10: return 5.0 / 4.0
        case .xPan: return 3.0
        }
    }
    
    public var description: String {
        switch self {
        case .mm35: return "35mm (3:2)"
        case .mm6x6: return "Medium Format 6×6 (1:1)"
        case .mm6x7: return "Medium Format 6×7 (7:6)"
        case .mm4x5: return "Large Format 4×5 (5:4)"
        case .mm8x10: return "Large Format 8×10 (5:4)"
        case .xPan: return "Hasselblad X-Pan (3:1)"
        }
    }
    
    public var frameSize: CGSize {
        switch self {
        case .mm35: return CGSize(width: 36, height: 24)
        case .mm6x6: return CGSize(width: 56, height: 56)
        case .mm6x7: return CGSize(width: 70, height: 56)
        case .mm4x5: return CGSize(width: 102, height: 127)
        case .mm8x10: return CGSize(width: 203, height: 254)
        case .xPan: return CGSize(width: 65, height: 24)
        }
    }
}

// MARK: - Film Emulsion Types

@frozen
public enum FilmEmulsion: String, CaseIterable, Sendable, Identifiable {
    case ilfordHP5 = "Ilford HP5 Plus"
    case ilfordDelta100 = "Ilford Delta 100"
    case ilfordDelta400 = "Ilford Delta 400"
    case ilfordPanF = "Ilford Pan F Plus"
    case ilfordFP4 = "Ilford FP4 Plus"
    case kodakTriX = "Kodak Tri-X 400"
    case kodakTMax100 = "Kodak T-Max 100"
    case kodakTMax400 = "Kodak T-Max 400"
    case kodakTMaxP3200 = "Kodak T-Max P3200"
    case fomapan100 = "Fomapan 100"
    case fomapan200 = "Fomapan 200"
    case fomapan400 = "Fomapan 400"
    case rolleiRetro80s = "Rollei Retro 80S"
    case rolleiInfrared = "Rollei Infrared 400"
    case adoxCHS100 = "Adox CHS 100 II"
    case berggerPancro400 = "Bergger Pancro 400"
    
    public var id: String { rawValue }
    
    public var iso: Int {
        switch self {
        case .ilfordHP5: return 400
        case .ilfordDelta100: return 100
        case .ilfordDelta400: return 400
        case .ilfordPanF: return 50
        case .ilfordFP4: return 125
        case .kodakTriX: return 400
        case .kodakTMax100: return 100
        case .kodakTMax400: return 400
        case .kodakTMaxP3200: return 3200
        case .fomapan100: return 100
        case .fomapan200: return 200
        case .fomapan400: return 400
        case .rolleiRetro80s: return 80
        case .rolleiInfrared: return 400
        case .adoxCHS100: return 100
        case .berggerPancro400: return 400
        }
    }
    
    public var contrastIndex: Double {
        // Characteristic curve slope (gamma)
        switch self {
        case .ilfordHP5: return 0.65
        case .ilfordDelta100: return 0.70
        case .ilfordDelta400: return 0.68
        case .ilfordPanF: return 0.75
        case .ilfordFP4: return 0.72
        case .kodakTriX: return 0.68
        case .kodakTMax100: return 0.72
        case .kodakTMax400: return 0.70
        case .kodakTMaxP3200: return 0.62
        case .fomapan100: return 0.68
        case .fomapan200: return 0.66
        case .fomapan400: return 0.64
        case .rolleiRetro80s: return 0.70
        case .rolleiInfrared: return 0.60
        case .adoxCHS100: return 0.72
        case .berggerPancro400: return 0.66
        }
    }
    
    public var manufacturer: String {
        switch self {
        case .ilfordHP5, .ilfordDelta100, .ilfordDelta400, .ilfordPanF, .ilfordFP4:
            return "Ilford"
        case .kodakTriX, .kodakTMax100, .kodakTMax400, .kodakTMaxP3200:
            return "Kodak"
        case .fomapan100, .fomapan200, .fomapan400:
            return "Foma"
        case .rolleiRetro80s, .rolleiInfrared:
            return "Rollei"
        case .adoxCHS100:
            return "Adox"
        case .berggerPancro400:
            return "Bergger"
        }
    }
}

// MARK: - Paper Types

@frozen
public enum PaperType: String, CaseIterable, Sendable, Identifiable {
    case ilfordMultigradeIV = "Ilford Multigrade IV"
    case ilfordMultigradeV = "Ilford Multigrade V"
    case ilfordWarmtone = "Ilford Warmtone"
    case ilfordCooltone = "Ilford Cooltone"
    case ilfordArt300 = "Ilford Art 300"
    case kodakPolymax = "Kodak Polymax"
    case fomaBromvariant = "Foma Bromvariant"
    case orientalSeagull = "Oriental Seagull"
    
    public var id: String { rawValue }
    
    public var baseTone: PaperBaseTone {
        switch self {
        case .ilfordMultigradeIV, .ilfordMultigradeV, .kodakPolymax, .fomaBromvariant:
            return .neutral
        case .ilfordWarmtone:
            return .warm
        case .ilfordCooltone:
            return .cool
        case .ilfordArt300:
            return .warm
        case .orientalSeagull:
            return .neutral
        }
    }
    
    public var surface: PaperSurface {
        switch self {
        case .ilfordMultigradeIV, .ilfordMultigradeV:
            return .glossy
        case .ilfordWarmtone:
            return .pearl
        case .ilfordCooltone:
            return .glossy
        case .ilfordArt300:
            return .matte
        case .kodakPolymax:
            return .glossy
        case .fomaBromvariant:
            return .pearl
        case .orientalSeagull:
            return .glossy
        }
    }
}

@frozen
public enum PaperBaseTone: String, Sendable {
    case neutral = "Neutral"
    case warm = "Warm"
    case cool = "Cool"
}

@frozen
public enum PaperSurface: String, Sendable {
    case glossy = "Glossy"
    case pearl = "Pearl"
    case matte = "Matte"
    case satin = "Satin"
}

// MARK: - Developer Types

@frozen
public enum DeveloperType: String, CaseIterable, Sendable, Identifiable {
    case ilfordID11 = "Ilford ID-11"
    case ilfordDDX = "Ilford DD-X"
    case ilfordMicrophen = "Ilford Microphen"
    case ilfordPerceptol = "Ilford Perceptol"
    case ilfordPQUniversal = "Ilford PQ Universal"
    case kodakD76 = "Kodak D-76"
    case kodakHC110 = "Kodak HC-110"
    case kodakXTOL = "Kodak X-TOL"
    case kodakTMax = "Kodak T-Max"
    case rodinal = "Rodinal (R09)"
    case caffenol = "Caffenol"
    
    public var id: String { rawValue }
    
    public var category: DeveloperCategory {
        switch self {
        case .ilfordID11, .kodakD76:
            return .fineGrain
        case .ilfordDDX, .kodakHC110, .kodakXTOL:
            return .highAcutance
        case .ilfordMicrophen, .kodakTMax:
            return .push
        case .ilfordPerceptol:
            return .fineGrain
        case .ilfordPQUniversal:
            return .paper
        case .rodinal:
            return .highAcutance
        case .caffenol:
            return .alternative
        }
    }
}

@frozen
public enum DeveloperCategory: String, Sendable {
    case fineGrain = "Fine Grain"
    case highAcutance = "High Acutance"
    case push = "Push Processing"
    case paper = "Paper Developer"
    case alternative = "Alternative Process"
}

// MARK: - Darkroom Process Types

@frozen
public enum DarkroomPhase: String, CaseIterable, Sendable, Identifiable {
    case development = "Development"
    case stopBath = "Stop Bath"
    case fixer = "Fixing"
    case wash = "Washing"
    case hypoClear = "Hypo Clearing"
    case finalWash = "Final Wash"
    case drying = "Drying"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .development: return "drop.fill"
        case .stopBath: return "hand.raised.fill"
        case .fixer: return "lock.fill"
        case .wash: return "water.waves"
        case .hypoClear: return "sparkles"
        case .finalWash: return "water.waves"
        case .drying: return "wind"
        }
    }
    
    public var color: String {
        switch self {
        case .development: return "#FF6B35"
        case .stopBath: return "#F7C59F"
        case .fixer: return "#2EC4B6"
        case .wash: return "#5BC0BE"
        case .hypoClear: return "#9B5DE5"
        case .finalWash: return "#00BBF9"
        case .drying: return "#FEE440"
        }
    }
}

// MARK: - Measurement Types

@frozen
public enum MeteringMode: String, CaseIterable, Sendable, Identifiable {
    case spot = "Spot"
    case centerWeighted = "Center-Weighted"
    case matrix = "Matrix"
    case incident = "Incident"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .spot: return "Spot Metering - 1% of frame"
        case .centerWeighted: return "Center-Weighted Average"
        case .matrix: return "Evaluative/Matrix Metering"
        case .incident: return "Incident Light Metering"
        }
    }
}

@frozen
public enum ExposureValue: Int, CaseIterable, Sendable, Comparable {
    case evMinus6 = -6
    case evMinus5 = -5
    case evMinus4 = -4
    case evMinus3 = -3
    case evMinus2 = -2
    case evMinus1 = -1
    case ev0 = 0
    case ev1 = 1
    case ev2 = 2
    case ev3 = 3
    case ev4 = 4
    case ev5 = 5
    case ev6 = 6
    case ev7 = 7
    case ev8 = 8
    case ev9 = 9
    case ev10 = 10
    case ev11 = 11
    case ev12 = 12
    case ev13 = 13
    case ev14 = 14
    case ev15 = 15
    case ev16 = 16
    case ev17 = 17
    case ev18 = 18
    case ev19 = 19
    case ev20 = 20
    case ev21 = 21
    
    public var description: String {
        "EV \(rawValue)"
    }
    
    public static func < (lhs: ExposureValue, rhs: ExposureValue) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Feature Flags

@frozen
public enum AppFeature: String, CaseIterable, Sendable, Identifiable {
    case basicChat = "basic_chat"
    case exposureMeter = "exposure_meter"
    case darkroomTimer = "darkroom_timer"
    case filmRollLog = "film_roll_log"
    case zoneMapping = "zone_mapping"
    case physicalModeling = "physical_modeling"
    case realCurves = "real_curves"
    case fullEditor = "full_editor"
    case aiCritique = "ai_critique"
    case instaxPrinting = "instax_printing"
    case advancedAnalytics = "advanced_analytics"
    case customEmulsions = "custom_emulsions"
    case panoramicTools = "panoramic_tools"
    case cloudSync = "cloud_sync"
    
    public var id: String { rawValue }
    
    public var isProFeature: Bool {
        switch self {
        case .basicChat, .exposureMeter, .darkroomTimer, .filmRollLog:
            return false
        case .zoneMapping, .physicalModeling, .realCurves, .fullEditor,
             .aiCritique, .instaxPrinting, .advancedAnalytics, 
             .customEmulsions, .panoramicTools, .cloudSync:
            return true
        }
    }
    
    public var displayName: String {
        switch self {
        case .basicChat: return "Ansel Chat"
        case .exposureMeter: return "Zone Meter"
        case .darkroomTimer: return "Darkroom Timer"
        case .filmRollLog: return "Film Roll Log"
        case .zoneMapping: return "Zone Mapping"
        case .physicalModeling: return "Emulsion Physics"
        case .realCurves: return "Characteristic Curves"
        case .fullEditor: return "Pro Editor"
        case .aiCritique: return "AI Critique"
        case .instaxPrinting: return "Instax Print"
        case .advancedAnalytics: return "Analytics"
        case .customEmulsions: return "Custom Emulsions"
        case .panoramicTools: return "Panoramic Tools"
        case .cloudSync: return "Cloud Sync"
        }
    }
}

// MARK: - App State Types

@frozen
public enum AppTheme: String, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case darkroom = "Darkroom" // Special red-safe mode
}

@frozen
public enum UserExperienceLevel: String, CaseIterable, Sendable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case master = "Master Printer"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .beginner:
            return "New to the Zone System - guided learning mode"
        case .intermediate:
            return "Familiar with basics - expanded tools"
        case .advanced:
            return "Experienced printer - full control"
        case .master:
            return "Master printer - all features unlocked"
        }
    }
}
