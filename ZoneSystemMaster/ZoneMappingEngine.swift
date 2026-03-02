// MARK: - Zone Mapping Engine
// Mappatura pixel in Zone del Sistema Zonale

import Foundation
import CoreImage
import SwiftUI

/// Motore di mappatura Zone per visualizzazione e analisi
public final class ZoneMappingEngine {
    
    public static let shared = ZoneMappingEngine()
    
    // Parametri di calibrazione
    private let gamma: Double = 2.2
    private let zoneVPixelValue: Double = 0.5 // Valore pixel per Zone V (mid-gray)
    
    private init() {}
    
    // MARK: - Zone Mapping
    
    /// Mappa valore pixel (0-1) in Zona
    public func mapPixelToZone(_ pixelValue: Double, exposureCompensation: Double = 0) -> Zone {
        // Applica gamma correction inversa per ottenere luminanza lineare
        let linearLuminance = pow(pixelValue, gamma)
        
        // Applica compensazione esposizione
        let adjustedLuminance = linearLuminance * pow(2, exposureCompensation)
        
        // Calcola zona: ogni zona è 1 stop (2x luminanza)
        // Zone V = mid-gray = 18% reflectance
        let zoneValue = round(log2(adjustedLuminance / zoneVPixelValue)) + 5
        let clampedValue = max(0, min(10, Int(zoneValue)))
        
        return Zone(rawValue: clampedValue) ?? .zoneV
    }
    
    /// Mappa Zona in valore pixel per visualizzazione
    public func mapZoneToPixel(_ zone: Zone, exposureCompensation: Double = 0) -> Double {
        // Luminanza relativa alla zona
        let relativeLuminance = pow(2, Double(zone.rawValue - 5))
        
        // Applica compensazione
        let adjustedLuminance = relativeLuminance * zoneVPixelValue * pow(2, -exposureCompensation)
        
        // Applica gamma
        let pixelValue = pow(adjustedLuminance, 1.0 / gamma)
        
        return max(0, min(1, pixelValue))
    }
    
    // MARK: - Image Zone Mapping
    
    /// Crea mappa zone da immagine
    public func createZoneMap(
        from image: CIImage,
        exposureCompensation: Double = 0
    ) -> ZoneMap {
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        
        // Converti in array di pixel
        guard let pixelData = extractPixelData(from: image) else {
            return ZoneMap(width: 0, height: 0, zones: [], histogram: [:])
        }
        
        var zones: [Zone] = []
        var histogram: [Zone: Int] = [:]
        
        for pixel in pixelData {
            let zone = mapPixelToZone(pixel, exposureCompensation: exposureCompensation)
            zones.append(zone)
            histogram[zone, default: 0] += 1
        }
        
        return ZoneMap(
            width: width,
            height: height,
            zones: zones,
            histogram: histogram
        )
    }
    
    /// Estrae dati pixel dall'immagine (luminanza)
    private func extractPixelData(from image: CIImage) -> [Double]? {
        let context = CIContext()
        
        // Converti in scala di grigi
        guard let grayscale = convertToGrayscale(image, context: context) else { return nil }
        
        let width = Int(grayscale.extent.width)
        let height = Int(grayscale.extent.height)
        
        var pixelData = [UInt8](repeating: 0, count: width * height)
        
        context.render(
            grayscale,
            toBitmap: &pixelData,
            rowBytes: width,
            bounds: grayscale.extent,
            format: .A8,
            colorSpace: nil
        )
        
        return pixelData.map { Double($0) / 255.0 }
    }
    
    /// Converte immagine in scala di grigi
    private func convertToGrayscale(_ image: CIImage, context: CIContext) -> CIImage? {
        let filter = CIFilter(name: "CIPhotoEffectMono")
        filter?.setValue(image, forKey: kCIInputImageKey)
        return filter?.outputImage
    }
    
    // MARK: - Zone Overlay Generation
    
