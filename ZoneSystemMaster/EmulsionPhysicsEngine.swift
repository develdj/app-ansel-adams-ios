// MARK: - Emulsion Physics Engine
// Simulazione fisica emulsione fotografica e curve H&D

import Foundation
import SwiftUI

/// Motore di simulazione fisica emulsione fotografica
public final class EmulsionPhysicsEngine {
    
    public static let shared = EmulsionPhysicsEngine()
    
    // Costanti fisiche
    private let referenceTemperature: Double = 20.0 // °C
    private let logHZoneStep: Double = 0.3 // Step logH tra zone (basato su 1 stop = 0.3 logH)
    
    private init() {}
    
    // MARK: - H&D Curve Calculations
    
    /// Calcola densità da logH usando curva H&D
    /// Formula generale: D = Dmin + (Dmax - Dmin) * (1 - exp(-γ * logH_eff))
    public func calculateDensity(
        logH: Double,
        film: FilmType,
        development: DevelopmentType,
        temperature: Double = 20.0
    ) -> Double {
        let gamma = calculateGamma(film: film, development: development, temperature: temperature)
        let toeLength = film.toeLength
        let shoulderStart = film.shoulderStart
        
        // Regione toe (parte inferiore curva)
        if logH < toeLength {
            return calculateToeRegion(logH: logH, film: film, gamma: gamma, toeLength: toeLength)
        }
        
        // Regione lineare (gamma)
        if logH < shoulderStart {
            return calculateLinearRegion(logH: logH, film: film, gamma: gamma, toeLength: toeLength)
        }
        
        // Regione shoulder (saturazione)
        return calculateShoulderRegion(logH: logH, film: film, gamma: gamma, shoulderStart: shoulderStart)
    }
    
    /// Calcola gamma effettivo con temperatura
    public func calculateGamma(
        film: FilmType,
        development: DevelopmentType,
        temperature: Double = 20.0
    ) -> Double {
        let baseGamma = film.gammaN * development.gammaMultiplier
        
        // Effetto temperatura: Δγ ∝ (T − 20°C) × coeff_emulsione
        let tempDelta = temperature - referenceTemperature
        let tempEffect = 1.0 + (tempDelta * film.temperatureCoefficient)
        
        return baseGamma * tempEffect
    }
    
    /// Calcola tempo di sviluppo corretto
    public func calculateDevelopmentTime(
        film: FilmType,
        development: DevelopmentType,
        temperature: Double = 20.0
    ) -> Double {
        let baseTime = film.developmentTimeN * development.timeMultiplier
        
        // Correzione temperatura (regola del fattore 2 per 10°C)
        let tempDelta = temperature - referenceTemperature
        let tempFactor = pow(2.0, tempDelta / 10.0)
        
        return baseTime / tempFactor
    }
    
    // MARK: - Curve Region Calculations
    
    /// Regione toe - transizione da Dmin a lineare
    private func calculateToeRegion(
        logH: Double,
        film: FilmType,
        gamma: Double,
        toeLength: Double
    ) -> Double {
        // Modello toe: transizione quadratica smooth
        let t = logH / toeLength
        let toeFactor = t * t * (3 - 2 * t) // Smoothstep function
        
        let linearDensity = film.dMin + gamma * (logH - toeLength * 0.5)
        return film.dMin + (linearDensity - film.dMin) * toeFactor
    }
    
    /// Regione lineare - risposta proporzionale a logH
    private func calculateLinearRegion(
        logH: Double,
        film: FilmType,
        gamma: Double,
        toeLength: Double
    ) -> Double {
        // Offset per compensare toe
        let toeOffset = toeLength * 0.3
        return film.dMin + gamma * (logH - toeOffset)
    }
    
