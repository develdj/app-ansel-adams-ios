// MARK: - AI Critique Engine
// Motore principale di analisi AI con Vision framework
// Swift 6.0 - Apple Intelligence On-Device

import Foundation
import Vision
import CoreImage
import UIKit
import NaturalLanguage

/// Motore principale per l'analisi critica delle immagini
@MainActor
public final class AICritiqueEngine {
    
    // MARK: - Properties
    
    private let zoneAnalyzer: ZoneAnalyzer
    private let compositionAnalyzer: CompositionAnalyzer
    private var requestHandler: VNImageRequestHandler?
    
    // Configurazione
    private let confidenceThreshold: Float = 0.7
    
    // MARK: - Initialization
    
    public init() {
        self.zoneAnalyzer = ZoneAnalyzer()
        self.compositionAnalyzer = CompositionAnalyzer()
    }
    
    // MARK: - Public Methods
    
    /// Analizza completa di un'immagine
    public func analyzeImage(_ image: UIImage) async throws -> ImageAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw CritiqueError.invalidImage
        }
        
        // Esegui analisi in parallelo dove possibile
        async let zoneTask = zoneAnalyzer.analyze(image: image)
        async let compositionTask = compositionAnalyzer.analyze(image: image)
        async let visionTask = performVisionAnalysis(cgImage: cgImage)
        
        // Attendi risultati
        let zoneDistribution = try await zoneTask
        let compositionAnalysis = try await compositionTask
        let visionResults = try await visionTask
        
        // Calcola analisi derivate
        let dynamicRange = calculateDynamicRange(from: zoneDistribution)
        let contrastAnalysis = calculateContrastAnalysis(from: zoneDistribution, image: image)
        
        // Determina tipo scena
        let sceneType = determineSceneType(from: visionResults, composition: compositionAnalysis)
        
        // Calcola punteggi
        let technicalScore = calculateTechnicalScore(
            zoneDistribution: zoneDistribution,
            dynamicRange: dynamicRange,
            contrast: contrastAnalysis
        )
        
        let artisticScore = calculateArtisticScore(
            composition: compositionAnalysis,
            sceneType: sceneType
        )
        
        // Genera critica Adams
        let adamsCritique = generateAdamsCritique(
            zoneDistribution: zoneDistribution,
            dynamicRange: dynamicRange,
            contrast: contrastAnalysis,
            composition: compositionAnalysis,
            sceneType: sceneType,
            technicalScore: technicalScore
        )
        
        // Genera suggerimenti
        let suggestions = generateSuggestions(
            zoneDistribution: zoneDistribution,
            dynamicRange: dynamicRange,
            contrast: contrastAnalysis,
            composition: compositionAnalysis,
            sceneType: sceneType
        )
        
        return ImageAnalysisResult(
            zoneDistribution: zoneDistribution,
            dynamicRange: dynamicRange,
            contrastAnalysis: contrastAnalysis,
            compositionAnalysis: compositionAnalysis,
            sceneType: sceneType,
            technicalScore: technicalScore,
            artisticScore: artisticScore,
            adamsCritique: adamsCritique,
            suggestions: suggestions
        )
    }
    
    /// Analisi rapida per preview
    public func quickAnalyze(_ image: UIImage) async throws -> QuickAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw CritiqueError.invalidImage
        }
        
        let zoneDistribution = try await zoneAnalyzer.analyze(image: image)
        let compositionAnalysis = try await compositionAnalyzer.analyze(image: image)
        
        let dynamicRange = calculateDynamicRange(from: zoneDistribution)
        
        return QuickAnalysisResult(
            zoneDistribution: zoneDistribution,
            dynamicRange: dynamicRange,
            sceneType: compositionAnalysis.sceneType,
            overallScore: calculateOverallScore(zoneDistribution, dynamicRange, compositionAnalysis)
        )
    }
    
    /// Analisi batch per multiple immagini
    public func analyzeBatch(images: [UIImage]) async throws -> [ImageAnalysisResult] {
        try await withThrowingTaskGroup(of: ImageAnalysisResult.self) { group in
            for image in images {
                group.addTask {
                    try await self.analyzeImage(image)
                }
            }
            
            var results: [ImageAnalysisResult] = []
            for try await result in group {
                results.append(result)
            }
            
            return results.sorted(by: { $0.technicalScore > $1.technicalScore })
        }
    }
    
    // MARK: - Vision Analysis
    
    private func performVisionAnalysis(cgImage: CGImage) async throws -> VisionResults {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        self.requestHandler = requestHandler
        
        // Configura richieste Vision
        let sceneRequest = VNClassifyImageRequest()
        sceneRequest.revision = VNClassifyImageRequestRevision1
        
        let objectRequest = VNDetectRectanglesRequest()
        objectRequest.minimumAspectRatio = 0.3
        objectRequest.maximumAspectRatio = 1.0
        objectRequest.minimumSize = 0.1
        
        let horizonRequest = VNDetectHorizonsRequest()
        
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        
        let faceRequest = VNDetectFaceRectanglesRequest()
        faceRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        // Esegui richieste
        try requestHandler.perform([
            sceneRequest,
            objectRequest,
            horizonRequest,
            saliencyRequest,
            faceRequest
        ])
        
        // Estrai risultati
        let sceneObservations = sceneRequest.results as? [VNClassificationObservation] ?? []
        let rectangles = objectRequest.results as? [VNRectangleObservation] ?? []
        let horizons = horizonRequest.results as? [VNHorizonObservation] ?? []
        let saliency = saliencyRequest.results?.first as? VNSaliencyImageObservation
        let faces = faceRequest.results as? [VNFaceObservation] ?? []
        
        return VisionResults(
            sceneClassifications: sceneObservations,
            detectedRectangles: rectangles,
            horizonObservations: horizons,
            saliencyObservation: saliency,
            faceObservations: faces
        )
    }
    
    // MARK: - Analysis Calculations
    
    private func calculateDynamicRange(from distribution: ZoneDistribution) -> DynamicRangeAnalysis {
        // Trova min e max zone con pixel significativi (> 0.1%)
        var minZone: Zone = .zone0
        var maxZone: Zone = .zone10
        
        for zone in Zone.allCases {
            if distribution.percentages[zone, default: 0] > 0.1 {
                minZone = zone
                break
            }
        }
        
        for zone in Zone.allCases.reversed() {
            if distribution.percentages[zone, default: 0] > 0.1 {
                maxZone = zone
                break
            }
        }
        
        let minLuminance = minZone.luminanceValue * 2.55
        let maxLuminance = maxZone.luminanceValue * 2.55
        
        return DynamicRangeAnalysis(minLuminance: minLuminance, maxLuminance: maxLuminance)
    }
    
    private func calculateContrastAnalysis(from distribution: ZoneDistribution, image: UIImage) -> ContrastAnalysis {
        // Calcola contrasto globale dalla deviazione standard
        let globalContrast = calculateGlobalContrast(from: distribution)
        
        // Stima contrasto locale
        let localContrast = globalContrast * 0.7 // Approssimazione
        
        // Calcola dettaglio ombre e luci
        let shadowDetail = min(1.0, (distribution.percentages[.zone2, default: 0] + 
                                     distribution.percentages[.zone3, default: 0]) / 20)
        
        let highlightDetail = min(1.0, (distribution.percentages[.zone8, default: 0] + 
                                        distribution.percentages[.zone9, default: 0]) / 20)
        
        return ContrastAnalysis(
            globalContrast: globalContrast,
            localContrast: localContrast,
            shadowDetail: shadowDetail,
            highlightDetail: highlightDetail
        )
    }
    
    private func calculateGlobalContrast(from distribution: ZoneDistribution) -> Double {
        // Calcola media ponderata delle zone
        var mean: Double = 0
        var variance: Double = 0
        
        for zone in Zone.allCases {
            let percentage = distribution.percentages[zone, default: 0] / 100
            mean += Double(zone.rawValue) * percentage
        }
        
        for zone in Zone.allCases {
            let percentage = distribution.percentages[zone, default: 0] / 100
            variance += pow(Double(zone.rawValue) - mean, 2) * percentage
        }
        
        return sqrt(variance) * 25 // Scala a valore 0-100
    }
    
    private func determineSceneType(from vision: VisionResults, composition: CompositionAnalysis) -> SceneType {
        // Priorità basata su rilevamenti
        if !vision.faceObservations.isEmpty {
            return .portrait
        }
        
        // Analizza classificazioni scena
        let topClassifications = vision.sceneClassifications.prefix(3)
        
        for classification in topClassifications {
            let identifier = classification.identifier.lowercased()
            
            if identifier.contains("landscape") || identifier.contains("mountain") || 
               identifier.contains("nature") || identifier.contains("outdoor") {
                return .landscape
            }
            
            if identifier.contains("street") || identifier.contains("urban") ||
               identifier.contains("city") {
                return .street
            }
            
            if identifier.contains("architecture") || identifier.contains("building") {
                return .architecture
            }
        }
        
        // Controlla aspect ratio per X-Pan
        if composition.aspectRatio > 2.5 {
            return .xpan
        }
        
        return composition.sceneType
    }
    
    private func calculateTechnicalScore(zoneDistribution: ZoneDistribution, 
                                         dynamicRange: DynamicRangeAnalysis,
                                         contrast: ContrastAnalysis) -> Double {
        var score: Double = 50 // Base
        
        // Punteggio gamma dinamica
        switch dynamicRange.rating {
        case .excellent: score += 20
        case .good: score += 15
        case .limited: score += 8
        case .compressed: score += 3
        }
        
        // Punteggio contrasto
        switch contrast.rating {
        case .high: score += 15
        case .normal: score += 12
        case .low: score += 6
        case .flat: score += 2
        }
        
        // Punteggio bilanciamento zone
        if zoneDistribution.hasGoodBalance {
            score += 15
        } else if zoneDistribution.isUnderexposed || zoneDistribution.isOverexposed {
            score -= 10
        }
        
        // Punteggio dettaglio
        score += contrast.shadowDetail * 10
        score += contrast.highlightDetail * 10
        
        return min(100, max(0, score))
    }
    
    private func calculateArtisticScore(composition: CompositionAnalysis, sceneType: SceneType) -> Double {
        var score: Double = 50 // Base
        
        // Punteggio regola terzi
        score += composition.ruleOfThirdsScore * 20
        
        // Punteggio linee guida
        score += Double(composition.leadingLines.count) * 3
        
        // Punteggio bilanciamento
        score += composition.balanceScore * 15
        
        // Punteggio punto focale
        if composition.focalPoint != nil {
            score += 10
        }
        
        return min(100, max(0, score))
    }
    
    private func calculateOverallScore(_ zoneDistribution: ZoneDistribution,
                                       _ dynamicRange: DynamicRangeAnalysis,
                                       _ composition: CompositionAnalysis) -> Double {
        let technical = calculateTechnicalScore(
            zoneDistribution: zoneDistribution,
            dynamicRange: dynamicRange,
            contrast: ContrastAnalysis(globalContrast: 40, localContrast: 30, shadowDetail: 0.5, highlightDetail: 0.5)
        )
        let artistic = calculateArtisticScore(composition: composition, sceneType: composition.sceneType)
        
        return (technical * 0.6) + (artistic * 0.4)
    }
    
    // MARK: - Adams Critique Generation
    
    private func generateAdamsCritique(zoneDistribution: ZoneDistribution,
                                       dynamicRange: DynamicRangeAnalysis,
                                       contrast: ContrastAnalysis,
                                       composition: CompositionAnalysis,
                                       sceneType: SceneType,
                                       technicalScore: Double) -> AdamsCritique {
        
        let overallComment = generateOverallComment(zoneDistribution, dynamicRange, sceneType, technicalScore)
        let technicalComment = generateTechnicalComment(zoneDistribution, dynamicRange, contrast)
        let artisticComment = generateArtisticComment(composition, sceneType)
        let zonePlacement = generateZonePlacementAdvice(zoneDistribution, sceneType)
        let development = generateDevelopmentAdvice(zoneDistribution, contrast)
        let printing = generatePrintingAdvice(zoneDistribution, contrast)
        let filter = generateFilterSuggestion(sceneType, zoneDistribution)
        
        return AdamsCritique(
            overallComment: overallComment,
            technicalComment: technicalComment,
            artisticComment: artisticComment,
            zonePlacementAdvice: zonePlacement,
            developmentAdvice: development,
            printingAdvice: printing,
            filterSuggestion: filter
        )
    }
    
    private func generateOverallComment(_ zones: ZoneDistribution, 
                                        _ range: DynamicRangeAnalysis,
                                        _ scene: SceneType,
                                        _ score: Double) -> String {
        var comment = scene.adamsQuote + "\n\n"
        
        if score >= 80 {
            comment += "Questa immagine dimostra una padronanza eccellente del Zone System. "
        } else if score >= 60 {
            comment += "C'è buon potenziale in questa immagine. "
        } else {
            comment += "Questa immagine presenta sfide tecniche significative. "
        }
        
        if zones.hasPureBlack && zones.hasPureWhite {
            comment += "L'uso del nero puro e bianco puro crea una gamma tonale completa."
        } else if !zones.hasPureBlack {
            comment += "Manca il nero puro, che darebbe maggiore profondità all'immagine."
        } else if !zones.hasPureWhite {
            comment += "Manca il bianco puro, che darebbe luminosità all'immagine."
        }
        
        return comment
    }
    
    private func generateTechnicalComment(_ zones: ZoneDistribution, 
                                          _ range: DynamicRangeAnalysis,
                                          _ contrast: ContrastAnalysis) -> String {
        var comment = "Gamma dinamica: \(range.dynamicRangeStops.formatted(.number.precision(.fractionLength(1)))) stops (\(range.rating.rawValue)). "
        
        comment += "Contrasto \(contrast.rating.rawValue.lowercased()). "
        
        if contrast.shadowDetail < 0.3 {
            comment += "Attenzione: dettaglio nelle ombre limitato. "
        }
        
        if contrast.highlightDetail < 0.3 {
            comment += "Attenzione: dettaglio nelle luci limitato. "
        }
        
        return comment
    }
    
    private func generateArtisticComment(_ composition: CompositionAnalysis, _ scene: SceneType) -> String {
        var comment = ""
        
        if composition.ruleOfThirdsScore > 0.7 {
            comment += "Ottimo uso della regola dei terzi. "
        }
        
        if !composition.leadingLines.isEmpty {
            comment += "Le linee guida conducono l'occhio efficacemente. "
        }
        
        if composition.balanceScore > 0.7 {
            comment += "Composizione ben bilanciata. "
        }
        
        return comment.isEmpty ? "La composizione ha spazio per miglioramento." : comment
    }
    
    private func generateZonePlacementAdvice(_ zones: ZoneDistribution, _ scene: SceneType) -> String {
        var advice = ""
        
        switch scene {
        case .landscape:
            if zones.shadowPercentage > 40 {
                advice = "In un paesaggio con ombre profonde, posiziona Zone III su una zona scura con dettaglio importante. Considera N-1 per comprimere il contrasto."
            } else {
                advice = "Posiziona Zone III sulle ombre con texture. Le zone luminose del cielo andranno in Zone VII-VIII."
            }
        case .portrait:
            advice = "Per il ritratto, posiziona Zone III sulle ombre della pelle. La parte illuminata del viso cadrà in Zone VI."
        case .street:
            advice = "Nella street photography, Zone III va sulle ombre con informazione. Cerca di mantenere dettaglio in entrambe le estreme."
        default:
            advice = "Posiziona Zone III sull'ombra più scura dove vuoi mantenere dettaglio. Espandi o comprimi in sviluppo secondo necessità."
        }
        
        return advice
    }
    
    private func generateDevelopmentAdvice(_ zones: ZoneDistribution, _ contrast: ContrastAnalysis) -> String {
        if contrast.rating == .high {
            return "Alto contrasto scenico. Sviluppa N-1 o N-2 per comprimere la gamma e mantenere dettaglio in ombre e luci."
        } else if contrast.rating == .flat {
            return "Contrasto basso. Sviluppa N+1 o N+2 per espandere la gamma e dare più punch all'immagine."
        } else {
            return "Contrasto normale. Sviluppo N standard dovrebbe dare buoni risultati."
        }
    }
    
    private func generatePrintingAdvice(_ zones: ZoneDistribution, _ contrast: ContrastAnalysis) -> String {
        var advice = "In stampa: "
        
        if !zones.hasPureBlack {
            advice += "Dodgi le ombre per creare nero puro nelle aree appropriate. "
        }
        
        if !zones.hasPureWhite {
            advice += "Brucia leggermente le luci per ottenere bianco puro nei punti di massima luminosità. "
        }
        
        if contrast.rating == .flat {
            advice += "Usa carta contrastata (grado 3-4) o filtro alto in stampa."
        } else if contrast.rating == .high {
            advice += "Usa carta morbida (grado 1-2) o filtro basso in stampa."
        } else {
            advice += "Carta grado 2 dovrebbe funzionare bene."
        }
        
        return advice
    }
    
    private func generateFilterSuggestion(_ scene: SceneType, _ zones: ZoneDistribution) -> String? {
        switch scene {
        case .landscape:
            if zones.highlightPercentage > 30 {
                return FilterType.orange.rawValue + ": " + FilterType.orange.effect
            } else {
                return FilterType.yellow.rawValue + ": " + FilterType.yellow.effect
            }
        case .portrait:
            return nil // Nessun filtro consigliato per ritratti
        case .street:
            return FilterType.yellow.rawValue + ": " + FilterType.yellow.effect
        default:
            return nil
        }
    }
    
    // MARK: - Suggestions Generation
    
    private func generateSuggestions(zoneDistribution: ZoneDistribution,
                                     dynamicRange: DynamicRangeAnalysis,
                                     contrast: ContrastAnalysis,
                                     composition: CompositionAnalysis,
                                     sceneType: SceneType) -> [TechnicalSuggestion] {
        
        var suggestions: [TechnicalSuggestion] = []
        
        // Suggerimenti esposizione
        if zoneDistribution.isUnderexposed {
            suggestions.append(TechnicalSuggestion(
                category: .exposure,
                priority: .critical,
                title: "Immagine sottoesposta",
                description: "Aumenta l'esposizione di 1-2 stop. Posiziona Zone III più in alto.",
                adamsQuote: "È meglio sovraesporre leggermente che perdere dettaglio nelle ombre."
            ))
        } else if zoneDistribution.isOverexposed {
            suggestions.append(TechnicalSuggestion(
                category: .exposure,
                priority: .critical,
                title: "Immagine sovraesposta",
                description: "Riduci l'esposizione. Proteggi le luci alte posizionando Zone VII più in basso.",
                adamsQuote: "Le luci bruciate sono perse per sempre. Proteggile con saggezza."
            ))
        }
        
        // Suggerimenti sviluppo
        if contrast.rating == .high {
            suggestions.append(TechnicalSuggestion(
                category: .development,
                priority: .important,
                title: "Sviluppo N-1 o N-2",
                description: DevelopmentType.nMinus1.description,
                adamsQuote: "La contrazione in sviluppo è la nostra arma contro il contrasto eccessivo."
            ))
        } else if contrast.rating == .flat {
            suggestions.append(TechnicalSuggestion(
                category: .development,
                priority: .important,
                title: "Sviluppo N+1 o N+2",
                description: DevelopmentType.nPlus1.description,
                adamsQuote: "L'espansione in sviluppo dà vita alle immagini piatte."
            ))
        }
        
        // Suggerimenti filtri
        if let filter = generateFilterSuggestion(sceneType, zoneDistribution) {
            suggestions.append(TechnicalSuggestion(
                category: .filters,
                priority: .suggestion,
                title: "Considera un filtro",
                description: filter,
                adamsQuote: FilterType.yellow.adamsRecommendation
            ))
        }
        
        // Suggerimenti composizione
        if composition.ruleOfThirdsScore < 0.5 {
            suggestions.append(TechnicalSuggestion(
                category: .composition,
                priority: .suggestion,
                title: "Migliora la composizione",
                description: "Posiziona il soggetto sui punti di forza della regola dei terzi.",
                adamsQuote: "La composizione è il fondamento su cui costruiamo la nostra visione."
            ))
        }
        
        return suggestions
    }
}

// MARK: - Supporting Types

struct VisionResults {
    let sceneClassifications: [VNClassificationObservation]
    let detectedRectangles: [VNRectangleObservation]
    let horizonObservations: [VNHorizonObservation]
    let saliencyObservation: VNSaliencyImageObservation?
    let faceObservations: [VNFaceObservation]
}

public struct QuickAnalysisResult: Sendable {
    public let zoneDistribution: ZoneDistribution
    public let dynamicRange: DynamicRangeAnalysis
    public let sceneType: SceneType
    public let overallScore: Double
}

public enum CritiqueError: Error, LocalizedError {
    case invalidImage
    case visionAnalysisFailed(String)
    case analysisTimeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage: return "Immagine non valida o corrotta"
        case .visionAnalysisFailed(let msg): return "Analisi Vision fallita: \(msg)"
        case .analysisTimeout: return "Timeout nell'analisi"
        }
    }
}

// MARK: - Composition Analysis Extensions

extension CompositionAnalysis {
    var aspectRatio: Double {
        // Placeholder - sarebbe calcolato dall'immagine reale
        return 1.5
    }
}
