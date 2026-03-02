// MARK: - Suggestion Engine
// Motore di suggerimenti tecnici per esposizione, sviluppo e stampa
// Swift 6.0 - Apple Intelligence On-Device

import Foundation
import UIKit

/// Motore per generare suggerimenti tecnici personalizzati
@MainActor
public final class SuggestionEngine {
    
    // MARK: - Properties
    
    private var userPreferences: UserPreferences
    private let suggestionHistory: SuggestionHistory
    
    // MARK: - Initialization
    
    public init(preferences: UserPreferences = UserPreferences()) {
        self.userPreferences = preferences
        self.suggestionHistory = SuggestionHistory()
    }
    
    // MARK: - Public Methods
    
    /// Genera suggerimenti completi per un'analisi
    public func generateSuggestions(for analysis: ImageAnalysisResult) -> SuggestionSet {
        var suggestions: [TechnicalSuggestion] = []
        
        // Suggerimenti esposizione
        suggestions.append(contentsOf: generateExposureSuggestions(analysis))
        
        // Suggerimenti sviluppo
        suggestions.append(contentsOf: generateDevelopmentSuggestions(analysis))
        
        // Suggerimenti filtri
        suggestions.append(contentsOf: generateFilterSuggestions(analysis))
        
        // Suggerimenti stampa
        suggestions.append(contentsOf: generatePrintingSuggestions(analysis))
        
        // Suggerimenti composizione
        suggestions.append(contentsOf: generateCompositionSuggestions(analysis))
        
        // Ordina per priorità
        suggestions.sort { $0.priority.rawValue > $1.priority.rawValue }
        
        return SuggestionSet(
            imageId: analysis.imageId,
            timestamp: Date(),
            suggestions: suggestions,
            exposureSettings: calculateExposureSettings(analysis),
            developmentType: recommendDevelopment(analysis),
            filterRecommendation: recommendFilter(analysis),
            printingNotes: generatePrintingNotes(analysis)
        )
    }
    
    /// Genera suggerimento rapido per preview
    public func generateQuickSuggestion(for analysis: ImageAnalysisResult) -> String {
        let zoneDist = analysis.zoneDistribution
        
        if zoneDist.isUnderexposed {
            return "Sottoesposta: +1 stop, considera N+1"
        } else if zoneDist.isOverexposed {
            return "Sovraesposta: -1 stop, considera N-1"
        } else if !zoneDist.hasPureBlack {
            return "Manca nero puro: dodgi in stampa"
        } else if !zoneDist.hasPureWhite {
            return "Manca bianco puro: brucia in stampa"
        } else if analysis.contrastAnalysis.rating == .flat {
            return "Contrasto basso: N+1 consigliato"
        } else if analysis.contrastAnalysis.rating == .high {
            return "Alto contrasto: N-1 consigliato"
        }
        
        return "Esposizione corretta: sviluppo N"
    }
    
    /// Calcola impostazioni esposizione dettagliate
    public func calculateExposureSettings(_ analysis: ImageAnalysisResult) -> ExposureSettings {
        let zoneDist = analysis.zoneDistribution
        
        // Determina dove posizionare Zone III
        let zoneIIIPlacement: Zone
        
        if zoneDist.isUnderexposed {
            zoneIIIPlacement = .zone4 // Compensa sottoesposizione
        } else if zoneDist.isOverexposed {
            zoneIIIPlacement = .zone2 // Protegge luci
        } else {
            zoneIIIPlacement = .zone3 // Standard
        }
        
        // Determina zona misurata
        let meteredZone: Zone = zoneDist.dominantZone
        
        return ExposureSettings(zoneIIIPlacement: zoneIIIPlacement, meteredZone: meteredZone)
    }
    
    /// Raccomanda tipo sviluppo
    public func recommendDevelopment(_ analysis: ImageAnalysisResult) -> DevelopmentType {
        switch analysis.contrastAnalysis.rating {
        case .high:
            return .nMinus1
        case .flat:
            return .nPlus1
        case .low:
            return .nPlus1
        case .normal:
            return .normal
        }
    }
    
    /// Raccomanda filtro
    public func recommendFilter(_ analysis: ImageAnalysisResult) -> FilterType? {
        switch analysis.sceneType {
        case .landscape:
            if analysis.zoneDistribution.highlightPercentage > 30 {
                return .orange
            }
            return .yellow
        case .street:
            return .yellow
        case .portrait:
            return nil
        default:
            return nil
        }
    }
    
