// MARK: - Exposure Engine
// Calcoli esposimetrici scientifici per Zone System

import Foundation
import CoreImage

/// Motore di calcolo esposimetrico
public final class ExposureEngine {
    
    // MARK: - Singleton
    public static let shared = ExposureEngine()
    
    // Costanti fisiche
    private let calibrationConstantK: Double = 12.5  // Costante calibrazione esposimetro
    private let calibrationConstantC: Double = 320   // Costante calibrazione luminanza
    private let midGrayReflectance: Double = 0.18    // 18% grigio medio
    
    private init() {}
    
    // MARK: - EV Calculations
    
    /// Calcola EV da apertura, tempo e ISO
    /// Formula: EV = log₂(N² / t) - log₂(S / 100)
    public func calculateEV(aperture: Double, shutterSpeed: Double, iso: Double) -> EV {
        return EV.from(aperture: aperture, shutterSpeed: shutterSpeed, iso: iso)
    }
    
    /// Calcola EV da luminanza (cd/m²) e ISO
    /// Formula: EV = log₂(L × S / K)
    public func calculateEV(fromLuminance luminance: Double, iso: Double) -> EV {
        return EV.from(luminance: luminance, iso: iso, calibrationConstant: calibrationConstantK)
    }
    
    /// Calcola luminanza da EV e ISO
    /// Formula: L = (2^EV × K) / S
    public func calculateLuminance(fromEV ev: EV, iso: Double) -> Double {
        return (pow(2, ev.value) * calibrationConstantK) / iso
    }
    
    // MARK: - Zone Mapping
    
    /// Converte luminanza in Zona del Sistema Zonale
    /// Zone V = grigio medio 18%
    /// Formula: Z = round(log₂(L / L_mid)) + 5
    public func luminanceToZone(_ luminance: Double, midGrayLuminance: Double) -> Zone {
        let zoneValue = round(log2(luminance / midGrayLuminance)) + 5
        let clampedValue = max(0, min(10, Int(zoneValue)))
        return Zone(rawValue: clampedValue) ?? .zoneV
    }
    
    /// Converte EV in Zona
    public func evToZone(_ ev: EV, midGrayEV: EV) -> Zone {
        let zoneValue = round(ev.value - midGrayEV.value) + 5
        let clampedValue = max(0, min(10, Int(zoneValue)))
        return Zone(rawValue: clampedValue) ?? .zoneV
    }
    
    /// Converte Zona in luminanza relativa
    public func zoneToRelativeLuminance(_ zone: Zone) -> Double {
        // Ogni zona è 1 stop di differenza
        // Zone V = 1.0 (riferimento)
        return pow(2, Double(zone.rawValue - 5))
    }
    
    /// Converte Zona in reflectance percentuale
    public func zoneToReflectance(_ zone: Zone) -> Double {
        return zone.reflectance / 100.0
    }
    
    // MARK: - Exposure Settings Calculation
    
    /// Calcola impostazioni esposizione per posizionare una zona specifica
    public func calculateExposureForZone(
        targetZone: Zone,
        actualZone: Zone,
        currentAperture: Double,
        currentShutter: Double,
        iso: Double
    ) -> ExposureSettings {
        let zoneDifference = Double(targetZone.rawValue - actualZone.rawValue)
        let evShift = zoneDifference // 1 zona = 1 EV
        
        // Calcola EV attuale
        let currentEV = calculateEV(aperture: currentAperture, shutterSpeed: currentShutter, iso: iso)
        let targetEV = EV(currentEV.value + evShift)
        
        // Trova combinazione apertura/tempo ottimale
        let combinations = targetEV.toApertureShutterCombo(atISO: iso)
        
        // Scegli la combinazione più vicina all'apertura corrente
        let bestCombo = combinations.min { abs($0.aperture - currentAperture) < abs($1.aperture - currentAperture) }
        ?? (currentAperture, currentShutter * pow(2, -evShift))
        
        return ExposureSettings(
            aperture: bestCombo.aperture,
            shutterSpeed: bestCombo.shutterSpeed,
            iso: iso,
            ev: targetEV,
            targetZone: targetZone
        )
    }
    