    /// Genera overlay colorato delle zone
    public func generateZoneOverlay(
        zoneMap: ZoneMap,
        style: OverlayStyle = .colorCoded
    ) -> CIImage? {
        let width = zoneMap.width
        let height = zoneMap.height
        
        guard width > 0 && height > 0 else { return nil }
        
        var pixelBytes = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let zone = zoneMap.zones[index]
                let color = style.colorForZone(zone)
                
                let pixelIndex = index * 4
                pixelBytes[pixelIndex] = color.r
                pixelBytes[pixelIndex + 1] = color.g
                pixelBytes[pixelIndex + 2] = color.b
                pixelBytes[pixelIndex + 3] = color.a
            }
        }
        
        guard let provider = CGDataProvider(data: Data(pixelBytes) as CFData) else { return nil }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }
        
        return CIImage(cgImage: cgImage)
    }
    
    /// Genera overlay con linee di contorno zone
    public func generateZoneContourOverlay(
        zoneMap: ZoneMap,
        lineColor: ZoneColor = ZoneColor(r: 255, g: 0, b: 0, a: 128)
    ) -> CIImage? {
        let width = zoneMap.width
        let height = zoneMap.height
        
        guard width > 0 && height > 0 else { return nil }
        
        var pixelBytes = [UInt8](repeating: 0, count: width * height * 4)
        
        // Trova i bordi tra zone diverse
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                let currentZone = zoneMap.zones[index]
                
                // Controlla i vicini
                let neighbors = [
                    zoneMap.zones[(y - 1) * width + x],
                    zoneMap.zones[(y + 1) * width + x],
                    zoneMap.zones[y * width + (x - 1)],
                    zoneMap.zones[y * width + (x + 1)]
                ]
                
                // Se almeno un vicino è diverso, è un bordo
                let isEdge = neighbors.contains { $0 != currentZone }
                
                let pixelIndex = index * 4
                if isEdge {
                    pixelBytes[pixelIndex] = lineColor.r
                    pixelBytes[pixelIndex + 1] = lineColor.g
                    pixelBytes[pixelIndex + 2] = lineColor.b
                    pixelBytes[pixelIndex + 3] = lineColor.a
                } else {
                    pixelBytes[pixelIndex + 3] = 0 // Trasparente
                }
            }
        }
        
        guard let provider = CGDataProvider(data: Data(pixelBytes) as CFData) else { return nil }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }
        
        return CIImage(cgImage: cgImage)
    }
    
    // MARK: - Zone Analysis
    
    /// Analizza distribuzione zone nell'immagine
    public func analyzeZoneDistribution(zoneMap: ZoneMap) -> ZoneAnalysis {
        let totalPixels = zoneMap.zones.count
        var distribution: [Zone: Double] = [:]
        var dominantZones: [Zone] = []
        
        for (zone, count) in zoneMap.histogram {
            let percentage = Double(count) / Double(totalPixels) * 100
            distribution[zone] = percentage
            
            if percentage > 15 { // Zone che occupano più del 15%
                dominantZones.append(zone)
            }
        }
        
        dominantZones.sort { distribution[$0] ?? 0 > distribution[$1] ?? 0 }
        
        // Calcola zone min e max presenti
        let presentZones = zoneMap.histogram.keys.sorted()
        let minZone = presentZones.first ?? .zoneV
        let maxZone = presentZones.last ?? .zoneV
        
        return ZoneAnalysis(
            distribution: distribution,
            dominantZones: dominantZones,
            minZone: minZone,
            maxZone: maxZone,
            zoneSpread: maxZone.rawValue - minZone.rawValue,
            totalPixels: totalPixels
        )
    }
    
    /// Suggerisce esposizione per posizionare ombre in Zona III
    public func suggestExposureForZoneIII(zoneMap: ZoneMap) -> ExposureSuggestion {
        let analysis = analyzeZoneDistribution(zoneMap: zoneMap)
        
        // Trova la zona più scura con dettaglio (escludi Zone 0-I)
        let shadowZones = zoneMap.histogram.keys.filter { $0.rawValue >= 2 && $0.rawValue <= 4 }
        let darkestShadow = shadowZones.min() ?? .zoneIII
        
        // Calcola shift necessario per portare in Zona III
        let zoneShift = 3 - darkestShadow.rawValue
        
        return ExposureSuggestion(
            currentDarkestShadow: darkestShadow,
            targetZone: .zoneIII,
            suggestedShift: Double(zoneShift),
            reasoning: "Posiziona l'ombra più scura con dettaglio (\(darkestShadow)) in Zona III per preservare texture"
        )
    }
    
    /// Suggerisce esposizione per proteggere luci
    public func suggestExposureForHighlights(zoneMap: ZoneMap) -> ExposureSuggestion {
        let analysis = analyzeZoneDistribution(zoneMap: zoneMap)
        
        // Trova la zona più luminosa con dettaglio (escludi Zone IX-X)
        let highlightZones = zoneMap.histogram.keys.filter { $0.rawValue >= 6 && $0.rawValue <= 8 }
        let brightestHighlight = highlightZones.max() ?? .zoneVII
        
        // Calcola shift necessario per portare in Zona VII-VIII
        let zoneShift = 7 - brightestHighlight.rawValue
        
        return ExposureSuggestion(
            currentBrightestHighlight: brightestHighlight,
            targetZone: .zoneVII,
            suggestedShift: Double(zoneShift),
            reasoning: "Protegge le luci più brillanti (\(brightestHighlight)) mantenendo dettaglio in Zona VII"
        )
    }
    
    // MARK: - Zone Visualization
    
    /// Genera gradiente di riferimento zone
    public func generateZoneScaleImage(width: Int = 400, height: Int = 60) -> CIImage? {
        var pixelBytes = [UInt8](repeating: 0, count: width * height * 4)
        
        let zoneWidth = width / 11
        
        for y in 0..<height {
            for x in 0..<width {
                let zoneIndex = min(x / zoneWidth, 10)
                let zone = Zone(rawValue: zoneIndex) ?? .zoneV
                let pixelValue = mapZoneToPixel(zone)
                
                let gray = UInt8(pixelValue * 255)
                let pixelIndex = (y * width + x) * 4
                pixelBytes[pixelIndex] = gray
                pixelBytes[pixelIndex + 1] = gray
                pixelBytes[pixelIndex + 2] = gray
                pixelBytes[pixelIndex + 3] = 255
            }
        }
        
        guard let provider = CGDataProvider(data: Data(pixelBytes) as CFData) else { return nil }
        
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }
        
        return CIImage(cgImage: cgImage)
    }
}