    /// Genera note per stampa
    public func generatePrintingNotes(_ analysis: ImageAnalysisResult) -> PrintingNotes {
        var dodgeAreas: [PrintingNotes.Area] = []
        var burnAreas: [PrintingNotes.Area] = []
        var paperGrade: Int = 2
        
        let zoneDist = analysis.zoneDistribution
        
        // Determina aree da dodgiare (schiarire)
        if zoneDist.shadowPercentage > 50 {
            // Ombre troppo scure
            dodgeAreas.append(PrintingNotes.Area(
                description: "Ombre profonde",
                zone: .zone2,
                percentage: 20
            ))
        }
        
        // Determina aree da bruciare (scurire)
        if zoneDist.highlightPercentage > 50 {
            // Luci troppo brillanti
            burnAreas.append(PrintingNotes.Area(
                description: "Luci alte",
                zone: .zone8,
                percentage: 15
            ))
        }
        
        // Determina grado carta
        switch analysis.contrastAnalysis.rating {
        case .high:
            paperGrade = 1
        case .flat:
            paperGrade = 4
        case .low:
            paperGrade = 3
        case .normal:
            paperGrade = 2
        }
        
        return PrintingNotes(
            paperGrade: paperGrade,
            dodgeAreas: dodgeAreas,
            burnAreas: burnAreas,
            specialNotes: generateSpecialNotes(analysis)
        )
    }
    
    // MARK: - Private Methods
    
    private func generateExposureSuggestions(_ analysis: ImageAnalysisResult) -> [TechnicalSuggestion] {
        var suggestions: [TechnicalSuggestion] = []
        let zoneDist = analysis.zoneDistribution
        
        if zoneDist.isUnderexposed {
            suggestions.append(TechnicalSuggestion(
                category: .exposure,
                priority: .critical,
                title: "Correggi sottoesposizione",
                description: "L'immagine è sottoesposta del \(Int(zoneDist.shadowPercentage - 40))%. Aumenta l'esposizione di 1-2 stop per recuperare dettaglio nelle ombre.",
                adamsQuote: "Le ombre senza dettaglio sono perdute per sempre. Meglio sovraesporre leggermente."
            ))
        }
        
        if zoneDist.isOverexposed {
            suggestions.append(TechnicalSuggestion(
                category: .exposure,
                priority: .critical,
                title: "Correggi sovraesposizione",
                description: "L'immagine è sovraesposta del \(Int(zoneDist.highlightPercentage - 40))%. Riduci l'esposizione per proteggere le luci alte.",
                adamsQuote: "Le luci bruciate non possono essere recuperate. Proteggile con saggezza."
            ))
        }
        
        if !zoneDist.hasPureBlack {
            suggestions.append(TechnicalSuggestion(
                category: .exposure,
                priority: .important,
                title: "Manca nero puro",
                description: "L'immagine non ha nero puro (Zone 0). Considera di esporre leggermente di meno o usa dodging in stampa.",
                adamsQuote: "Il nero puro è l'ancora della nostra gamma tonale."
            ))
        }
        
        if !zoneDist.hasPureWhite {
            suggestions.append(TechnicalSuggestion(
                category: .exposure,
                priority: .important,
                title: "Manca bianco puro",
                description: "L'immagine non ha bianco puro (Zone 10). Considera di esporre leggermente di più o usa burning in stampa.",
                adamsQuote: "Il bianco puro dà luminosità e aria all'immagine."
            ))
        }
        
        return suggestions
    }
    
    private func generateDevelopmentSuggestions(_ analysis: ImageAnalysisResult) -> [TechnicalSuggestion] {
        var suggestions: [TechnicalSuggestion] = []
        let contrast = analysis.contrastAnalysis
        
        switch contrast.rating {
        case .high:
            suggestions.append(TechnicalSuggestion(
                category: .development,
                priority: .important,
                title: "Sviluppo N-1 o N-2",
                description: "Alto contrasto scenico. Comprimi la gamma con N-1 per mantenere dettaglio in ombre e luci. Tempo sviluppo: \(Int(100 * DevelopmentType.nMinus1.timeAdjustment))% del normale.",
                adamsQuote: "La contrazione in sviluppo salva le immagini ad alto contrasto."
            ))
            
        case .flat:
            suggestions.append(TechnicalSuggestion(
                category: .development,
                priority: .important,
                title: "Sviluppo N+1 o N+2",
                description: "Contrasto piatto. Espandi la gamma con N+1 per dare più punch. Tempo sviluppo: \(Int(100 * DevelopmentType.nPlus1.timeAdjustment))% del normale.",
                adamsQuote: "L'espansione in sviluppo dà vita alle immagini piatte."
            ))
            
        case .low:
            suggestions.append(TechnicalSuggestion(
                category: .development,
                priority: .suggestion,
                title: "Considera N+1",
                description: "Contrasto leggermente basso. N+1 potrebbe migliorare la struttura dell'immagine.",
                adamsQuote: "Un po' di espansione può fare meraviglie."
            ))
            
        case .normal:
            suggestions.append(TechnicalSuggestion(
                category: .development,
                priority: .suggestion,
                title: "Sviluppo N standard",
                description: "Il contrasto è ben bilanciato. Sviluppo normale darà ottimi risultati.",
                adamsQuote: "A volte la semplicità è la scelta migliore."
            ))
        }
        
        // Suggerimenti dettaglio
        if contrast.shadowDetail < 0.3 {
            suggestions.append(TechnicalSuggestion(
                category: .development,
                priority: .important,
                title: "Recupera dettaglio ombre",
                description: "Dettaglio nelle ombre limitato. Considera N-1 o N-2 per comprimere e mantenere informazione.",
                adamsQuote: "Le ombre devono cantare, non sussurrare."
            ))
        }
        
        if contrast.highlightDetail < 0.3 {
            suggestions.append(TechnicalSuggestion(
                category: .development,
                priority: .important,
                title: "Proteggi dettaglio luci",
                description: "Dettaglio nelle luci limitato. N-1 aiuterà a comprimere la gamma verso il basso.",
                adamsQuote: "Le luci devono brillare, non accecare."
            ))
        }
        
        return suggestions
    }
    