    /// Regione shoulder - saturazione verso Dmax
    private func calculateShoulderRegion(
        logH: Double,
        film: FilmType,
        gamma: Double,
        shoulderStart: Double
    ) -> Double {
        let shoulderWidth = 1.0
        let t = (logH - shoulderStart) / shoulderWidth
        
        // Transizione smooth verso Dmax
        let shoulderFactor = exp(-t * t)
        let linearDensity = film.dMin + gamma * (shoulderStart - film.toeLength * 0.3)
        
        return film.dMax - (film.dMax - linearDensity) * shoulderFactor
    }
    
    // MARK: - Zone-based Curve Generation
    
    /// Genera curva H&D completa per tutte le zone
    public func generateHDCurve(
        film: FilmType,
        development: DevelopmentType,
        temperature: Double = 20.0,
        steps: Int = 100
    ) -> [HDCurvePoint] {
        var points: [HDCurvePoint] = []
        
        // Range logH: da Zone 0 a Zone X
        // Zone V = logH = 1.5 (riferimento)
        let minLogH: Double = 0.0
        let maxLogH: Double = 3.0
        
        for i in 0..<steps {
            let logH = minLogH + (maxLogH - minLogH) * Double(i) / Double(steps - 1)
            let density = calculateDensity(logH: logH, film: film, development: development, temperature: temperature)
            
            // Mappa logH a zona
            let zone = logHToZone(logH)
            
            points.append(HDCurvePoint(logH: logH, density: density, zone: zone))
        }
        
        return points
    }
    
    /// Converte logH in Zona
    private func logHToZone(_ logH: Double) -> Zone? {
        // Zone V corrisponde a logH ≈ 1.5
        // Ogni zona = 0.3 logH (1 stop)
        let zoneValue = round((logH - 1.5) / 0.3 + 5)
        let clampedValue = max(0, min(10, Int(zoneValue)))
        return Zone(rawValue: clampedValue)
    }
    
    /// Converte Zona in logH
    public func zoneToLogH(_ zone: Zone) -> Double {
        return 1.5 + Double(zone.rawValue - 5) * 0.3
    }
    
    // MARK: - Film Characteristic Curves
    
    /// Genera curve caratteristiche per confronto pellicole
    public func generateComparisonCurves(
        films: [FilmType],
        development: DevelopmentType = .nNormal
    ) -> [FilmType: [HDCurvePoint]] {
        var curves: [FilmType: [HDCurvePoint]] = [:]
        
        for film in films {
            curves[film] = generateHDCurve(film: film, development: development)
        }
        
        return curves
    }
    
    /// Genera famiglia di curve per uno stesso film (N, N+, N-)
    public func generateDevelopmentFamily(
        film: FilmType,
        temperatures: [Double] = [18.0, 20.0, 22.0, 24.0]
    ) -> [DevelopmentType: [HDCurvePoint]] {
        var families: [DevelopmentType: [HDCurvePoint]] = [:]
        
        for development in DevelopmentType.allCases {
            families[development] = generateHDCurve(film: film, development: development)
        }
        
        return families
    }
    
    // MARK: - Sensitivity Analysis
    
    /// Analizza sensitività della pellicola
    public func analyzeSensitivity(film: FilmType) -> SensitivityAnalysis {
        let curveN = generateHDCurve(film: film, development: .nNormal)
        
        // Trova gamma effettivo (pendenza lineare)
        let gamma = calculateGamma(film: film, development: .nNormal)
        
        // Calcola ISO effettivo (basato su punto di densità 0.1 sopra Dmin)
        let speedPointDensity = film.dMin + 0.1
        let speedPointLogH = findLogH(forDensity: speedPointDensity, in: curveN)
        let effectiveISO = 0.8 / pow(10, speedPointLogH) * Double(film.nominalISO) / 100.0
        
        // Range dinamico (distanza tra Dmin+0.1 e Dmax-0.1)
        let minDensity = film.dMin + 0.1
        let maxDensity = film.dMax - 0.1
        let minLogH = findLogH(forDensity: minDensity, in: curveN)
        let maxLogH = findLogH(forDensity: maxDensity, in: curveN)
        let dynamicRange = maxLogH - minLogH
        
        return SensitivityAnalysis(
            film: film,
            gamma: gamma,
            effectiveISO: effectiveISO,
            dynamicRange: dynamicRange,
            speedPointLogH: speedPointLogH,
            dMin: film.dMin,
            dMax: film.dMax
        )
    }
    
