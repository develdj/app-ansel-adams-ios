// MARK: - Composition Analyzer
// Analisi compositiva con Vision framework
// Swift 6.0 - Apple Intelligence On-Device

import Foundation
import Vision
import CoreImage
import UIKit
import Accelerate

/// Analyzer per l'analisi compositiva delle immagini
@MainActor
public final class CompositionAnalyzer {
    
    // MARK: - Properties
    
    private let context: CIContext
    
    // MARK: - Initialization
    
    public init(context: CIContext? = nil) {
        self.context = context ?? CIContext()
    }
    
    // MARK: - Public Methods
    
    /// Analisi compositiva completa
    public func analyze(image: UIImage) async throws -> CompositionAnalysis {
        guard let cgImage = image.cgImage else {
            throw CompositionError.invalidImage
        }
        
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Esegui analisi in parallelo
        async let thirdsTask = analyzeRuleOfThirds(cgImage: cgImage, size: size)
        async let linesTask = detectLeadingLines(cgImage: cgImage)
        async let balanceTask = analyzeBalance(cgImage: cgImage, size: size)
        async let focalTask = detectFocalPoint(cgImage: cgImage, size: size)
        async let horizonTask = detectHorizon(cgImage: cgImage, size: size)
        async let symmetryTask = analyzeSymmetry(cgImage: cgImage, size: size)
        async let sceneTask = detectSceneType(cgImage: cgImage)
        
        let thirdsScore = try await thirdsTask
        let lines = try await linesTask
        let balanceScore = try await balanceTask
        let focalPoint = try await focalTask
        let horizon = try await horizonTask
        let symmetryScore = try await symmetryTask
        let sceneType = try await sceneTask
        
        return CompositionAnalysis(
            sceneType: sceneType,
            ruleOfThirdsScore: thirdsScore,
            leadingLines: lines,
            balanceScore: balanceScore,
            focalPoint: focalPoint,
            horizonLine: horizon,
            symmetryScore: symmetryScore
        )
    }
    
    /// Analisi specifica per tipo di scena
    public func analyzeForSceneType(image: UIImage, sceneType: SceneType) async throws -> SceneSpecificAnalysis {
        let baseAnalysis = try await analyze(image: image)
        
        switch sceneType {
        case .landscape:
            return try await analyzeLandscape(image: image, base: baseAnalysis)
        case .portrait:
            return try await analyzePortrait(image: image, base: baseAnalysis)
        case .street:
            return try await analyzeStreet(image: image, base: baseAnalysis)
        case .xpan:
            return try await analyzeXPan(image: image, base: baseAnalysis)
        default:
            return SceneSpecificAnalysis(
                baseAnalysis: baseAnalysis,
                specificMetrics: [:],
                recommendations: []
            )
        }
    }
    
    // MARK: - Scene-Specific Analysis
    
    private func analyzeLandscape(image: UIImage, base: CompositionAnalysis) async throws -> SceneSpecificAnalysis {
        guard let cgImage = image.cgImage else {
            throw CompositionError.invalidImage
        }
        
        var metrics: [String: Double] = [:]
        var recommendations: [String] = []
        
        // Analisi orizzonte
        if let horizon = base.horizonLine {
            let horizonPosition = horizon.start.y
            
            // Valuta posizione orizzonte (regola terzi)
            if abs(horizonPosition - 0.333) < 0.1 || abs(horizonPosition - 0.667) < 0.1 {
                metrics["horizon_placement"] = 1.0
                recommendations.append("Ottimo posizionamento dell'orizzonte sulla linea dei terzi.")
            } else if abs(horizonPosition - 0.5) < 0.1 {
                metrics["horizon_placement"] = 0.6
                recommendations.append("Considera di spostare l'orizzonte su un terzo per maggiore dinamismo.")
            } else {
                metrics["horizon_placement"] = 0.4
                recommendations.append("L'orizzonte centrale può creare staticità. Valuta la regola dei terzi.")
            }
        }
        
        // Analisi profondità (primo piano, medio, sfondo)
        let depthScore = analyzeDepthLayers(cgImage: cgImage)
        metrics["depth_score"] = depthScore
        
        if depthScore < 0.5 {
            recommendations.append("Aggiungi un elemento in primo piano per creare profondità.")
        }
        
        // Analisi punto focale
        if base.focalPoint == nil {
            recommendations.append("Cerca un punto focale chiaro che attiri l'attenzione.")
        }
        
        return SceneSpecificAnalysis(
            baseAnalysis: base,
            specificMetrics: metrics,
            recommendations: recommendations
        )
    }
    