    /// Calcola impostazioni per esporre ombre in Zona III (metodo Ansel Adams)
    public func calculateZoneIIExposure(
        shadowLuminance: Double,
        midGrayLuminance: Double,
        iso: Double,
        preferredAperture: Double? = nil
    ) -> ExposureSettings {
        // Determina zona attuale dell'ombra
        let shadowZone = luminanceToZone(shadowLuminance, midGrayLuminance: midGrayLuminance)
        
        // Calcola EV per l'ombra
        let shadowEV = calculateEV(fromLuminance: shadowLuminance, iso: iso)
        
        // Per Zone III, dobbiamo sottoesporre di (shadowZone - III) stop
        let zoneShift = Double(3 - shadowZone.rawValue)
        let targetEV = EV(shadowEV.value + zoneShift)
        
        // Genera impostazioni
        let combinations = targetEV.toApertureShutterCombo(atISO: iso)
        
        let bestCombo: (aperture: Double, shutterSpeed: Double)
        if let preferred = preferredAperture,
           let combo = combinations.first(where: { abs($0.aperture - preferred) < 0.5 }) {
            bestCombo = combo
        } else {
            bestCombo = combinations.first ?? (8.0, 1/125)
        }
        
        return ExposureSettings(
            aperture: bestCombo.aperture,
            shutterSpeed: bestCombo.shutterSpeed,
            iso: iso,
            ev: targetEV,
            targetZone: .zoneIII
        )
    }
    
    // MARK: - Spot Metering Simulation
    
    /// Simula esposimetria spot su un'immagine
    public func spotMeter(
        in image: CIImage,
        at point: CGPoint,
        spotSize: Double = 0.05,  // 5% dell'immagine
        iso: Double
    ) -> ExposureReading? {
        // Estrai regione spot
        let spotRegion = extractSpotRegion(from: image, at: point, size: spotSize)
        
        // Calcola luminanza media della regione
        guard let avgLuminance = calculateAverageLuminance(spotRegion) else { return nil }
        
        // Calcola EV e zona
        let ev = calculateEV(fromLuminance: avgLuminance, iso: iso)
        
        // Determina mid-gray (ipotizziamo esposizione corretta per Zone V)
        let midGrayEV = calculateEV(fromLuminance: avgLuminance * 5, iso: iso) // Approssimazione
        let zone = evToZone(ev, midGrayEV: midGrayEV)
        
        return ExposureReading(ev: ev, zone: zone, luminance: avgLuminance, position: point)
    }
    
    /// Estrai regione spot dall'immagine
    private func extractSpotRegion(from image: CIImage, at point: CGPoint, size: Double) -> CIImage? {
        let width = image.extent.width * CGFloat(size)
        let height = image.extent.height * CGFloat(size)
        let x = point.x * image.extent.width - width / 2
        let y = point.y * image.extent.height - height / 2
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
        return image.cropped(to: rect)
    }
    
    /// Calcola luminanza media
    private func calculateAverageLuminance(_ image: CIImage?) -> Double? {
        guard let image = image else { return nil }
        
        // Semplificazione: usa il filtro area average di Core Image
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)
        
        guard let output = filter?.outputImage else { return nil }
        