// MARK: - Supporting Types

/// Mappa delle zone per un'immagine
public struct ZoneMap {
    public let width: Int
    public let height: Int
    public let zones: [Zone]
    public let histogram: [Zone: Int]
    
    public func zoneAt(x: Int, y: Int) -> Zone? {
        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
        return zones[y * width + x]
    }
}

/// Stili di overlay per visualizzazione zone
public enum OverlayStyle {
    case colorCoded
    case grayscale
    case heatmap
    case contour
    
    public func colorForZone(_ zone: Zone) -> ZoneColor {
        switch self {
        case .colorCoded:
            return zoneColorCoded(zone)
        case .grayscale:
            let gray = UInt8(Double(zone.rawValue) / 10.0 * 255)
            return ZoneColor(r: gray, g: gray, b: gray, a: 200)
        case .heatmap:
            return zoneHeatmapColor(zone)
        case .contour:
            let gray = UInt8(Double(zone.rawValue) / 10.0 * 255)
            return ZoneColor(r: gray, g: gray, b: gray, a: 255)
        }
    }
    
    private func zoneColorCoded(_ zone: Zone) -> ZoneColor {
        // Colori Ansel Adams tradizionali
        switch zone {
        case .zone0: return ZoneColor(r: 0, g: 0, b: 0, a: 255)
        case .zoneI: return ZoneColor(r: 25, g: 25, b: 25, a: 255)
        case .zoneII: return ZoneColor(r: 50, g: 50, b: 50, a: 255)
        case .zoneIII: return ZoneColor(r: 75, g: 75, b: 100, a: 200) // Blu per ombre
        case .zoneIV: return ZoneColor(r: 100, g: 100, b: 100, a: 200)
        case .zoneV: return ZoneColor(r: 128, g: 128, b: 128, a: 200)
        case .zoneVI: return ZoneColor(r: 160, g: 160, b: 160, a: 200)
        case .zoneVII: return ZoneColor(r: 200, g: 200, b: 150, a: 200) // Giallo per luci
        case .zoneVIII: return ZoneColor(r: 220, g: 220, b: 100, a: 200)
        case .zoneIX: return ZoneColor(r: 240, g: 240, b: 50, a: 200)
        case .zoneX: return ZoneColor(r: 255, g: 255, b: 255, a: 255)
        }
    }
    
    private func zoneHeatmapColor(_ zone: Zone) -> ZoneColor {
        // Heatmap: blu (freddo) a rosso (caldo)
        let t = Double(zone.rawValue) / 10.0
        let r = UInt8(min(255, t * 2 * 255))
        let b = UInt8(min(255, (1 - t) * 2 * 255))
        let g = UInt8(min(255, 255 - abs(Int(r) - Int(b))))
        return ZoneColor(r: r, g: g, b: b, a: 200)
    }
}

/// Colore RGBA per pixel
public struct ZoneColor {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8
    public let a: UInt8
}

/// Analisi distribuzione zone
public struct ZoneAnalysis {
    public let distribution: [Zone: Double]
    public let dominantZones: [Zone]
    public let minZone: Zone
    public let maxZone: Zone
    public let zoneSpread: Int
    public let totalPixels: Int
    
    public var description: String {
        return """
        Zone Analysis:
        - Zone Range: \(minZone.rawValue) to \(maxZone.rawValue) (\(zoneSpread) stops)
        - Dominant Zones: \(dominantZones.map { "Z\($0.rawValue)" }.joined(separator: ", "))
        - Total Pixels: \(totalPixels)
        """
    }
}

/// Suggerimento esposizione
public struct ExposureSuggestion {
    public let currentDarkestShadow: Zone?
    public let currentBrightestHighlight: Zone?
    public let targetZone: Zone
    public let suggestedShift: Double
    public let reasoning: String
    
    public init(
        currentDarkestShadow: Zone? = nil,
        currentBrightestHighlight: Zone? = nil,
        targetZone: Zone,
        suggestedShift: Double,
        reasoning: String
    ) {
        self.currentDarkestShadow = currentDarkestShadow
        self.currentBrightestHighlight = currentBrightestHighlight
        self.targetZone = targetZone
        self.suggestedShift = suggestedShift
        self.reasoning = reasoning
    }
    
    public var description: String {
        let direction = suggestedShift > 0 ? "sottoesponi" : "sovraesponi"
        return """
        Exposure Suggestion:
        - \(reasoning)
        - \(direction) di \(abs(suggestedShift)) stop
        - Target: \(targetZone)
        """
    }
}