    /// Trova logH per una densità target (ricerca binaria)
    private func findLogH(forDensity targetDensity: Double, in curve: [HDCurvePoint]) -> Double {
        var low = 0
        var high = curve.count - 1
        
        while low < high {
            let mid = (low + high) / 2
            if curve[mid].density < targetDensity {
                low = mid + 1
            } else {
                high = mid
            }
        }
        
        return curve[min(low, curve.count - 1)].logH
    }
    
    // MARK: - Exposure Latitude
    
    /// Calcola latitudine di esposizione
    public func calculateExposureLatitude(
        film: FilmType,
        development: DevelopmentType,
        minAcceptableDensity: Double = 0.3,
        maxAcceptableDensity: Double = 1.5
    ) -> ExposureLatitude {
        let curve = generateHDCurve(film: film, development: development)
        
        let minLogH = findLogH(forDensity: minAcceptableDensity, in: curve)
        let maxLogH = findLogH(forDensity: maxAcceptableDensity, in: curve)
        
        let latitudeStops = (maxLogH - minLogH) / 0.3
        
        return ExposureLatitude(
            minLogH: minLogH,
            maxLogH: maxLogH,
            latitudeStops: latitudeStops,
            film: film,
            development: development
        )
    }
    
    // MARK: - Paper Response Simulation
    
    /// Simula curva di risposta carta fotografica
    public func generatePaperCurve(
        paperGrade: PaperGrade,
        exposureRange: ClosedRange<Double> = 0.0...2.5
    ) -> [PaperCurvePoint] {
        var points: [PaperCurvePoint] = []
        let steps = 100
        
        for i in 0..<steps {
            let logE = exposureRange.lowerBound + 
                (exposureRange.upperBound - exposureRange.lowerBound) * Double(i) / Double(steps - 1)
            let density = calculatePaperDensity(logE: logE, grade: paperGrade)
            points.append(PaperCurvePoint(logE: logE, density: density))
        }
        
        return points
    }
    
    /// Calcola densità carta da logE
    private func calculatePaperDensity(logE: Double, grade: PaperGrade) -> Double {
        let dMax = grade.maxDensity
        let dMin = grade.minDensity
        let gamma = grade.contrastIndex
        
        // Modello sigmoidale per carta
        let midpoint = grade.midpointLogE
        let steepness = gamma * 2.0
        
        let normalized = 1.0 / (1.0 + exp(-steepness * (logE - midpoint)))
        return dMin + (dMax - dMin) * normalized
    }
    
    // MARK: - Split Grade Printing
    
    /// Calcola esposizione split grade
    public func calculateSplitGradeExposure(
        negativeDensityRange: ClosedRange<Double>,
        paperGrades: (soft: PaperGrade, hard: PaperGrade),
        targetDensityRange: ClosedRange<Double> = 0.2...2.0
    ) -> SplitGradeExposure {
        // Calcola esposizione per grado soft (gestisce luci)
        let softExposure = calculateGradeExposure(
            grade: paperGrades.soft,
            negativeRange: negativeDensityRange,
            targetRange: targetDensityRange
        )
        
        // Calcola esposizione per grado hard (gestisce ombre)
        let hardExposure = calculateGradeExposure(
            grade: paperGrades.hard,
            negativeRange: negativeDensityRange,
            targetRange: targetDensityRange
        )
        
        return SplitGradeExposure(
            softGradeExposure: softExposure,
            hardGradeExposure: hardExposure,
            softGrade: paperGrades.soft,
            hardGrade: paperGrades.hard
        )
    }
    
    private func calculateGradeExposure(
        grade: PaperGrade,
        negativeRange: ClosedRange<Double>,
        targetRange: ClosedRange<Double>
    ) -> Double {
        // Semplificazione: calcola esposizione media necessaria
        let midNegative = (negativeRange.lowerBound + negativeRange.upperBound) / 2
        return pow(10, grade.midpointLogE - midNegative)
    }
}

