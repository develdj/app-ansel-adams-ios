//
//  ZoneSystemModels.swift
//  Zone System Master - Photo Editor Engine
//  Data models for Ansel Adams darkroom techniques
//

import Foundation
import CoreImage
import Metal
import SwiftUI

// MARK: - Zone System Constants

public enum ZoneSystem {
    public static let zoneCount = 11 // Zones 0-10
    public static let middleGrayZone = 5 // Zone V (18% gray)
    public static let zoneRange: ClosedRange<Float> = 0...10
    
    // Zone descriptions from Ansel Adams
    public static let zoneDescriptions: [String] = [
        "Zone 0: Pure black - Maximum black of paper stock",
        "Zone I: Near black - Slight tonality, no texture",
        "Zone II: Dark gray - First suggestion of texture",
        "Zone III: Dark gray - Average dark materials, distinct texture",
        "Zone IV: Medium dark gray - Dark foliage, stone, shadowed landscape",
        "Zone V: Middle gray - 18% reflectance, north sky, dark skin",
        "Zone VI: Light gray - Average Caucasian skin, light stone",
        "Zone VII: Light gray - Very light skin, light concrete, snow in shadow",
        "Zone VIII: Very light gray - Whites with texture, light snow",
        "Zone IX: Very light - Slight tone, glaring snow, specular highlights",
        "Zone X: Pure white - Paper white, no detail"
    ]
    
    // Zone luminance values (normalized 0-1)
    public static let zoneLuminance: [Float] = [
        0.0,    // Zone 0
        0.01,   // Zone I
        0.035,  // Zone II
        0.09,   // Zone III
        0.18,   // Zone IV
        0.36,   // Zone V (18% gray = ~0.36 in linear)
        0.5,    // Zone VI
        0.68,   // Zone VII
        0.81,   // Zone VIII
        0.91,   // Zone IX
        1.0     // Zone X
    ]
}

// MARK: - Luminosity Mask Types

public enum LuminosityMaskType: String, CaseIterable, Identifiable {
    case lights = "Lights"
    case lightsMedium = "Lights Medium"
    case midtones = "Midtones"
    case darksMedium = "Darks Medium"
    case darks = "Darks"
    
    public var id: String { rawValue }
    
    // Zone ranges for each mask type
    public var zoneRange: ClosedRange<Float> {
        switch self {
        case .lights:
            return 7.5...10.0 // Zone VIII-X
        case .lightsMedium:
            return 5.5...7.5 // Zone VI-VII
        case .midtones:
            return 4.5...5.5 // Zone V
        case .darksMedium:
            return 2.5...4.5 // Zone III-IV
        case .darks:
            return 0.0...2.5 // Zone 0-II
        }
    }
    
    public var description: String {
        switch self {
        case .lights:
            return "Highlights (Zone VIII-X)"
        case .lightsMedium:
            return "Bright midtones (Zone VI-VII)"
        case .midtones:
            return "Middle gray (Zone V)"
        case .darksMedium:
            return "Dark midtones (Zone III-IV)"
        case .darks:
            return "Shadows (Zone 0-II)"
        }
    }
}

// MARK: - Film Types

public enum FilmType: String, CaseIterable, Identifiable {
    case hp5 = "Ilford HP5 Plus"
    case triX = "Kodak Tri-X"
    case delta100 = "Ilford Delta 100"
    case delta400 = "Ilford Delta 400"
    case tmax100 = "Kodak T-Max 100"
    case tmax400 = "Kodak T-Max 400"
    case fp4 = "Ilford FP4 Plus"
    case panF = "Ilford Pan F Plus"
    
    public var id: String { rawValue }
    
    public var iso: Int {
        switch self {
        case .hp5: return 400
        case .triX: return 400
        case .delta100: return 100
        case .delta400: return 400
        case .tmax100: return 100
        case .tmax400: return 400
        case .fp4: return 125
        case .panF: return 50
        }
    }
    
