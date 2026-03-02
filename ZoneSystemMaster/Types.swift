// MARK: - Zone System Master - Tipi Fondamentali
// Scientific Exposure Engine per Sistema Zonale di Ansel Adams
// Swift 6.0 - Precisione Double

import Foundation
import SwiftUI

// MARK: - Zone System Core

/// Le 11 Zone del Sistema Zonale di Ansel Adams
/// Zone 0 = nero puro, Zone V = grigio medio 18%, Zone X = bianco puro
public enum Zone: Int, CaseIterable, Comparable {
    case zone0 = 0   // Nero puro, nessun dettaglio
    case zoneI = 1   // Nero con leggero tono, no texture
    case zoneII = 2  // Nero con texture, ombre profonde
    case zoneIII = 3 // Ombre con dettaglio (target esposizione ombre)
    case zoneIV = 4  // Ombre chiare, fogliame scuro
    case zoneV = 5   // Grigio medio 18%, erba verde, pelle chiara
    case zoneVI = 6  // Pelle caucasica chiara, neve in ombra
    case zoneVII = 7 // Pelle molto chiara, neve con dettaglio
    case zoneVIII = 8 // Luci chiare con texture
    case zoneIX = 9  // Bianco con leggero tono
    case zoneX = 10  // Bianco puro, nessun dettaglio
    
    public var reflectance: Double {
        // Reflectance percentuale per zona (basata su standard ANSI)
        let reflectances: [Double] = [0.0, 0.3, 0.6, 1.2, 2.4, 4.8, 9.6, 19.2, 38.4, 76.8, 100.0]
        return reflectances[rawValue]
    }
    
    public var description: String {
        let descriptions = [
            "Zone 0: Nero puro, nessun dettaglio",
            "Zone I: Nero con leggero tono, no texture",
            "Zone II: Nero con texture, ombre profonde",
            "Zone III: Ombre con dettaglio (esposizione target)",
            "Zone IV: Ombre chiare, fogliame scuro",
            "Zone V: Grigio medio 18%, riferimento",
            "Zone VI: Pelle chiara, neve in ombra",
            "Zone VII: Pelle molto chiara, neve con dettaglio",
            "Zone VIII: Luci chiare con texture",
            "Zone IX: Bianco con leggero tono",
            "Zone X: Bianco puro, nessun dettaglio"
        ]
        return descriptions[rawValue]
    }
    
    public var densityTarget: Double {
        // Densità target su pellicola per sviluppo N
        let densities: [Double] = [0.05, 0.15, 0.30, 0.45, 0.60, 0.75, 0.90, 1.05, 1.20, 1.35, 1.50]
        return densities[rawValue]
    }
    
    public static func < (lhs: Zone, rhs: Zone) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Exposure Value (EV)

/// Exposure Value - sistema di misurazione logaritmico
public struct EV: Comparable, CustomStringConvertible {
    public let value: Double
    
    public init(_ value: Double) {
        self.value = value
    }
    
    public static func from(aperture: Double, shutterSpeed: Double, iso: Double) -> EV {
        // EV = log2(N² / t) - log2(S / 100)
        let evBase = log2(pow(aperture, 2) / shutterSpeed)
        let isoCompensation = log2(iso / 100.0)
        return EV(evBase - isoCompensation)
    }
    
    public static func from(luminance: Double, iso: Double, calibrationConstant: Double = 12.5) -> EV {
        // EV = log2(L × S / K) dove K è la costante di calibrazione
        return EV(log2(luminance * iso / calibrationConstant))
    }
    
    public func toApertureShutterCombo(atISO iso: Double) -> [(aperture: Double, shutterSpeed: Double)] {
        var combinations: [(Double, Double)] = []
        let standardApertures = [1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0, 32.0]
        
        for aperture in standardApertures {
            let shutterSpeed = pow(aperture, 2) / pow(2, value + log2(iso / 100.0))
            if shutterSpeed >= 1/8000 && shutterSpeed <= 30 {
                combinations.append((aperture, shutterSpeed))
            }
        }
        return combinations
    }
    