        // Estrai valore RGB
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext()
        context.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: output.extent, format: .RGBA8, colorSpace: nil)
        
        // Converte in luminanza (formula ITU-R BT.709)
        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance * 100 // Scala approssimativa a cd/m²
    }
    
    // MARK: - Matrix Metering Simulation
    
    /// Simula esposimetria matrix (valutativa)
    public func matrixMeter(
        in image: CIImage,
        iso: Double,
        sceneType: SceneType = .average
    ) -> [ExposureReading] {
        // Dividi l'immagine in una griglia 5x5
        let gridSize = 5
        var readings: [ExposureReading] = []
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = Double(col) / Double(gridSize) + 0.5 / Double(gridSize)
                let y = Double(row) / Double(gridSize) + 0.5 / Double(gridSize)
                let point = CGPoint(x: x, y: y)
                
                if let reading = spotMeter(in: image, at: point, iso: iso) {
                    readings.append(reading)
                }
            }
        }
        
        // Applica pesi in base al tipo di scena
        return applyMatrixWeights(readings, sceneType: sceneType)
    }
    
    /// Applica pesi matrix in base al tipo di scena
    private func applyMatrixWeights(_ readings: [ExposureReading], sceneType: SceneType) -> [ExposureReading] {
        var weightedReadings = readings
        
        switch sceneType {
        case .backlit:
            // Dai più peso al centro
            for i in 0..<readings.count {
                let isCenter = (i >= 6 && i <= 8) || (i >= 11 && i <= 13) || (i >= 16 && i <= 18)
                if !isCenter {
                    // Riduci peso delle zone periferiche (backlight)
                    let adjustedEV = EV(readings[i].ev.value - 1.0)
                    weightedReadings[i] = ExposureReading(
                        ev: adjustedEV,
                        zone: readings[i].zone,
                        luminance: readings[i].luminance * 0.5,
                        position: readings[i].position
                    )
                }
            }
        case .spotlight:
            // Dai più peso alle zone luminose
            for i in 0..<readings.count {
                if readings[i].zone.rawValue < 6 {
                    // Zone scure: riduci peso
                    let adjustedEV = EV(readings[i].ev.value - 0.5)
                    weightedReadings[i] = ExposureReading(
                        ev: adjustedEV,
                        zone: readings[i].zone,
                        luminance: readings[i].luminance * 0.7,
                        position: readings[i].position
                    )
                }
            }
        default:
            break
        }
        
        return weightedReadings
    }
    
    /// Calcola EV medio da letture matrix
    public func averageEV(from readings: [ExposureReading]) -> EV {
        let sum = readings.reduce(0.0) { $0 + $1.ev.value }
        return EV(sum / Double(readings.count))
    }
    
    // MARK: - Dynamic Range Analysis
    
    /// Analizza range dinamico della scena
    public func analyzeDynamicRange(readings: [ExposureReading]) -> DynamicRangeAnalysis {
        let zones = readings.map { $0.zone }
        let minZone = zones.min() ?? .zoneV
        let maxZone = zones.max() ?? .zoneV
        let zoneSpread = maxZone.rawValue - minZone.rawValue
        
        return DynamicRangeAnalysis(
            minZone: minZone,
            maxZone: maxZone,
            zoneSpread: zoneSpread,
            developmentRecommendation: recommendDevelopment(zoneSpread: zoneSpread),
            readings: readings
        )
    }
    
    /// Raccomanda sviluppo in base allo spread di zone
    private func recommendDevelopment(zoneSpread: Int) -> DevelopmentType {
        switch zoneSpread {
        case ...4:
            return .nPlus1  // Scena piatta, aumenta contrasto
        case 5...7:
            return .nNormal // Range normale
        case 8...9:
            return .nMinus1 // Alto contrasto, riduci
        default:
            return .nMinus2 // Contrasto estremo
        }
    }
    
    // MARK: - Exposure Compensation
    
    /// Calcola compensazione esposizione per posizionare zona
    public func exposureCompensation(
        from currentZone: Zone,
        to targetZone: Zone
    ) -> Double {
        return Double(targetZone.rawValue - currentZone.rawValue)
    }
    
    /// Applica compensazione EV a impostazioni
    public func applyCompensation(
        _ compensation: Double,
        to settings: ExposureSettings
    ) -> ExposureSettings {
        let newEV = EV(settings.ev.value + compensation)
        let combinations = newEV.toApertureShutterCombo(atISO: settings.iso)
        
        // Mantieni apertura simile
        let bestCombo = combinations.min { abs($0.aperture - settings.aperture) < abs($1.aperture - settings.aperture) }
        ?? (settings.aperture, settings.shutterSpeed * pow(2, -compensation))
        
        return ExposureSettings(
            aperture: bestCombo.aperture,
            shutterSpeed: bestCombo.shutterSpeed,
            iso: settings.iso,
            ev: newEV,
            targetZone: settings.targetZone
        )
    }
}

// MARK: - Supporting Types

public enum SceneType {
    case average
    case backlit
    case spotlight
    case lowLight
    case highContrast
}

public struct DynamicRangeAnalysis {
    public let minZone: Zone
    public let maxZone: Zone
    public let zoneSpread: Int
    public let developmentRecommendation: DevelopmentType
    public let readings: [ExposureReading]
    
    public var description: String {
        return """
        Dynamic Range Analysis:
        - Zone Range: \(minZone.rawValue) to \(maxZone.rawValue) (\(zoneSpread) stops)
        - Recommended Development: \(developmentRecommendation.rawValue)
        - Scene Type: \(sceneTypeDescription)
        """
    }
    
    private var sceneTypeDescription: String {
        switch zoneSpread {
        case ...4: return "Low contrast - flat scene"
        case 5...7: return "Normal contrast"
        case 8...9: return "High contrast"
        default: return "Extreme contrast"
        }
    }
}