    public var grainCharacteristic: GrainCharacteristic {
        switch self {
        case .hp5:
            return GrainCharacteristic(intensity: 0.8, size: 1.0, sharpness: 0.7)
        case .triX:
            return GrainCharacteristic(intensity: 1.2, size: 1.1, sharpness: 0.6)
        case .delta100:
            return GrainCharacteristic(intensity: 0.4, size: 0.6, sharpness: 0.9)
        case .delta400:
            return GrainCharacteristic(intensity: 0.7, size: 0.8, sharpness: 0.8)
        case .tmax100:
            return GrainCharacteristic(intensity: 0.3, size: 0.5, sharpness: 0.95)
        case .tmax400:
            return GrainCharacteristic(intensity: 0.5, size: 0.7, sharpness: 0.9)
        case .fp4:
            return GrainCharacteristic(intensity: 0.5, size: 0.7, sharpness: 0.85)
        case .panF:
            return GrainCharacteristic(intensity: 0.2, size: 0.4, sharpness: 0.98)
        }
    }
    
    public var contrastIndex: Float {
        switch self {
        case .hp5: return 0.62
        case .triX: return 0.65
        case .delta100: return 0.58
        case .delta400: return 0.60
        case .tmax100: return 0.55
        case .tmax400: return 0.58
        case .fp4: return 0.56
        case .panF: return 0.52
        }
    }
}

public struct GrainCharacteristic {
    public let intensity: Float
    public let size: Float
    public let sharpness: Float
}

// MARK: - Paper Grades (Multigrade)

public enum PaperGrade: Int, CaseIterable, Identifiable {
    case grade00 = 0 // Very soft
    case grade0 = 1  // Soft
    case grade1 = 2  // Slightly soft
    case grade2 = 3  // Normal
    case grade3 = 4  // Slightly hard
    case grade4 = 5  // Hard
    case grade5 = 6  // Very hard
    
    public var id: Int { rawValue }
    
    public var description: String {
        switch self {
        case .grade00: return "00 - Very Soft"
        case .grade0: return "0 - Soft"
        case .grade1: return "1 - Slightly Soft"
        case .grade2: return "2 - Normal"
        case .grade3: return "3 - Slightly Hard"
        case .grade4: return "4 - Hard"
        case .grade5: return "5 - Very Hard"
        }
    }
    
    public var contrastFactor: Float {
        switch self {
        case .grade00: return 0.30
        case .grade0: return 0.50
        case .grade1: return 0.70
        case .grade2: return 1.00
        case .grade3: return 1.40
        case .grade4: return 2.00
        case .grade5: return 2.80
        }
    }
}

// MARK: - Dodge & Burn Settings

public struct DodgeBurnSettings: Equatable {
    public var mode: DodgeBurnMode
    public var intensity: Float // 0.0 to 2.0
    public var exposureTime: Float // Simulated exposure time
    public var brushSize: Float
    public var brushHardness: Float // 0.0 = soft, 1.0 = hard
    public var brushShape: BrushShape
    public var gamma: Float
    
    public init(
        mode: DodgeBurnMode = .dodge,
        intensity: Float = 0.5,
        exposureTime: Float = 1.0,
        brushSize: Float = 50.0,
        brushHardness: Float = 0.5,
        brushShape: BrushShape = .circle,
        gamma: Float = 1.0
    ) {
        self.mode = mode
        self.intensity = intensity
        self.exposureTime = exposureTime
        self.brushSize = brushSize
        self.brushHardness = brushHardness
        self.brushShape = brushShape
        self.gamma = gamma
    }
    
    public static let `default` = DodgeBurnSettings()
}

public enum DodgeBurnMode: String, CaseIterable, Identifiable {
    case dodge = "Dodge"
    case burn = "Burn"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .dodge:
            return "Dodge (Lighten) - Hold back exposure"
        case .burn:
            return "Burn (Darken) - Add exposure"
        }
    }
}

public enum BrushShape: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case ellipse = "Ellipse"
    case freeform = "Freeform"
    
    public var id: String { rawValue }
}

// MARK: - Curve Control Points

public struct CurveControlPoint: Equatable, Identifiable {
    public let id = UUID()
    public var x: Float // Input value 0-1
    public var y: Float // Output value 0-1
    public var isFixed: Bool // Fixed points (black/white)
    
    public init(x: Float, y: Float, isFixed: Bool = false) {
        self.x = max(0, min(1, x))
        self.y = max(0, min(1, y))
        self.isFixed = isFixed
    }
    
    public static let blackPoint = CurveControlPoint(x: 0, y: 0, isFixed: true)
    public static let whitePoint = CurveControlPoint(x: 1, y: 1, isFixed: true)
    public static let midpoint = CurveControlPoint(x: 0.5, y: 0.5, isFixed: false)
}

// MARK: - Tonal Curve Settings