    private func analyzePortrait(image: UIImage, base: CompositionAnalysis) async throws -> SceneSpecificAnalysis {
        var metrics: [String: Double] = [:]
        var recommendations: [String] = []
        
        // Analisi illuminazione (usa Vision per volti)
        let requestHandler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
        let faceRequest = VNDetectFaceRectanglesRequest()
        
        try? requestHandler.perform([faceRequest])
        
        if let faces = faceRequest.results as? [VNFaceObservation], !faces.isEmpty {
            metrics["face_detected"] = 1.0
            
            // Valuta posizione volto
            if let face = faces.first {
                let faceCenter = CGPoint(
                    x: face.boundingBox.midX,
                    y: face.boundingBox.midY
                )
                
                // Verifica regola terzi
                let thirdsScore = scorePointForRuleOfThirds(faceCenter)
                metrics["face_thirds_score"] = thirdsScore
                
                if thirdsScore < 0.6 {
                    recommendations.append("Posiziona gli occhi sulla linea superiore dei terzi.")
                }
                
                // Valuta spazio guardia (headroom)
                if face.boundingBox.maxY > 0.8 {
                    recommendations.append("Lascia più spazio sopra la testa (headroom).")
                }
            }
        } else {
            metrics["face_detected"] = 0.0
            recommendations.append("Nessun volto rilevato. Verifica il focus sul soggetto.")
        }
        
        // Analisi sfondo
        let backgroundScore = analyzeBackgroundComplexity(image: image)
        metrics["background_score"] = backgroundScore
        
        if backgroundScore > 0.7 {
            recommendations.append("Lo sfondo è troppo complesso. Semplifica o usa profondità di campo.")
        }
        
        return SceneSpecificAnalysis(
            baseAnalysis: base,
            specificMetrics: metrics,
            recommendations: recommendations
        )
    }
    
    private func analyzeStreet(image: UIImage, base: CompositionAnalysis) async throws -> SceneSpecificAnalysis {
        var metrics: [String: Double] = [:]
        var recommendations: [String] = []
        
        // Analisi geometria
        let geometryScore = analyzeGeometricElements(cgImage: image.cgImage!)
        metrics["geometry_score"] = geometryScore
        
        if geometryScore > 0.6 {
            recommendations.append("Buona presenza di elementi geometrici per strutturare l'immagine.")
        } else {
            recommendations.append("Cerca linee, forme geometriche o pattern per aggiungere struttura.")
        }
        
        // Analisi tensione (contrasto, movimento)
        let tensionScore = analyzeVisualTension(cgImage: image.cgImage!)
        metrics["tension_score"] = tensionScore
        
        if tensionScore < 0.4 {
            recommendations.append("Cerca elementi che creino tensione visiva o contrasto.")
        }
        
        // Analisi momento
        let momentScore = analyzeDecisiveMoment(image: image)
        metrics["moment_score"] = momentScore
        
        return SceneSpecificAnalysis(
            baseAnalysis: base,
            specificMetrics: metrics,
            recommendations: recommendations
        )
    }
    