// MARK: - Paper Grade

/// Gradi di contrasto carta fotografica
public enum PaperGrade: String, CaseIterable {
    case grade00 = "00"
    case grade0 = "0"
    case grade1 = "1"
    case grade2 = "2"
    case grade3 = "3"
    case grade4 = "4"
    case grade5 = "5"
    
    public var contrastIndex: Double {
        switch self {
        case .grade00: return 0.8
        case .grade0: return 1.0
        case .grade1: return 1.3
        case .grade2: return 1.6
        case .grade3: return 2.0
        case .grade4: return 2.5
        case .grade5: return 3.2
        }
    }
    
    public var maxDensity: Double {
        return 2.0
    }
    
    public var minDensity: Double {
        return 0.05
    }
    
    public var midpointLogE: Double {
        switch self {
        case .grade00: return 1.8
        case .grade0: return 1.6
        case .grade1: return 1.4
        case .grade2: return 1.2
        case .grade3: return 1.0
        case .grade4: return 0.8
        case .grade5: return 0.6
        }
    }
    
    public var description: String {
        switch self {
        case .grade00: return "Grade 00: Extra Soft"
        case .grade0: return "Grade 0: Soft"
        case .grade1: return "Grade 1: Normal Soft"
        case .grade2: return "Grade 2: Normal"
        case .grade3: return "Grade 3: Normal Hard"
        case .grade4: return "Grade 4: Hard"
        case .grade5: return "Grade 5: Extra Hard"
        }
    }
}

/// Punto curva carta
public struct PaperCurvePoint {
    public let logE: Double      // Log esposizione
    public let density: Double   // Densità riflessa
}

/// Esposizione split grade
public struct SplitGradeExposure {
    public let softGradeExposure: Double
    public let hardGradeExposure: Double
    public let softGrade: PaperGrade
    public let hardGrade: PaperGrade
    
    public var totalExposure: Double {
        return softGradeExposure + hardGradeExposure
    }
    
    public var softPercentage: Double {
        return softGradeExposure / totalExposure * 100
    }
    
    public var description: String {
        return """
        Split Grade Printing:
        - Soft (\(softGrade.rawValue)): \(String(format: "%.1f", softGradeExposure))s (\(String(format: "%.0f", softPercentage))%)
        - Hard (\(hardGrade.rawValue)): \(String(format: "%.1f", hardGradeExposure))s (\(String(format: "%.0f", 100 - softPercentage))%)
        """
    }
}

// MARK: - Analysis Results

/// Analisi sensitività pellicola
public struct SensitivityAnalysis {
    public let film: FilmType
    public let gamma: Double
    public let effectiveISO: Double
    public let dynamicRange: Double // in logH
    public let speedPointLogH: Double
    public let dMin: Double
    public let dMax: Double
    
    public var dynamicRangeStops: Double {
        return dynamicRange / 0.3
    }
    
    public var description: String {
        return """
        Sensitivity Analysis: \(film.rawValue)
        - Gamma (N): \(String(format: "%.2f", gamma))
        - Effective ISO: \(String(format: "%.0f", effectiveISO))
        - Dynamic Range: \(String(format: "%.1f", dynamicRangeStops)) stops
        - Dmin: \(String(format: "%.2f", dMin))
        - Dmax: \(String(format: "%.2f", dMax))
        """
    }
}

/// Latitudine di esposizione
public struct ExposureLatitude {
    public let minLogH: Double
    public let maxLogH: Double
    public let latitudeStops: Double
    public let film: FilmType
    public let development: DevelopmentType
    
    public var description: String {
        return """
        Exposure Latitude: \(film.rawValue) - \(development.rawValue)
        - Latitude: \(String(format: "%.1f", latitudeStops)) stops
        - Acceptable logH range: \(String(format: "%.2f", minLogH)) to \(String(format: "%.2f", maxLogH))
        """
    }
}