public struct TonalCurveSettings: Equatable {
    public var controlPoints: [CurveControlPoint]
    public var blackPoint: Float
    public var whitePoint: Float
    public var gamma: Float
    public var toe: Float // Shadow compression
    public var shoulder: Float // Highlight compression
    public var contrast: Float
    
    public init(
        controlPoints: [CurveControlPoint] = [.blackPoint, .midpoint, .whitePoint],
        blackPoint: Float = 0.0,
        whitePoint: Float = 1.0,
        gamma: Float = 1.0,
        toe: Float = 0.0,
        shoulder: Float = 0.0,
        contrast: Float = 1.0
    ) {
        self.controlPoints = controlPoints
        self.blackPoint = blackPoint
        self.whitePoint = whitePoint
        self.gamma = gamma
        self.toe = toe
        self.shoulder = shoulder
        self.contrast = contrast
    }
    
    public static let linear = TonalCurveSettings()
    
    public static let highContrast = TonalCurveSettings(
        controlPoints: [
            .blackPoint,
            CurveControlPoint(x: 0.25, y: 0.15),
            CurveControlPoint(x: 0.75, y: 0.85),
            .whitePoint
        ],
        contrast: 1.4
    )
    
    public static let lowContrast = TonalCurveSettings(
        controlPoints: [
            .blackPoint,
            CurveControlPoint(x: 0.25, y: 0.35),
            CurveControlPoint(x: 0.75, y: 0.65),
            .whitePoint
        ],
        contrast: 0.7
    )
}

// MARK: - Split Grade Settings

public struct SplitGradeSettings: Equatable {
    public var lowGrade: PaperGrade
    public var highGrade: PaperGrade
    public var lowExposure: Float
    public var highExposure: Float
    public var maskIntensity: Float
    public var useMask: Bool
    
    public init(
        lowGrade: PaperGrade = .grade0,
        highGrade: PaperGrade = .grade4,
        lowExposure: Float = 1.0,
        highExposure: Float = 1.0,
        maskIntensity: Float = 0.5,
        useMask: Bool = true
    ) {
        self.lowGrade = lowGrade
        self.highGrade = highGrade
        self.lowExposure = lowExposure
        self.highExposure = highExposure
        self.maskIntensity = maskIntensity
        self.useMask = useMask
    }
}

// MARK: - Vignette Settings

public struct VignetteSettings: Equatable {
    public var intensity: Float
    public var radius: Float
    public var feather: Float
    public var center: CGPoint
    public var enabled: Bool
    
    public init(
        intensity: Float = 0.5,
        radius: Float = 0.8,
        feather: Float = 0.3,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5),
        enabled: Bool = false
    ) {
        self.intensity = intensity
        self.radius = radius
        self.feather = feather
        self.center = center
        self.enabled = enabled
    }
}

// MARK: - BW Conversion Settings

public struct BWConversionSettings: Equatable {
    public var redFilter: Float
    public var greenFilter: Float
    public var blueFilter: Float
    public var contrast: Float
    public var brightness: Float
    
    public init(
        redFilter: Float = 0.299,
        greenFilter: Float = 0.587,
        blueFilter: Float = 0.114,
        contrast: Float = 1.0,
        brightness: Float = 0.0
    ) {
        self.redFilter = redFilter
        self.greenFilter = greenFilter
        self.blueFilter = blueFilter
        self.contrast = contrast
        self.brightness = brightness
    }
    
    public var filterWeights: SIMD3<Float> {
        let sum = redFilter + greenFilter + blueFilter
        guard sum > 0 else { return SIMD3<Float>(0.299, 0.587, 0.114) }
        return SIMD3<Float>(redFilter, greenFilter, blueFilter) / sum
    }
    
    // Preset filter simulations
    public static let redFilter90 = BWConversionSettings(
        redFilter: 0.9, greenFilter: 0.05, blueFilter: 0.05,
        contrast: 1.2
    )
    
    public static let orangeFilter = BWConversionSettings(
        redFilter: 0.7, greenFilter: 0.25, blueFilter: 0.05,
        contrast: 1.1
    )
    
    public static let yellowFilter = BWConversionSettings(
        redFilter: 0.5, greenFilter: 0.45, blueFilter: 0.05,
        contrast: 1.05
    )
    
    public static let greenFilter = BWConversionSettings(
        redFilter: 0.1, greenFilter: 0.8, blueFilter: 0.1,
        contrast: 1.15
    )
    