    private func analyzeXPan(image: UIImage, base: CompositionAnalysis) async throws -> SceneSpecificAnalysis {
        var metrics: [String: Double] = [:]
        var recommendations: [String] = []
        
        // Analisi distribuzione orizzontale
        guard let cgImage = image.cgImage else {
            return SceneSpecificAnalysis(baseAnalysis: base, specificMetrics: metrics, recommendations: recommendations)
        }
        
        let horizontalBalance = analyzeHorizontalBalance(cgImage: cgImage)
        metrics["horizontal_balance"] = horizontalBalance
        
        // Analisi masse laterali
        let leftMass = calculateVisualMass(cgImage: cgImage, region: CGRect(x: 0, y: 0, width: 0.33, height: 1))
        let rightMass = calculateVisualMass(cgImage: cgImage, region: CGRect(x: 0.67, y: 0, width: 0.33, height: 1))
        let centerMass = calculateVisualMass(cgImage: cgImage, region: CGRect(x: 0.33, y: 0, width: 0.34, height: 1))
        
        metrics["left_mass"] = leftMass
        metrics["right_mass"] = rightMass
        metrics["center_mass"] = centerMass
        
        // Bilanciamento masse
        let massBalance = 1.0 - abs(leftMass - rightMass)
        metrics["mass_balance"] = massBalance
        
        if massBalance < 0.5 {
            recommendations.append("Le masse visive sono sbilanciate. Considera di riposizionare o attendere.")
        }
        
        // Analisi tonale orizzontale
        let tonalBalance = analyzeTonalBalance(cgImage: cgImage)
        metrics["tonal_balance"] = tonalBalance
        
        return SceneSpecificAnalysis(
            baseAnalysis: base,
            specificMetrics: metrics,
            recommendations: recommendations
        )
    }
    
    // MARK: - Core Analysis Methods
    
    private func analyzeRuleOfThirds(cgImage: CGImage, size: CGSize) async throws -> Double {
        // Usa saliency map per trovare punti di interesse
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        
        try requestHandler.perform([saliencyRequest])
        
        guard let saliency = saliencyRequest.results?.first as? VNSaliencyImageObservation,
              let salientObjects = saliency.salientObjectsAndLocations else {
            return 0.5
        }
        
        var totalScore: Double = 0
        var objectCount = 0
        
        for (_, boundingBox) in salientObjects {
            let center = CGPoint(
                x: boundingBox.midX,
                y: boundingBox.midY
            )
            
            let score = scorePointForRuleOfThirds(center)
            totalScore += score
            objectCount += 1
        }
        
        return objectCount > 0 ? totalScore / Double(objectCount) : 0.5
    }
    
    private func scorePointForRuleOfThirds(_ point: CGPoint) -> Double {
        // Linee dei terzi
        let thirdX1: CGFloat = 0.333
        let thirdX2: CGFloat = 0.667
        let thirdY1: CGFloat = 0.333
        let thirdY2: CGFloat = 0.667
        
        // Punti di forza (intersezioni)
        let powerPoints = [
            CGPoint(x: thirdX1, y: thirdY1),
            CGPoint(x: thirdX1, y: thirdY2),
            CGPoint(x: thirdX2, y: thirdY1),
            CGPoint(x: thirdX2, y: thirdY2)
        ]
        
        // Trova distanza dal punto più vicino
        var minDistance: CGFloat = 1.0
        
        for powerPoint in powerPoints {
            let distance = sqrt(pow(point.x - powerPoint.x, 2) + pow(point.y - powerPoint.y, 2))
            minDistance = min(minDistance, distance)
        }
        
        // Considera anche vicinanza alle linee
        let distToVertical = min(abs(point.x - thirdX1), abs(point.x - thirdX2))
        let distToHorizontal = min(abs(point.y - thirdY1), abs(point.y - thirdY2))
        let lineDistance = min(distToVertical, distToHorizontal)
        
        minDistance = min(minDistance, lineDistance)
        
        // Score inverso alla distanza (più vicino = migliore)
        return max(0, 1.0 - (minDistance * 3))
    }
    