    public static func < (lhs: EV, rhs: EV) -> Bool {
        return lhs.value < rhs.value
    }
    
    public static func + (lhs: EV, rhs: Double) -> EV {
        return EV(lhs.value + rhs)
    }
    
    public var description: String {
        return String(format: "EV %.1f", value)
    }
}

// MARK: - Film Types

/// Pellicole supportate con parametri sensitometrici reali
public enum FilmType: String, CaseIterable, Identifiable {
    case ilfordHP5Plus = "Ilford HP5 Plus"
    case ilfordFP4Plus = "Ilford FP4 Plus"
    case kodakTriX400 = "Kodak Tri-X 400"
    case kodakTMax100 = "Kodak T-Max 100"
    case kodakTMax400 = "Kodak T-Max 400"
    
    public var id: String { rawValue }
    
    public var nominalISO: Int {
        switch self {
        case .ilfordHP5Plus: return 400
        case .ilfordFP4Plus: return 125
        case .kodakTriX400: return 400
        case .kodakTMax100: return 100
        case .kodakTMax400: return 400
        }
    }
    
    public var recommendedEI: [Int] {
        // Exposure Index consigliati per diversi sviluppi
        switch self {
        case .ilfordHP5Plus: return [200, 400, 800, 1600]
        case .ilfordFP4Plus: return [64, 125, 250, 500]
        case .kodakTriX400: return [200, 400, 800, 1600, 3200]
        case .kodakTMax100: return [50, 100, 200, 400]
        case .kodakTMax400: return [200, 400, 800, 1600, 3200]
        }
    }
    
    // Parametri sensitometrici per curve H&D
    public var dMin: Double {
        // Densità minima (fog + base)
        switch self {
        case .ilfordHP5Plus: return 0.15
        case .ilfordFP4Plus: return 0.12
        case .kodakTriX400: return 0.18
        case .kodakTMax100: return 0.14
        case .kodakTMax400: return 0.16
        }
    }
    
    public var dMax: Double {
        // Densità massima
        switch self {
        case .ilfordHP5Plus: return 1.90
        case .ilfordFP4Plus: return 1.85
        case .kodakTriX400: return 1.95
        case .kodakTMax100: return 1.80
        case .kodakTMax400: return 1.90
        }
    }
    
    public var gammaN: Double {
        // Gamma per sviluppo normale (N)
        switch self {
        case .ilfordHP5Plus: return 0.65
        case .ilfordFP4Plus: return 0.60
        case .kodakTriX400: return 0.70
        case .kodakTMax100: return 0.55
        case .kodakTMax400: return 0.62
        }
    }
    
    public var gammaNPlus: Double {
        // Gamma per sviluppo N+ (più contrasto)
        return gammaN * 1.3
    }
    
    public var gammaNMinus: Double {
        // Gamma per sviluppo N- (meno contrasto)
        return gammaN * 0.7
    }
    
    public var toeLength: Double {
        // Lunghezza della regione toe in logH
        switch self {
        case .ilfordHP5Plus: return 0.6
        case .ilfordFP4Plus: return 0.5
        case .kodakTriX400: return 0.7
        case .kodakTMax100: return 0.4
        case .kodakTMax400: return 0.55
        }
    }
    
    public var shoulderStart: Double {
        // Inizio regione shoulder in logH (relativo a Zone VIII)
        switch self {
        case .ilfordHP5Plus: return 2.4
        case .ilfordFP4Plus: return 2.5
        case .kodakTriX400: return 2.3
        case .kodakTMax100: return 2.6
        case .kodakTMax400: return 2.4
        }
    }
    
