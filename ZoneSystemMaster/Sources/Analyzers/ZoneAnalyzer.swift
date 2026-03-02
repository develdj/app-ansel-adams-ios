// MARK: - Zone Analyzer
// Calcolo distribuzione zone tonali con mappatura pixel-per-pixel
// Swift 6.0 - Apple Intelligence On-Device

import Foundation
import CoreImage
import UIKit
import Accelerate

/// Analyzer per il calcolo della distribuzione delle zone tonali
@MainActor
public final class ZoneAnalyzer {
    
    // MARK: - Properties
    
    private let context: CIContext
    private let zoneThresholds: [UInt8]
    
    // Cache per performance
    private var analysisCache: [String: ZoneDistribution] = [:]
    private let cacheQueue = DispatchQueue(label: "zonesystem.cache", attributes: .concurrent)
    
    // MARK: - Initialization
    
    public init(context: CIContext? = nil) {
        self.context = context ?? CIContext(options: [
            .workingColorSpace: CGColorSpaceCreateDeviceGray(),
            .workingFormat: CIFormat.L8
        ])
        
        // Soglie per ogni zona (valori RGB)
        self.zoneThresholds = [
            0,    // Zone 0: 0
            25,   // Zone 1: 1-25
            50,   // Zone 2: 26-50
            75,   // Zone 3: 51-75
            100,  // Zone 4: 76-100
            128,  // Zone 5: 101-128
            155,  // Zone 6: 129-155
            180,  // Zone 7: 156-180
            205,  // Zone 8: 181-205
            230,  // Zone 9: 206-230
            255   // Zone 10: 231-255
        ]
    }
    
    // MARK: - Public Methods
    
    /// Analizza la distribuzione delle zone di un'immagine
    public func analyze(image: UIImage) async throws -> ZoneDistribution {
        guard let cgImage = image.cgImage else {
            throw ZoneAnalysisError.invalidImage
        }
        
        // Verifica cache
        let cacheKey = "\(cgImage.width)x\(cgImage.height)-\(cgImage.hashValue)"
        if let cached = getCachedAnalysis(for: cacheKey) {
            return cached
        }
        
        // Converti in scala di grigi
        guard let grayImage = convertToGrayscale(cgImage) else {
            throw ZoneAnalysisError.conversionFailed
        }
        
        // Calcola istogramma
        let histogram = try await calculateHistogram(for: grayImage)
        
        // Calcola distribuzione zone
        let distribution = calculateZoneDistribution(from: histogram, totalPixels: cgImage.width * cgImage.height)
        
        // Genera heatmap
        let heatmap = await generateZoneHeatmap(from: grayImage, size: image.size)
        
        let zoneDistribution = ZoneDistribution(
            percentages: distribution,
            zoneHeatmap: heatmap
        )
        
        // Salva in cache
        setCachedAnalysis(zoneDistribution, for: cacheKey)
        
        return zoneDistribution
    }
    
    /// Analizza una specifica regione dell'immagine
    public func analyzeRegion(image: UIImage, region: CGRect) async throws -> ZoneDistribution {
        guard let cgImage = image.cgImage?.cropping(to: region) else {
            throw ZoneAnalysisError.invalidRegion
        }
        
        let regionImage = UIImage(cgImage: cgImage)
        return try await analyze(image: regionImage)
    }
    
    /// Calcola la zona di un punto specifico
    public func zoneAtPoint(image: UIImage, point: CGPoint) -> Zone? {
        guard let cgImage = image.cgImage else { return nil }
        
        let pixelData = cgImage.dataProvider?.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        let pixelIndex = Int(point.y) * bytesPerRow + Int(point.x) * bytesPerPixel
        let luminance = data[pixelIndex]
        
        return zoneFromLuminance(luminance)
    }
    
    /// Genera un'immagine con overlay delle zone
    public func generateZoneOverlay(image: UIImage, opacity: CGFloat = 0.5) async -> UIImage? {
        guard let zoneDistribution = try? await analyze(image: image),
              let heatmap = zoneDistribution.zoneHeatmap else {
            return nil
        }
        
        let heatmapImage = UIImage(ciImage: heatmap)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        // Disegna immagine originale
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        // Sovrapponi heatmap
        heatmapImage.draw(in: CGRect(origin: .zero, size: image.size), blendMode: .overlay, alpha: opacity)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - Private Methods
    
    private func convertToGrayscale(_ cgImage: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: cgImage)
        
        // Applica filtro scala di grigi
        guard let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono") else {
            return nil
        }
        
        grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = grayscaleFilter.outputImage,
              let cgOutput = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return cgOutput
    }
    
    private func calculateHistogram(for cgImage: CGImage) async throws -> [UInt32] {
        guard let provider = cgImage.dataProvider,
              let data = provider.data else {
            throw ZoneAnalysisError.dataAccessFailed
        }
        
        let bytes = CFDataGetBytePtr(data)
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        let bitsPerComponent = cgImage.bitsPerComponent
        
        var histogram = [UInt32](repeating: 0, count: 256)
        
        // Calcolo istogramma con Accelerate per performance
        await Task.detached {
            var srcBuffer = vImage_Buffer(
                data: UnsafeMutableRawPointer(mutating: bytes),
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: bytesPerRow
            )
            
            var histogramBins = [vImagePixelCount](repeating: 0, count: 256)
            
            let error = vImageHistogramCalculation_Planar8(
                &srcBuffer,
                &histogramBins,
                vImage_Flags(kvImageNoFlags)
            )
            
            guard error == kvImageNoError else { return }
            
            for i in 0..<256 {
                histogram[i] = UInt32(histogramBins[i])
            }
        }.value
        
        return histogram
    }
    
    private func calculateZoneDistribution(from histogram: [UInt32], totalPixels: Int) -> [Zone: Double] {
        var distribution: [Zone: Double] = [:]
        
        for zone in Zone.allCases {
            let range = rangeForZone(zone)
            let pixelCount = range.reduce(0) { $0 + Int(histogram[$1]) }
            let percentage = (Double(pixelCount) / Double(totalPixels)) * 100
            distribution[zone] = percentage
        }
        
        return distribution
    }
    
    private func rangeForZone(_ zone: Zone) -> ClosedRange<Int> {
        switch zone {
        case .zone0: return 0...0
        case .zone1: return 1...25
        case .zone2: return 26...50
        case .zone3: return 51...75
        case .zone4: return 76...100
        case .zone5: return 101...128
        case .zone6: return 129...155
        case .zone7: return 156...180
        case .zone8: return 181...205
        case .zone9: return 206...230
        case .zone10: return 231...255
        }
    }
    
    private func zoneFromLuminance(_ luminance: UInt8) -> Zone {
        switch luminance {
        case 0: return .zone0
        case 1...25: return .zone1
        case 26...50: return .zone2
        case 51...75: return .zone3
        case 76...100: return .zone4
        case 101...128: return .zone5
        case 129...155: return .zone6
        case 156...180: return .zone7
        case 181...205: return .zone8
        case 206...230: return .zone9
        default: return .zone10
        }
    }
    
    private func generateZoneHeatmap(from cgImage: CGImage, size: CGSize) async -> CIImage? {
        let ciImage = CIImage(cgImage: cgImage)
        
        // Crea lookup table per mappare luminanza a colore zona
        let lut = createZoneColorLUT()
        
        // Applica color mapping
        guard let colorCubeFilter = CIFilter(name: "CIColorCube") else {
            return nil
        }
        
        let cubeSize = 64
        colorCubeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        colorCubeFilter.setValue(cubeSize, forKey: "inputCubeDimension")
        colorCubeFilter.setValue(lut, forKey: "inputCubeData")
        
        guard let outputImage = colorCubeFilter.outputImage else {
            return nil
        }
        
        // Scala alla dimensione originale
        let scaleX = size.width / CGFloat(cgImage.width)
        let scaleY = size.height / CGFloat(cgImage.height)
        
        return outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
    
    private func createZoneColorLUT() -> Data {
        // Crea una color cube che mappa luminanza a colori zona
        let cubeSize = 64
        let dataSize = cubeSize * cubeSize * cubeSize * 4 * MemoryLayout<Float>.size
        var lutData = [Float](repeating: 0, count: cubeSize * cubeSize * cubeSize * 4)
        
        for b in 0..<cubeSize {
            for g in 0..<cubeSize {
                for r in 0..<cubeSize {
                    // Usa solo la componente luminanza (assumiamo immagine grayscale)
                    let luminance = Float(r) / Float(cubeSize - 1)
                    let zone = zoneFromLuminance(UInt8(luminance * 255))
                    let color = colorForZone(zone)
                    
                    let index = (r + g * cubeSize + b * cubeSize * cubeSize) * 4
                    lutData[index + 0] = Float(color.red)
                    lutData[index + 1] = Float(color.green)
                    lutData[index + 2] = Float(color.blue)
                    lutData[index + 3] = 1.0
                }
            }
        }
        
        return Data(bytes: &lutData, count: dataSize)
    }
    
    private func colorForZone(_ zone: Zone) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        // Colori per visualizzazione heatmap
        switch zone {
        case .zone0: return (0.0, 0.0, 0.0)       // Nero
        case .zone1: return (0.1, 0.0, 0.2)       // Viola scuro
        case .zone2: return (0.2, 0.0, 0.4)       // Viola
        case .zone3: return (0.0, 0.0, 0.6)       // Blu scuro
        case .zone4: return (0.0, 0.3, 0.8)       // Blu
        case .zone5: return (0.0, 0.6, 0.6)       // Ciano
        case .zone6: return (0.0, 0.7, 0.3)       // Verde acqua
        case .zone7: return (0.7, 0.7, 0.0)       // Giallo
        case .zone8: return (0.9, 0.5, 0.0)       // Arancio
        case .zone9: return (1.0, 0.2, 0.0)       // Rosso-arancio
        case .zone10: return (1.0, 1.0, 1.0)      // Bianco
        }
    }
    
    // MARK: - Cache Management
    
    private func getCachedAnalysis(for key: String) -> ZoneDistribution? {
        cacheQueue.sync {
            analysisCache[key]
        }
    }
    
    private func setCachedAnalysis(_ distribution: ZoneDistribution, for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.analysisCache[key] = distribution
            
            // Limita dimensione cache
            if self.analysisCache.count > 50 {
                self.analysisCache.removeFirst()
            }
        }
    }
    
    public func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.analysisCache.removeAll()
        }
    }
}

