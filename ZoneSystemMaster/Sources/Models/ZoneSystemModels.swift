// MARK: - Zone System Master - Core Models
// Swift 6.0 - Apple Intelligence On-Device AI Engine
// Analisi foto in bianco e nero con critica stile Ansel Adams

import Foundation
import CoreImage
import UIKit
import Vision

// MARK: - Zone Definitions

/// Rappresenta le 11 zone tonali del Zone System (0-10)
public enum Zone: Int, CaseIterable, Sendable {
    case zone0 = 0   // Nero puro, nessun dettaglio
    case zone1 = 1   // Nero con leggero tono, nessun dettaglio
    case zone2 = 2   // Nero con dettaglio visibile
    case zone3 = 3   // Nero scuro con buon dettaglio (ombra con texture)
    case zone4 = 4   // Grigio scuro, ombra media
    case zone5 = 5   // Grigio medio 18% (grigio neutro)
    case zone6 = 6   // Grigio chiaro, pelle caucasica in luce diffusa
    case zone7 = 7   // Grigio molto chiaro, pelle in luce diretta
    case zone8 = 8   // Bianco con dettaglio texture
    case zone9 = 9   // Bianco senza dettaglio, leggero tono
    case zone10 = 10 // Bianco puro, nessun dettaglio
    
    public var description: String {
        switch self {
        case .zone0: return "Nero puro - Nessun dettaglio"
        case .zone1: return "Nero con tono - Nessun dettaglio"
        case .zone2: return "Nero con dettaglio"
        case .zone3: return "Ombra scura con texture"
        case .zone4: return "Ombra media"
        case .zone5: return "Grigio medio 18%"
        case .zone6: return "Luce diffusa"
        case .zone7: return "Luce diretta"
        case .zone8: return "Bianco con texture"
        case .zone9: return "Bianco senza dettaglio"
        case .zone10: return "Bianco puro - Nessun dettaglio"
        }
    }
    
    public var luminanceValue: Double {
        // Valori di luminanza percentuale per zona
        switch self {
        case .zone0: return 0.0
        case .zone1: return 0.3
        case .zone2: return 0.8
        case .zone3: return 2.0
        case .zone4: return 5.0
        case .zone5: return 18.0
        case .zone6: return 36.0
        case .zone7: return 59.0
        case .zone8: return 78.0
        case .zone9: return 95.0
        case .zone10: return 100.0
        }
    }
    
    public var rgbValue: UInt8 {
        // Valore RGB approssimativo per visualizzazione
        switch self {
        case .zone0: return 0
        case .zone1: return 25
        case .zone2: return 50
        case .zone3: return 75
        case .zone4: return 100
        case .zone5: return 128
        case .zone6: return 155
        case .zone7: return 180
        case .zone8: return 205
        case .zone9: return 230
        case .zone10: return 255
        }
    }
}

// MARK: - Scene Type

public enum SceneType: String, CaseIterable, Sendable {
    case landscape = "Paesaggio"
    case portrait = "Ritratto"
    case street = "Street Photography"
    case xpan = "X-Pan / Panoramico"
    case architecture = "Architettura"
    macro = "Macro"
    case unknown = "Sconosciuto"
    
    public var adamsQuote: String {
        switch self {
        case .landscape:
            return "Il paesaggio è il mio linguaggio visivo. Cerco sempre la luce che rivela la vera natura della terra."
        case .portrait:
            return "Nel ritratto, la luce deve rivelare l'anima del soggetto, non solo la sua forma."
        case .street:
            return "La strada offre momenti effimeri. La luce li trasforma in eternità."
        case .xpan:
            return "Il formato panoramico richiede una visione orizzontale. Ogni elemento conta nello spazio esteso."
        case .architecture:
            return "L'architettura è geometria fatta pietra. La luce ne rivela la struttura nascosta."
        case .macro:
            return "Nel dettaglio minuto troviamo universi interi. La luce rivela ciò che l'occhio non vede."
        case .unknown:
            return "Ogni immagine ha una voce. Dobbiamo solo imparare ad ascoltarla."
        }
    }
}

// MARK: - Analysis Results

/// Risultato completo dell'analisi di un'immagine
public struct ImageAnalysisResult: Sendable {
    public let imageId: UUID
    public let timestamp: Date
    public let zoneDistribution: ZoneDistribution
    public let dynamicRange: DynamicRangeAnalysis
    public let contrastAnalysis: ContrastAnalysis
    public let compositionAnalysis: CompositionAnalysis
    public let sceneType: SceneType
    public let technicalScore: Double
    public let artisticScore: Double
    public let adamsCritique: AdamsCritique
    public let suggestions: [TechnicalSuggestion]
    