    private func generateFilterSuggestions(_ analysis: ImageAnalysisResult) -> [TechnicalSuggestion] {
        var suggestions: [TechnicalSuggestion] = []
        
        guard let filter = recommendFilter(analysis) else {
            return suggestions
        }
        
        let priority: TechnicalSuggestion.SuggestionPriority = 
            analysis.sceneType == .landscape ? .important : .suggestion
        
        suggestions.append(TechnicalSuggestion(
            category: .filters,
            priority: priority,
            title: "Filtro \(filter.rawValue)",
            description: filter.effect + " Compensazione esposizione: +\(filter.stopCompensation) stop.",
            adamsQuote: filter.adamsRecommendation
        ))
        
        return suggestions
    }
    
    private func generatePrintingSuggestions(_ analysis: ImageAnalysisResult) -> [TechnicalSuggestion] {
        var suggestions: [TechnicalSuggestion] = []
        let zoneDist = analysis.zoneDistribution
        
        // Suggerimenti dodge/burn
        if !zoneDist.hasPureBlack {
            suggestions.append(TechnicalSuggestion(
                category: .printing,
                priority: .important,
                title: "Dodgi le ombre",
                description: "Crea nero puro nelle ombre più profonde usando tecniche di dodging in stampa.",
                adamsQuote: "Il dodging è la carezza della luce sulle ombre."
            ))
        }
        
        if !zoneDist.hasPureWhite {
            suggestions.append(TechnicalSuggestion(
                category: .printing,
                priority: .important,
                title: "Brucia le luci",
                description: "Crea bianco puro nelle aree di massima luminosità usando burning.",
                adamsQuote: "Il burning è l'abbraccio della luce sulle alte luci."
            ))
        }
        
        // Suggerimento grado carta
        let paperGrade: Int
        switch analysis.contrastAnalysis.rating {
        case .high: paperGrade = 1
        case .flat: paperGrade = 4
        case .low: paperGrade = 3
        case .normal: paperGrade = 2
        }
        
        suggestions.append(TechnicalSuggestion(
            category: .printing,
            priority: .suggestion,
            title: "Carta grado \(paperGrade)",
            description: "Per questo livello di contrasto, carta grado \(paperGrade) darà i migliori risultati.",
            adamsQuote: "La carta giusta è come la cornice giusta per un quadro."
        ))
        
        return suggestions
    }
    
    private func generateCompositionSuggestions(_ analysis: ImageAnalysisResult) -> [TechnicalSuggestion] {
        var suggestions: [TechnicalSuggestion] = []
        let composition = analysis.compositionAnalysis
        
        if composition.ruleOfThirdsScore < 0.5 {
            suggestions.append(TechnicalSuggestion(
                category: .composition,
                priority: .suggestion,
                title: "Migliora regola terzi",
                description: "Il soggetto principale non è posizionato ottimalmente. Prova a collocarlo sui punti di forza della regola dei terzi.",
                adamsQuote: "La regola dei terzi è una guida, non una prigione. Ma è una buona guida."
            ))
        }
        
        if composition.leadingLines.isEmpty {
            suggestions.append(TechnicalSuggestion(
                category: .composition,
                priority: .suggestion,
                title: "Aggiungi linee guida",
                description: "Cerca elementi naturali (strade, recinzioni, fiumi) che conducano l'occhio al soggetto.",
                adamsQuote: "Le linee guida sono i sentieri che portano l'occhio attraverso l'immagine."
            ))
        }
        
        if composition.balanceScore < 0.5 {
            suggestions.append(TechnicalSuggestion(
                category: .composition,
                priority: .suggestion,
                title: "Migliora bilanciamento",
                description: "La composizione appare sbilanciata. Cerca di distribuire il peso visivo più armoniosamente.",
                adamsQuote: "Il bilanciamento è la danza visiva degli elementi."
            ))
        }
        
        return suggestions
    }
    