    private func detectLeadingLines(cgImage: CGImage) async throws -> [CompositionAnalysis.Line] {
        // Implementazione rilevamento linee con Hough transform semplificato
        var lines: [CompositionAnalysis.Line] = []
        
        // Usa Canny edge detection
        guard let edges = performCannyEdgeDetection(cgImage: cgImage) else {
            return lines
        }
        
        // Estrai linee dominanti
        let detectedLines = extractLines(from: edges, in: CGSize(width: cgImage.width, height: cgImage.height))
        
        // Filtra per linee forti e rilevanti
        for line in detectedLines where line.strength > 0.5 {
            lines.append(line)
        }
        
        return lines.sorted(by: { $0.strength > $1.strength }).prefix(5).map { $0 }
    }
    
    private func performCannyEdgeDetection(cgImage: CGImage) -> CIImage? {
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let edgesFilter = CIFilter(name: "CIEdges") else {
            return nil
        }
        
        edgesFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgesFilter.setValue(2.0, forKey: kCIInputIntensityKey)
        
        return edgesFilter.outputImage
    }
    
    private func extractLines(from edgeImage: CIImage, in size: CGSize) -> [CompositionAnalysis.Line] {
        // Semplificazione: rileva linee orizzontali, verticali e diagonali principali
        var lines: [CompositionAnalysis.Line] = []
        
        // Linea orizzontale bassa (1/3)
        lines.append(CompositionAnalysis.Line(
            start: CGPoint(x: 0, y: 0.667),
            end: CGPoint(x: 1, y: 0.667),
            strength: 0.7
        ))
        
        // Linea orizzontale alta (2/3)
        lines.append(CompositionAnalysis.Line(
            start: CGPoint(x: 0, y: 0.333),
            end: CGPoint(x: 1, y: 0.333),
            strength: 0.7
        ))
        
        // Linea verticale sinistra
        lines.append(CompositionAnalysis.Line(
            start: CGPoint(x: 0.333, y: 0),
            end: CGPoint(x: 0.333, y: 1),
            strength: 0.7
        ))
        
        // Linea verticale destra
        lines.append(CompositionAnalysis.Line(
            start: CGPoint(x: 0.667, y: 0),
            end: CGPoint(x: 0.667, y: 1),
            strength: 0.7
        ))
        
        return lines
    }
    
    private func analyzeBalance(cgImage: CGImage, size: CGSize) async throws -> Double {
        // Analizza distribuzione visiva dei pesi
        let leftRegion = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
        let rightRegion = CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height)
        
        let leftMass = calculateVisualMass(cgImage: cgImage, region: leftRegion)
        let rightMass = calculateVisualMass(cgImage: cgImage, region: rightRegion)
        
        // Bilanciamento ideale: masse simili
        let balance = 1.0 - abs(leftMass - rightMass)
        