    public init(
        imageId: UUID = UUID(),
        timestamp: Date = Date(),
        zoneDistribution: ZoneDistribution,
        dynamicRange: DynamicRangeAnalysis,
        contrastAnalysis: ContrastAnalysis,
        compositionAnalysis: CompositionAnalysis,
        sceneType: SceneType,
        technicalScore: Double,
        artisticScore: Double,
        adamsCritique: AdamsCritique,
        suggestions: [TechnicalSuggestion]
    ) {
        self.imageId = imageId
        self.timestamp = timestamp
        self.zoneDistribution = zoneDistribution
        self.dynamicRange = dynamicRange
        self.contrastAnalysis = contrastAnalysis
        self.compositionAnalysis = compositionAnalysis
        self.sceneType = sceneType
        self.technicalScore = technicalScore
        self.artisticScore = artisticScore
        self.adamsCritique = adamsCritique
        self.suggestions = suggestions
    }
}

/// Distribuzione delle zone tonali nell'immagine
public struct ZoneDistribution: Sendable {
    /// Percentuale di pixel per ogni zona (0-10)
    public let percentages: [Zone: Double]
    
    /// Zona con la maggior percentuale di pixel
    public let dominantZone: Zone
    
    /// Zone presenti nell'immagine (con percentuale > 1%)
    public let presentZones: [Zone]
    
    /// Zone mancanti (0% o < 0.5%)
    public let missingZones: [Zone]
    
    /// Indica se c'è nero puro (Zone 0)
    public let hasPureBlack: Bool
    
    /// Indica se c'è bianco puro (Zone 10)
    public let hasPureWhite: Bool
    
    /// Mappa termica delle zone (per visualizzazione)
    public let zoneHeatmap: CIImage?
    
    public init(
        percentages: [Zone: Double],
        zoneHeatmap: CIImage? = nil
    ) {
        self.percentages = percentages
        self.zoneHeatmap = zoneHeatmap
        
        // Calcola zona dominante
        self.dominantZone = percentages.max(by: { $0.value < $1.value })?.key ?? .zone5
        
        // Zone presenti (> 1%)
        self.presentZones = Zone.allCases.filter { percentages[$0, default: 0] > 1.0 }
        
        // Zone mancanti (< 0.5%)
        self.missingZones = Zone.allCases.filter { percentages[$0, default: 0] < 0.5 }
        
        self.hasPureBlack = percentages[.zone0, default: 0] > 0.1
        self.hasPureWhite = percentages[.zone10, default: 0] > 0.1
    }
    
    /// Percentuale totale di ombre (Zone 0-3)
    public var shadowPercentage: Double {
        [.zone0, .zone1, .zone2, .zone3].reduce(0) { $0 + (percentages[$1] ?? 0) }
    }
    
    /// Percentuale totale di luci (Zone 7-10)
    public var highlightPercentage: Double {
        [.zone7, .zone8, .zone9, .zone10].reduce(0) { $0 + (percentages[$1] ?? 0) }
    }
    
    /// Percentuale toni medi (Zone 4-6)
    public var midtonePercentage: Double {
        [.zone4, .zone5, .zone6].reduce(0) { $0 + (percentages[$1] ?? 0) }
    }
}

/// Analisi della gamma dinamica
public struct DynamicRangeAnalysis: Sendable {
    /// Gamma dinamica in stops (approssimativa)
    public let dynamicRangeStops: Double
    
    /// Luminosità minima rilevata (0-255)
    public let minLuminance: Double
    
    /// Luminosità massima rilevata (0-255)
    public let maxLuminance: Double
    
    /// Rapporto di contrasto
    public let contrastRatio: Double
    
    /// Valutazione della gamma dinamica
    public let rating: DynamicRangeRating
    
    public enum DynamicRangeRating: String, Sendable {
        case excellent = "Eccellente"
        case good = "Buona"
        case limited = "Limitata"
        case compressed = "Compressa"
        
        public var description: String {
            switch self {
            case .excellent: return "Gamma dinamica eccellente (> 10 stops)"
            case .good: return "Buona gamma dinamica (7-10 stops)"
            case .limited: return "Gamma dinamica limitata (5-7 stops)"
            case .compressed: return "Gamma dinamica compressa (< 5 stops)"
            }
        }
    }
    