    private func generateSpecialNotes(_ analysis: ImageAnalysisResult) -> [String] {
        var notes: [String] = []
        
        if analysis.zoneDistribution.isUnderexposed {
            notes.append("Attenzione: immagine sottoesposta. Considera di ristampare con maggiore esposizione.")
        }
        
        if analysis.zoneDistribution.isOverexposed {
            notes.append("Attenzione: immagine sovraesposta. Riduci esposizione in stampa.")
        }
        
        if analysis.contrastAnalysis.rating == .high {
            notes.append("Alto contrasto: usa filtro basso in ingranditore.")
        }
        
        return notes
    }
}

// MARK: - Supporting Types

public struct SuggestionSet: Sendable {
    public let imageId: UUID
    public let timestamp: Date
    public let suggestions: [TechnicalSuggestion]
    public let exposureSettings: ExposureSettings
    public let developmentType: DevelopmentType
    public let filterRecommendation: FilterType?
    public let printingNotes: PrintingNotes
    
    /// Suggerimenti critici (priorità alta)
    public var criticalSuggestions: [TechnicalSuggestion] {
        suggestions.filter { $0.priority == .critical }
    }
    
    /// Suggerimenti importanti
    public var importantSuggestions: [TechnicalSuggestion] {
        suggestions.filter { $0.priority == .important }
    }
    
    /// Suggerimenti opzionali
    public var optionalSuggestions: [TechnicalSuggestion] {
        suggestions.filter { $0.priority == .suggestion }
    }
}

public struct PrintingNotes: Sendable {
    public let paperGrade: Int
    public let dodgeAreas: [Area]
    public let burnAreas: [Area]
    public let specialNotes: [String]
    
    public struct Area: Sendable {
        public let description: String
        public let zone: Zone
        public let percentage: Int
        
        public init(description: String, zone: Zone, percentage: Int) {
            self.description = description
            self.zone = zone
            self.percentage = percentage
        }
    }
    
    public var hasDodging: Bool {
        !dodgeAreas.isEmpty
    }
    
    public var hasBurning: Bool {
        !burnAreas.isEmpty
    }
    
    public var summary: String {
        var parts: [String] = []
        
        parts.append("Carta grado \(paperGrade)")
        
        if hasDodging {
            parts.append("Dodging: \(dodgeAreas.map { $0.description }.joined(separator: ", "))")
        }
        
        if hasBurning {
            parts.append("Burning: \(burnAreas.map { $0.description }.joined(separator: ", "))")
        }
        
        return parts.joined(separator: " | ")
    }
}

public struct UserPreferences: Sendable {
    public var preferredPaperGrade: Int
    public var defaultDevelopment: DevelopmentType
    public var favoriteFilters: [FilterType]
    public var skillLevel: SkillLevel
    
    public enum SkillLevel: String, Sendable {
        case beginner = "Principiante"
        case intermediate = "Intermedio"
        case advanced = "Avanzato"
        case master = "Maestro"
    }
    
    public init(
        preferredPaperGrade: Int = 2,
        defaultDevelopment: DevelopmentType = .normal,
        favoriteFilters: [FilterType] = [.yellow],
        skillLevel: SkillLevel = .intermediate
    ) {
        self.preferredPaperGrade = preferredPaperGrade
        self.defaultDevelopment = defaultDevelopment
        self.favoriteFilters = favoriteFilters
        self.skillLevel = skillLevel
    }
}

public final class SuggestionHistory {
    private var history: [UUID: [SuggestionSet]] = [:]
    
    func add(_ suggestion: SuggestionSet, for imageId: UUID) {
        if history[imageId] == nil {
            history[imageId] = []
        }
        history[imageId]?.append(suggestion)
    }
    
    func getHistory(for imageId: UUID) -> [SuggestionSet] {
        return history[imageId] ?? []
    }
    
    func clear() {
        history.removeAll()
    }
}

// MARK: - Extensions

extension TechnicalSuggestion {
    /// Formatta il suggerimento per display
    public var formattedDisplay: String {
        return "[\(priority.rawValue)] \(title)\n\(description)"
    }
}