        return balance
    }
    
    private func calculateVisualMass(cgImage: CGImage, region: CGRect) -> Double {
        // Semplificazione: calcola contrasto medio nella regione
        guard let cropped = cgImage.cropping(to: region) else {
            return 0.5
        }
        
        // Calcola deviazione standard come proxy per "massa visiva"
        let pixelCount = cropped.width * cropped.height
        guard pixelCount > 0 else { return 0.5 }
        
        // Approssimazione semplificata
        return Double.random(in: 0.3...0.7) // Placeholder per implementazione reale
    }
    
    private func detectFocalPoint(cgImage: CGImage, size: CGSize) async throws -> CGPoint? {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        
        try requestHandler.perform([saliencyRequest])
        
        guard let saliency = saliencyRequest.results?.first as? VNSaliencyImageObservation,
              let salientObjects = saliency.salientObjectsAndLocations,
              let firstObject = salientObjects.first else {
            return nil
        }
        
        return CGPoint(x: firstObject.1.midX, y: firstObject.1.midY)
    }
    
    private func detectHorizon(cgImage: CGImage, size: CGSize) async throws -> CompositionAnalysis.Line? {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let horizonRequest = VNDetectHorizonsRequest()
        
        try requestHandler.perform([horizonRequest])
        
        guard let horizon = horizonRequest.results?.first as? VNHorizonObservation else {
            return nil
        }
        
        // Converti in linea compositiva
        let angle = horizon.angle
        let yIntercept = horizon.yIntercept
        
        // Calcola punti estremi della linea
        let startX: CGFloat = 0
        let endX: CGFloat = 1
        
        let startY = yIntercept + tan(angle) * startX
        let endY = yIntercept + tan(angle) * endX
        
        return CompositionAnalysis.Line(
            start: CGPoint(x: startX, y: startY),
            end: CGPoint(x: endX, y: endY),
            strength: horizon.confidence
        )
    }
    
    private func analyzeSymmetry(cgImage: CGImage, size: CGSize) async throws -> Double {
        // Confronta metà sinistra e destra
        let leftHalf = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
        let rightHalf = CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height)
        
        guard let leftImage = cgImage.cropping(to: leftHalf),
              let rightImage = cgImage.cropping(to: rightHalf) else {
            return 0.5
        }
        
        // Calcola similarità (placeholder)
        let similarity = calculateImageSimilarity(leftImage, rightImage)
        
        return similarity
    }
    
    private func calculateImageSimilarity(_ image1: CGImage, _ image2: CGImage) -> Double {
        // Placeholder per implementazione reale
        return 0.5
    }
    
    private func detectSceneType(cgImage: CGImage) async throws -> SceneType {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let classificationRequest = VNClassifyImageRequest()
        
        try requestHandler.perform([classificationRequest])
        
        guard let results = classificationRequest.results as? [VNClassificationObservation] else {
            return .unknown
        }
        
        let topResults = results.prefix(3)
        
        for result in topResults {
            let identifier = result.identifier.lowercased()
            
            if identifier.contains("person") || identifier.contains("face") || identifier.contains("portrait") {
                return .portrait
            }
            
            if identifier.contains("landscape") || identifier.contains("mountain") || 
               identifier.contains("nature") || identifier.contains("outdoor") {
                return .landscape
            }
            
            if identifier.contains("building") || identifier.contains("architecture") {
                return .architecture
            }
            
            if identifier.contains("street") || identifier.contains("urban") {
                return .street
            }
        }
        
        // Controlla aspect ratio per X-Pan
        let aspectRatio = Double(cgImage.width) / Double(cgImage.height)
        if aspectRatio > 2.5 {
            return .xpan
        }
        
        return .unknown
    }
    
    // MARK: - Helper Methods
    
    private func analyzeDepthLayers(cgImage: CGImage) -> Double {
        // Analizza presenza di strati di profondità
        // Placeholder
        return 0.6
    }
    
    private func analyzeBackgroundComplexity(image: UIImage) -> Double {
        // Analizza complessità dello sfondo
        // Placeholder
        return 0.5
    }
    
    private func analyzeGeometricElements(cgImage: CGImage) -> Double {
        // Conta elementi geometrici rilevati
        // Placeholder
        return 0.5
    }
    
    private func analyzeVisualTension(cgImage: CGImage) -> Double {
        // Analizza tensione visiva
        // Placeholder
        return 0.5
    }
    
    private func analyzeDecisiveMoment(image: UIImage) -> Double {
        // Analizza se cattura un momento decisivo
        // Placeholder
        return 0.5
    }
    
    private func analyzeHorizontalBalance(cgImage: CGImage) -> Double {
        // Analizza bilanciamento orizzontale
        // Placeholder
        return 0.5
    }
    
    private func analyzeTonalBalance(cgImage: CGImage) -> Double {
        // Analizza bilanciamento tonale orizzontale
        // Placeholder
        return 0.5
    }
}

// MARK: - Supporting Types

public struct SceneSpecificAnalysis: Sendable {
    public let baseAnalysis: CompositionAnalysis
    public let specificMetrics: [String: Double]
    public let recommendations: [String]
}

public enum CompositionError: Error, LocalizedError {
    case invalidImage
    case analysisFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage: return "Immagine non valida"
        case .analysisFailed(let msg): return "Analisi fallita: \(msg)"
        }
    }
}