    public var temperatureCoefficient: Double {
        // Coefficiente di variazione gamma per °C (riferimento 20°C)
        switch self {
        case .ilfordHP5Plus: return 0.015
        case .ilfordFP4Plus: return 0.012
        case .kodakTriX400: return 0.018
        case .kodakTMax100: return 0.010
        case .kodakTMax400: return 0.014
        }
    }
    
    public var developmentTimeN: Double {
        // Tempo di sviluppo base in minuti (ID-11/D-76 1+1, 20°C)
        switch self {
        case .ilfordHP5Plus: return 11.0
        case .ilfordFP4Plus: return 12.0
        case .kodakTriX400: return 9.5
        case .kodakTMax100: return 9.0
        case .kodakTMax400: return 8.0
        }
    }
}

// MARK: - Development Type

/// Tipi di sviluppo per controllo contrasto
public enum DevelopmentType: String, CaseIterable {
    case nMinus2 = "N-2"
    case nMinus1 = "N-1"
    case nNormal = "N"
    case nPlus1 = "N+1"
    case nPlus2 = "N+2"
    
    public var description: String {
        switch self {
        case .nMinus2: return "N-2: Contrasto molto ridotto (scene ad alto contrasto)"
        case .nMinus1: return "N-1: Contrasto ridotto"
        case .nNormal: return "N: Sviluppo normale"
        case .nPlus1: return "N+1: Contrasto aumentato"
        case .nPlus2: return "N+2: Contrasto molto aumentato (scene piatte)"
        }
    }
    
    public var timeMultiplier: Double {
        switch self {
        case .nMinus2: return 0.6
        case .nMinus1: return 0.8
        case .nNormal: return 1.0
        case .nPlus1: return 1.3
        case .nPlus2: return 1.7
        }
    }
    
    public var gammaMultiplier: Double {
        switch self {
        case .nMinus2: return 0.6
        case .nMinus1: return 0.8
        case .nNormal: return 1.0
        case .nPlus1: return 1.3
        case .nPlus2: return 1.6
        }
    }
}

// MARK: - Film Format

/// Formati fotografici supportati
public enum FilmFormat: String, CaseIterable, Identifiable {
    case mm35 = "35mm"
    case mm6x6 = "6x6"
    case mm6x7 = "6x7"
    case mm6x9 = "6x9"
    case mm4x5 = "4x5"
    case mm8x10 = "8x10"
    case ratio16x9 = "16:9"
    case ratio5x4 = "5:4"
    case ratio1x2 = "1:2"
    case xPan = "X-Pan 1:3"
    
    public var id: String { rawValue }
    
    public var sensorWidth: Double {
        // Larghezza in mm (o equivalente 35mm)
        switch self {
        case .mm35: return 36.0
        case .mm6x6: return 56.0
        case .mm6x7: return 56.0
        case .mm6x9: return 56.0
        case .mm4x5: return 102.0
        case .mm8x10: return 203.0
        case .ratio16x9: return 36.0
        case .ratio5x4: return 36.0
        case .ratio1x2: return 24.0
        case .xPan: return 65.0
        }
    }
    
    public var sensorHeight: Double {
        // Altezza in mm
        switch self {
        case .mm35: return 24.0
        case .mm6x6: return 56.0
        case .mm6x7: return 67.0
        case .mm6x9: return 84.0
        case .mm4x5: return 127.0
        case .mm8x10: return 254.0
        case .ratio16x9: return 20.25
        case .ratio5x4: return 28.8
        case .ratio1x2: return 48.0
        case .xPan: return 24.0
        }
    }
    
    public var aspectRatio: Double {
        return sensorWidth / sensorHeight
    }
    
    public var diagonal: Double {
        return sqrt(pow(sensorWidth, 2) + pow(sensorHeight, 2))
    }
    