// MARK: - Errors

public enum ZoneAnalysisError: Error, LocalizedError {
    case invalidImage
    case conversionFailed
    case invalidRegion
    case dataAccessFailed
    case histogramCalculationFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage: return "Immagine non valida"
        case .conversionFailed: return "Conversione in scala di grigi fallita"
        case .invalidRegion: return "Regione di analisi non valida"
        case .dataAccessFailed: return "Accesso ai dati pixel fallito"
        case .histogramCalculationFailed: return "Calcolo istogramma fallito"
        }
    }
}

// MARK: - Zone Distribution Extensions

extension ZoneDistribution {
    /// Verifica se l'immagine ha un buon bilanciamento tonale
    public var hasGoodBalance: Bool {
        let shadowRatio = shadowPercentage / 100
        let midRatio = midtonePercentage / 100
        let highlightRatio = highlightPercentage / 100
        
        // Bilanciamento ideale: ombre ~25%, medi ~50%, luci ~25%
        return shadowRatio >= 0.15 && shadowRatio <= 0.35 &&
               midRatio >= 0.40 && midRatio <= 0.60 &&
               highlightRatio >= 0.15 && highlightRatio <= 0.35
    }
    
    /// Indica se l'immagine è sottoesposta
    public var isUnderexposed: Bool {
        shadowPercentage > 60 && highlightPercentage < 10
    }
    
    /// Indica se l'immagine è sovraesposta
    public var isOverexposed: Bool {
        highlightPercentage > 60 && shadowPercentage < 10
    }
    
    /// Calcola l'indice di contrasto
    public var contrastIndex: Double {
        let shadowSum = [.zone0, .zone1, .zone2].reduce(0) { $0 + (percentages[$1] ?? 0) }
        let highlightSum = [.zone8, .zone9, .zone10].reduce(0) { $0 + (percentages[$1] ?? 0) }
        return abs(shadowSum - highlightSum)
    }
}