    public init(minLuminance: Double, maxLuminance: Double) {
        self.minLuminance = minLuminance
        self.maxLuminance = maxLuminance
        self.contrastRatio = maxLuminance / max(minLuminance, 1)
        
        // Approssimazione stops (log2 del rapporto)
        self.dynamicRangeStops = log2(contrastRatio)
        
        // Valutazione
        switch dynamicRangeStops {
        case 10...: self.rating = .excellent
        case 7..<10: self.rating = .good
        case 5..<7: self.rating = .limited
        default: self.rating = .compressed
        }
    }
}

/// Analisi del contrasto
public struct ContrastAnalysis: Sendable {
    /// Contrasto globale (deviazione standard della luminanza)
    public let globalContrast: Double
    
    /// Contrasto locale medio
    public let localContrast: Double
    
    /// Valutazione contrasto
    public let rating: ContrastRating
    
    /// Dettaglio nelle ombre (0-1)
    public let shadowDetail: Double
    
    /// Dettaglio nelle luci (0-1)
    public let highlightDetail: Double
    
    public enum ContrastRating: String, Sendable {
        case high = "Alto"
        case normal = "Normale"
        case low = "Basso"
        case flat = "Piatto"
        
        public var adamsComment: String {
            switch self {
            case .high:
                return "Il contrasto marcato crea drama e tensione. Attenzione a non perdere dettaglio nelle estreme."
            case .normal:
                return "Un contrasto equilibrato che serve bene la maggior parte dei soggetti."
            case .low:
                return "Il basso contrasto può creare un'atmosfera eterea, ma rischia di apparire spento."
            case .flat:
                return "L'immagine appare piatta. Considera N+1 o N+2 in sviluppo per aumentare il contrasto."
            }
        }
    }
    
    public init(globalContrast: Double, localContrast: Double, shadowDetail: Double, highlightDetail: Double) {
        self.globalContrast = globalContrast
        self.localContrast = localContrast
        self.shadowDetail = shadowDetail
        self.highlightDetail = highlightDetail
        
        // Valutazione basata sul contrasto globale
        switch globalContrast {
        case 60...: self.rating = .high
        case 40..<60: self.rating = .normal
        case 25..<40: self.rating = .low
        default: self.rating = .flat
        }
    }
}

/// Analisi compositiva
public struct CompositionAnalysis: Sendable {
    public let sceneType: SceneType
    public let ruleOfThirdsScore: Double
    public let leadingLines: [Line]
    public let balanceScore: Double
    public let focalPoint: CGPoint?
    public let horizonLine: Line?
    public let symmetryScore: Double
    
    public struct Line: Sendable {
        public let start: CGPoint
        public let end: CGPoint
        public let strength: Double
        
        public init(start: CGPoint, end: CGPoint, strength: Double) {
            self.start = start
            self.end = end
            self.strength = strength
        }
    }
    
    public init(
        sceneType: SceneType,
        ruleOfThirdsScore: Double,
        leadingLines: [Line],
        balanceScore: Double,
        focalPoint: CGPoint?,
        horizonLine: Line?,
        symmetryScore: Double
    ) {
        self.sceneType = sceneType
        self.ruleOfThirdsScore = ruleOfThirdsScore
        self.leadingLines = leadingLines
        self.balanceScore = balanceScore
        self.focalPoint = focalPoint
        self.horizonLine = horizonLine
        self.symmetryScore = symmetryScore
    }
}

/// Critica in stile Ansel Adams
public struct AdamsCritique: Sendable {
    public let overallComment: String
    public let technicalComment: String
    public let artisticComment: String
    public let zonePlacementAdvice: String
    public let developmentAdvice: String
    public let printingAdvice: String
    public let filterSuggestion: String?
    
    public init(
        overallComment: String,
        technicalComment: String,
        artisticComment: String,
        zonePlacementAdvice: String,
        developmentAdvice: String,
        printingAdvice: String,
        filterSuggestion: String? = nil
    ) {
        self.overallComment = overallComment
        self.technicalComment = technicalComment
        self.artisticComment = artisticComment
        self.zonePlacementAdvice = zonePlacementAdvice
        self.developmentAdvice = developmentAdvice
        self.printingAdvice = printingAdvice
        self.filterSuggestion = filterSuggestion
    }
}

/// Suggerimento tecnico
public struct TechnicalSuggestion: Identifiable, Sendable {
    public let id = UUID()
    public let category: SuggestionCategory
    public let priority: SuggestionPriority
    public let title: String
    public let description: String
    public let adamsQuote: String
    
    public enum SuggestionCategory: String, Sendable {
        case exposure = "Esposizione"
        case development = "Sviluppo"
        case printing = "Stampa"
        case filters = "Filtri"
        case composition = "Composizione"
        case lighting = "Luce"
    }
    