    public var cropFactor: Double {
        // Fattore di crop rispetto a 35mm
        return 43.3 / diagonal // 43.3mm è la diagonale del 35mm
    }
}

// MARK: - Aperture

/// Valori di apertura standard
public enum Aperture: Double, CaseIterable {
    case f1_0 = 1.0
    case f1_4 = 1.4
    case f2_0 = 2.0
    case f2_8 = 2.8
    case f4_0 = 4.0
    case f5_6 = 5.6
    case f8_0 = 8.0
    case f11_0 = 11.0
    case f16_0 = 16.0
    case f22_0 = 22.0
    case f32_0 = 32.0
    case f45_0 = 45.0
    case f64_0 = 64.0
    
    public var description: String {
        return String(format: "f/%.1f", rawValue)
    }
}

// MARK: - Shutter Speed

/// Velocità otturatore standard
public enum ShutterSpeed: Double, CaseIterable {
    case s30 = 30.0
    case s15 = 15.0
    case s8 = 8.0
    case s4 = 4.0
    case s2 = 2.0
    case s1 = 1.0
    case s1_2 = 0.5
    case s1_4 = 0.25
    case s1_8 = 0.125
    case s1_15 = 0.0667
    case s1_30 = 0.0333
    case s1_60 = 0.0167
    case s1_125 = 0.008
    case s1_250 = 0.004
    case s1_500 = 0.002
    case s1_1000 = 0.001
    case s1_2000 = 0.0005
    case s1_4000 = 0.00025
    case s1_8000 = 0.000125
    
    public var description: String {
        if rawValue >= 1 {
            return String(format: "%.0f\"", rawValue)
        } else {
            let denominator = Int(round(1.0 / rawValue))
            return "1/\(denominator)"
        }
    }
}

// MARK: - Metering Mode

/// Modalità di esposimetria
public enum MeteringMode: String, CaseIterable {
    case spot = "Spot"
    case centerWeighted = "Center Weighted"
    case matrix = "Matrix"
    case highlight = "Highlight Priority"
    case shadow = "Shadow Priority"
}

// MARK: - Exposure Reading

/// Lettura esposimetrica
public struct ExposureReading {
    public let ev: EV
    public let zone: Zone
    public let luminance: Double // cd/m²
    public let position: CGPoint?
    
    public init(ev: EV, zone: Zone, luminance: Double, position: CGPoint? = nil) {
        self.ev = ev
        self.zone = zone
        self.luminance = luminance
        self.position = position
    }
}

// MARK: - Exposure Settings

/// Impostazioni di esposizione calcolate
public struct ExposureSettings {
    public let aperture: Double
    public let shutterSpeed: Double
    public let iso: Double
    public let ev: EV
    public let targetZone: Zone
    
    public var description: String {
        let apertureStr = String(format: "f/%.1f", aperture)
        let shutterStr: String
        if shutterSpeed >= 1 {
            shutterStr = String(format: "%.0f\"", shutterSpeed)
        } else {
            let denom = Int(round(1.0 / shutterSpeed))
            shutterStr = "1/\(denom)"
        }
        return "\(apertureStr) | \(shutterStr) | ISO \(Int(iso)) | \(ev) | Target: \(targetZone)"
    }
}

// MARK: - H&D Curve Point

/// Punto su curva Hurter-Driffield
public struct HDCurvePoint {
    public let logH: Double      // Logaritmo esposizione
    public let density: Double   // Densità ottica
    public let zone: Zone?
    
    public init(logH: Double, density: Double, zone: Zone? = nil) {
        self.logH = logH
        self.density = density
        self.zone = zone
    }
}

// MARK: - Panoramic Guidelines

/// Linee guida per composizione panoramica
public struct PanoramicGuidelines {
    public let horizontalThirds: [Double]  // Posizioni y delle linee orizzontali
    public let verticalThirds: [Double]    // Posizioni x delle linee verticali
    public let goldenRatioH: [Double]      // Sezioni auree orizzontali
    public let goldenRatioV: [Double]      // Sezioni auree verticali
    public let horizonLine: Double?        // Linea orizzonte suggerita
}