    public static let blueFilter = BWConversionSettings(
        redFilter: 0.05, greenFilter: 0.15, blueFilter: 0.8,
        contrast: 1.1
    )
}

// MARK: - Film Grain Settings

public struct FilmGrainSettings: Equatable {
    public var filmType: FilmType
    public var intensity: Float
    public var grainSize: Float
    public var pushPull: Float // -2 to +2 stops
    public var enabled: Bool
    
    public init(
        filmType: FilmType = .hp5,
        intensity: Float = 0.5,
        grainSize: Float = 1.0,
        pushPull: Float = 0.0,
        enabled: Bool = true
    ) {
        self.filmType = filmType
        self.intensity = intensity
        self.grainSize = grainSize
        self.pushPull = pushPull
        self.enabled = enabled
    }
}

// MARK: - Sharpening Settings

public struct SharpeningSettings: Equatable {
    public var amount: Float
    public var radius: Float
    public var threshold: Float
    public var enabled: Bool
    
    public init(
        amount: Float = 0.5,
        radius: Float = 1.0,
        threshold: Float = 0.01,
        enabled: Bool = false
    ) {
        self.amount = amount
        self.radius = radius
        self.threshold = threshold
        self.enabled = enabled
    }
}

// MARK: - Export Settings

public struct ExportSettings: Equatable {
    public var format: ExportFormat
    public var quality: Float
    public var resolution: ExportResolution
    public var colorSpace: ExportColorSpace
    public var includeMetadata: Bool
    
    public init(
        format: ExportFormat = .tiff,
        quality: Float = 1.0,
        resolution: ExportResolution = .original,
        colorSpace: ExportColorSpace = .grayGamma22,
        includeMetadata: Bool = true
    ) {
        self.format = format
        self.quality = quality
        self.resolution = resolution
        self.colorSpace = colorSpace
        self.includeMetadata = includeMetadata
    }
}

public enum ExportFormat: String, CaseIterable, Identifiable {
    case tiff = "TIFF"
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    
    public var id: String { rawValue }
    
    public var fileExtension: String {
        switch self {
        case .tiff: return "tiff"
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }
}

public enum ExportResolution: String, CaseIterable, Identifiable {
    case original = "Original"
    case half = "50%"
    case quarter = "25%"
    case custom = "Custom"
    
    public var id: String { rawValue }
}

public enum ExportColorSpace: String, CaseIterable, Identifiable {
    case grayGamma22 = "Gray Gamma 2.2"
    case grayGamma18 = "Gray Gamma 1.8"
    case sRGB = "sRGB"
    case adobeRGB = "Adobe RGB"
    case proPhoto = "ProPhoto RGB"
    
    public var id: String { rawValue }
}

// MARK: - Annotation Types

public enum AnnotationType: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case freehand = "Freehand"
    case text = "Text"
    case bezier = "Bezier Curve"
    
    public var id: String { rawValue }
}

public struct Annotation: Identifiable, Equatable {
    public let id = UUID()
    public var type: AnnotationType
    public var points: [CGPoint]
    public var color: Color
    public var lineWidth: CGFloat
    public var text: String?
    public var opacity: Double
    
    public init(
        type: AnnotationType,
        points: [CGPoint] = [],
        color: Color = .red,
        lineWidth: CGFloat = 2.0,
        text: String? = nil,
        opacity: Double = 0.8
    ) {
        self.type = type
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
        self.text = text
        self.opacity = opacity
    }
}

// MARK: - Processing State

public enum ProcessingState: Equatable {
    case idle
    case processing(progress: Float)
    case completed
    case failed(error: String)
    
    public static func == (lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.processing(let p1), .processing(let p2)):
            return p1 == p2
        case (.completed, .completed):
            return true
        case (.failed(let e1), .failed(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

// MARK: - Histogram Data

public struct HistogramData: Equatable {
    public var red: [UInt32]
    public var green: [UInt32]
    public var blue: [UInt32]
    public var luminance: [UInt32]
    public var zones: [UInt32] // Zone 0-10 histogram
    
    public init(
        red: [UInt32] = Array(repeating: 0, count: 256),
        green: [UInt32] = Array(repeating: 0, count: 256),
        blue: [UInt32] = Array(repeating: 0, count: 256),
        luminance: [UInt32] = Array(repeating: 0, count: 256),
        zones: [UInt32] = Array(repeating: 0, count: 11)
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.luminance = luminance
        self.zones = zones
    }
}