    public enum SuggestionPriority: String, Sendable {
        case critical = "Critico"
        case important = "Importante"
        case suggestion = "Suggerimento"
        
        public var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .important: return "exclamationmark.circle.fill"
            case .suggestion: return "lightbulb.fill"
            }
        }
    }
}

// MARK: - Development & Exposure Settings

public struct ExposureSettings: Sendable {
    public let zoneIIIPlacement: Zone
    public let meteredZone: Zone
    public let exposureCompensation: Double
    
    public init(zoneIIIPlacement: Zone, meteredZone: Zone) {
        self.zoneIIIPlacement = zoneIIIPlacement
        self.meteredZone = meteredZone
        // Compensazione = differenza tra zona misurata e zona III
        self.exposureCompensation = Double(zoneIIIPlacement.rawValue - meteredZone.rawValue)
    }
}

public enum DevelopmentType: String, Sendable {
    case nMinus2 = "N-2"
    case nMinus1 = "N-1"
    case normal = "N"
    case nPlus1 = "N+1"
    case nPlus2 = "N+2"
    
    public var description: String {
        switch self {
        case .nMinus2: return "Contrazione 2 stops - Per scene ad alto contrasto"
        case .nMinus1: return "Contrazione 1 stop - Per scene contrastate"
        case .normal: return "Sviluppo normale - Per scene a contrasto medio"
        case .nPlus1: return "Espansione 1 stop - Per scene piatte"
        case .nPlus2: return "Espansione 2 stops - Per scene molto piatte"
        }
    }
    
    public var timeAdjustment: Double {
        switch self {
        case .nMinus2: return 0.6
        case .nMinus1: return 0.8
        case .normal: return 1.0
        case .nPlus1: return 1.3
        case .nPlus2: return 1.7
        }
    }
}

public enum FilterType: String, CaseIterable, Sendable {
    case yellow = "Giallo #8"
    case orange = "Arancio #16"
    case red = "Rosso #25"
    case green = "Verde #11"
    case blue = "Blu #47"
    case none = "Nessuno"
    
    public var stopCompensation: Double {
        switch self {
        case .yellow: return 1.0
        case .orange: return 1.5
        case .red: return 2.0
        case .green: return 2.0
        case .blue: return 3.0
        case .none: return 0
        }
    }
    
    public var effect: String {
        switch self {
        case .yellow:
            return "Scurisce leggermente il cielo, aumenta contrasto nuvole"
        case .orange:
            return "Scurisce il cielo significativamente, dramatizza nuvole"
        case .red:
            return "Scurisce molto il cielo, effetto drammatico estremo"
        case .green:
            return "Schiarisce il verde della vegetazione"
        case .blue:
            return "Schiarisce il cielo, usato per effetti infrarosso"
        case .none:
            return "Nessun effetto filtro"
        }
    }
    
    public var adamsRecommendation: String {
        switch self {
        case .yellow:
            return "Il filtro giallo è il mio compagno quotidiano. Sottile ma efficace."
        case .orange:
            return "L'arancio offre un buon equilibrio per la maggior parte dei paesaggi."
        case .red:
            return "Il rosso è per quando vogliamo il cielo che urla. Usare con cautela."
        case .green:
            return "Il verde rivela la struttura della vegetazione come nessun altro."
        case .blue:
            return "Il blu ha usi specializzati. Conosci il tuo intento prima di usarlo."
        case .none:
            return "A volte la luce naturale è tutto ciò di cui abbiamo bisogno."
        }
    }
}

// MARK: - Chat Models

public struct ChatMessage: Identifiable, Sendable {
    public let id = UUID()
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    public let relatedAnalysis: ImageAnalysisResult?
    
    public enum MessageRole: String, Sendable {
        case user = "Utente"
        case assistant = "Ansel"
        case system = "Sistema"
    }
    
    public init(role: MessageRole, content: String, relatedAnalysis: ImageAnalysisResult? = nil) {
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.relatedAnalysis = relatedAnalysis
    }
}

public struct ChatContext: Sendable {
    public var messages: [ChatMessage]
    public var currentAnalysis: ImageAnalysisResult?
    public var language: Language
    
    public enum Language: String, Sendable {
        case italian = "it"
        case english = "en"
    }
    
    public init(messages: [ChatMessage] = [], currentAnalysis: ImageAnalysisResult? = nil, language: Language = .italian) {
        self.messages = messages
        self.currentAnalysis = currentAnalysis
        self.language = language
    }
}
