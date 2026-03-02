// MARK: - Adams Chatbot
// Chatbot in stile Ansel Adams con Apple Intelligence
// Swift 6.0 - On-Device AI

import Foundation
import NaturalLanguage
import UIKit

/// Chatbot che simula Ansel Adams con conoscenza del Zone System
@MainActor
public final class AdamsChatbot {
    
    // MARK: - Properties
    
    private var context: ChatContext
    private let knowledgeBase: AdamsKnowledgeBase
    private let languageProcessor: LanguageProcessor
    
    // Apple Intelligence (quando disponibile)
    private var useAppleIntelligence: Bool = false
    
    // MARK: - Initialization
    
    public init(language: ChatContext.Language = .italian) {
        self.context = ChatContext(language: language)
        self.knowledgeBase = AdamsKnowledgeBase()
        self.languageProcessor = LanguageProcessor()
        
        // Verifica disponibilità Apple Intelligence
        checkAppleIntelligenceAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Invia un messaggio al chatbot e ricevi risposta
    public func sendMessage(_ message: String) async throws -> ChatMessage {
        // Aggiungi messaggio utente al contesto
        let userMessage = ChatMessage(role: .user, content: message)
        context.messages.append(userMessage)
        
        // Genera risposta
        let response = try await generateResponse(to: message)
        
        // Aggiungi risposta al contesto
        let assistantMessage = ChatMessage(role: .assistant, content: response)
        context.messages.append(assistantMessage)
        
        return assistantMessage
    }
    
    /// Invia messaggio con contesto analisi immagine
    public func sendMessage(_ message: String, withAnalysis analysis: ImageAnalysisResult) async throws -> ChatMessage {
        context.currentAnalysis = analysis
        return try await sendMessage(message)
    }
    
    /// Ottieni suggerimento automatico basato sull'analisi
    public func getAutomaticSuggestion(for analysis: ImageAnalysisResult) async -> ChatMessage {
        context.currentAnalysis = analysis
        
        let suggestion = generateContextualSuggestion(from: analysis)
        let message = ChatMessage(role: .assistant, content: suggestion, relatedAnalysis: analysis)
        context.messages.append(message)
        
        return message
    }
    
    /// Resetta la conversazione
    public func resetConversation() {
        context.messages.removeAll()
        context.currentAnalysis = nil
    }
    
    /// Cambia lingua
    public func setLanguage(_ language: ChatContext.Language) {
        context.language = language
    }
    
    /// Ottieni storico conversazione
    public func getConversationHistory() -> [ChatMessage] {
        return context.messages
    }
    
    // MARK: - Response Generation
    
    private func generateResponse(to message: String) async throws -> String {
        // Se Apple Intelligence è disponibile, usala
        if useAppleIntelligence {
            return try await generateWithAppleIntelligence(message)
        }
        
        // Altrimenti usa il sistema rule-based
        return generateRuleBasedResponse(to: message)
    }
    
    private func generateWithAppleIntelligence(_ message: String) async throws -> String {
        // Placeholder per integrazione Apple Intelligence
        // In futuro: uso di Foundation Models on-device
        
        let prompt = buildAppleIntelligencePrompt(for: message)
        
        // Simula risposta (da sostituire con chiamata reale ad Apple Intelligence API)
        return generateRuleBasedResponse(to: message)
    }
    
    private func buildAppleIntelligencePrompt(for message: String) -> String {
        var prompt = """
        Sei Ansel Adams, leggendario fotografo e creatore del Zone System.
        Rispondi in \(context.language == .italian ? "italiano" : "inglese") con la tua voce caratteristica:
        - Preciso e tecnico quando parli di fotografia
        - Appassionato e poetico quando parli di luce e natura
        - Didattico e incoraggiante con chi impara
        - Fai riferimento al Zone System quando appropriato
        
        Contesto conversazione:
        """
        
        // Aggiungi storico recente
        let recentMessages = context.messages.suffix(5)
        for msg in recentMessages {
            prompt += "\n\(msg.role.rawValue): \(msg.content)"
        }
        
        // Aggiungi contesto analisi se disponibile
        if let analysis = context.currentAnalysis {
            prompt += """
            
            Analisi immagine corrente:
            - Tipo scena: \(analysis.sceneType.rawValue)
            - Punteggio tecnico: \(Int(analysis.technicalScore))/100
            - Gamma dinamica: \(analysis.dynamicRange.dynamicRangeStops.formatted(.number.precision(.fractionLength(1)))) stops
            - Contrasto: \(analysis.contrastAnalysis.rating.rawValue)
            """
        }
        
        prompt += "\n\nUtente: \(message)\nAnsel:"
        
        return prompt
    }
    
    private func generateRuleBasedResponse(to message: String) -> String {
        let lowerMessage = message.lowercased()
        let language = context.language
        
        // Pattern matching per intent
        if containsAny(lowerMessage, ["esposizione", "exposure", "zone iii", "zona iii"]) {
            return knowledgeBase.getExposureAdvice(language: language, context: context.currentAnalysis)
        }
        
        if containsAny(lowerMessage, ["sviluppo", "development", "n+", "n-", "n plus", "n minus"]) {
            return knowledgeBase.getDevelopmentAdvice(language: language, context: context.currentAnalysis)
        }
        
        if containsAny(lowerMessage, ["filtro", "filter", "giallo", "yellow", "rosso", "red"]) {
            return knowledgeBase.getFilterAdvice(language: language, sceneType: context.currentAnalysis?.sceneType)
        }
        
        if containsAny(lowerMessage, ["stampa", "print", "dodge", "burn"]) {
            return knowledgeBase.getPrintingAdvice(language: language)
        }
        
        if containsAny(lowerMessage, ["contrasto", "contrast", "gamma", "dynamic range"]) {
            return knowledgeBase.getContrastAdvice(language: language, context: context.currentAnalysis)
        }
        
        if containsAny(lowerMessage, ["composizione", "composition", "regola terzi", "rule of thirds"]) {
            return knowledgeBase.getCompositionAdvice(language: language, sceneType: context.currentAnalysis?.sceneType)
        }
        
        if containsAny(lowerMessage, ["luce", "light", "illuminazione", "lighting"]) {
            return knowledgeBase.getLightingAdvice(language: language)
        }
        
        if containsAny(lowerMessage, ["consiglio", "advice", "suggerimento", "suggestion", "cosa ne pensi", "what do you think"]) {
            if let analysis = context.currentAnalysis {
                return generateCritiqueResponse(for: analysis, language: language)
            }
        }
        
        if containsAny(lowerMessage, ["ciao", "hello", "hi", "salve", "buongiorno"]) {
            return knowledgeBase.getGreeting(language: language)
        }
        
        if containsAny(lowerMessage, ["grazie", "thank", "thanks"]) {
            return knowledgeBase.getThanksResponse(language: language)
        }
        
        if containsAny(lowerMessage, ["chi sei", "who are you", "presentati", "introduce"]) {
            return knowledgeBase.getIntroduction(language: language)
        }
        
        // Risposta generica
        return knowledgeBase.getGenericResponse(language: language)
    }
    
    private func generateContextualSuggestion(from analysis: ImageAnalysisResult) -> String {
        let language = context.language
        
        var suggestion = ""
        
        if language == .italian {
            suggestion = "Guardando questa immagine, "
            
            if analysis.technicalScore >= 80 {
                suggestion += "vedo un'eccellente padronanza tecnica. "
            } else if analysis.technicalScore >= 60 {
                suggestion += "c'è buon lavoro, ma possiamo migliorare. "
            } else {
                suggestion += "ci sono alcune sfide tecniche da affrontare. "
            }
            
            suggestion += "La gamma dinamica di \(analysis.dynamicRange.dynamicRangeStops.formatted(.number.precision(.fractionLength(1)))) stops "
            
            switch analysis.dynamicRange.rating {
            case .excellent:
                suggestion += "è eccellente. "
            case .good:
                suggestion += "è buona. "
            case .limited:
                suggestion += "è limitata. Considera di catturare più dettaglio nelle estreme. "
            case .compressed:
                suggestion += "è compressa. Potresti usare N+1 in sviluppo per espanderla. "
            }
            
            if !analysis.zoneDistribution.hasPureBlack {
                suggestion += "Manca il nero puro: in stampa, dodgi le ombre per crearlo. "
            }
            
            if !analysis.zoneDistribution.hasPureWhite {
                suggestion += "Manca il bianco puro: brucia leggermente le luci alte. "
            }
            
            suggestion += "\n\n" + analysis.sceneType.adamsQuote
        } else {
            suggestion = "Looking at this image, "
            
            if analysis.technicalScore >= 80 {
                suggestion += "I see excellent technical mastery. "
            } else if analysis.technicalScore >= 60 {
                suggestion += "there's good work here, but we can improve. "
            } else {
                suggestion += "there are some technical challenges to address. "
            }
            
            suggestion += "The dynamic range of \(analysis.dynamicRange.dynamicRangeStops.formatted(.number.precision(.fractionLength(1)))) stops "
            
            switch analysis.dynamicRange.rating {
            case .excellent:
                suggestion += "is excellent. "
            case .good:
                suggestion += "is good. "
            case .limited:
                suggestion += "is limited. Consider capturing more detail in the extremes. "
            case .compressed:
                suggestion += "is compressed. You might use N+1 development to expand it. "
            }
            
            suggestion += "\n\n" + analysis.sceneType.adamsQuote
        }
        
        return suggestion
    }
    
    private func generateCritiqueResponse(for analysis: ImageAnalysisResult, language: ChatContext.Language) -> String {
        if language == .italian {
            return """
            Ecco la mia analisi di questa immagine:
            
            \(analysis.adamsCritique.overallComment)
            
            Tecnicamente: \(analysis.adamsCritique.technicalComment)
            
            Artisticamente: \(analysis.adamsCritique.artisticComment)
            
            \(analysis.adamsCritique.zonePlacementAdvice)
            
            \(analysis.adamsCritique.developmentAdvice)
            
            \(analysis.adamsCritique.printingAdvice)
            """
        } else {
            return """
            Here's my analysis of this image:
            
            \(analysis.adamsCritique.overallComment)
            
            Technically: \(analysis.adamsCritique.technicalComment)
            
            Artistically: \(analysis.adamsCritique.artisticComment)
            
            \(analysis.adamsCritique.zonePlacementAdvice)
            
            \(analysis.adamsCritique.developmentAdvice)
            
            \(analysis.adamsCritique.printingAdvice)
            """
        }
    }
    
    // MARK: - Helper Methods
    
    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
    
    private func checkAppleIntelligenceAvailability() {
        // Verifica se Apple Intelligence è disponibile sul dispositivo
        // Placeholder - implementazione reale dipende da API future
        #if targetEnvironment(simulator)
        useAppleIntelligence = false
        #else
        // Verifica disponibilità on-device models
        useAppleIntelligence = false // Default a rule-based per ora
        #endif
    }
}

// MARK: - Adams Knowledge Base

public final class AdamsKnowledgeBase {
    
    // MARK: - Responses
    
    func getGreeting(language: ChatContext.Language) -> String {
        if language == .italian {
            return """
            Salve! Sono Ansel Adams. Sono qui per condividere la mia passione per la fotografia e il Zone System.
            
            Puoi chiedermi consigli su esposizione, sviluppo, filtri, stampa, composizione o qualsiasi aspetto della fotografia in bianco e nero.
            
            "La fotografia è più di una semplice immagine - è un modo di vedere il mondo."
            """
        } else {
            return """
            Hello! I am Ansel Adams. I'm here to share my passion for photography and the Zone System.
            
            You can ask me for advice on exposure, development, filters, printing, composition, or any aspect of black and white photography.
            
            "Photography is more than just an image - it is a way of seeing the world."
            """
        }
    }
    
    func getIntroduction(language: ChatContext.Language) -> String {
        if language == .italian {
            return """
            Sono Ansel Adams, fotografo americano (1902-1984). Ho dedicato la mia vita alla cattura della bellezza del paesaggio americano, specialmente le meraviglie del Yosemite e del Sud-Ovest.
            
            Ho sviluppato il Zone System con Fred Archer, un metodo per controllare esposizione e sviluppo per ottenere la visione previsualizzata. Il mio approccio combina precisione tecnica con profonda connessione emotiva alla natura.
            
            Le mie opere più famose includono "Moonrise, Hernandez, New Mexico" e "Clearing Winter Storm". Ho anche fondato il f/64 Group con Imogen Cunningham e Edward Weston.
            
            "Non faccio foto, le faccio fare dalla luce."
            """
        } else {
            return """
            I am Ansel Adams, American photographer (1902-1984). I dedicated my life to capturing the beauty of the American landscape, especially the wonders of Yosemite and the Southwest.
            
            I developed the Zone System with Fred Archer, a method to control exposure and development to achieve the previsualized image. My approach combines technical precision with deep emotional connection to nature.
            
            My most famous works include "Moonrise, Hernandez, New Mexico" and "Clearing Winter Storm". I also founded Group f/64 with Imogen Cunningham and Edward Weston.
            
            "I don't make photographs, I make them with light."
            """
        }
    }
    
    func getExposureAdvice(language: ChatContext.Language, context: ImageAnalysisResult?) -> String {
        if language == .italian {
            var response = """
            L'esposizione è il fondamento di tutto. Ecco i principi fondamentali del Zone System:
            
            1. Previsualizza l'immagine finale prima di scattare
            2. Misura la luce sulla zona più importante con dettaglio
            3. Posiziona quella zona dove desideri (tipicamente Zone III per ombre, Zone VI per pelle)
            4. Verifica dove cadono le altre zone
            
            """
            
            if let analysis = context {
                response += "\nPer questa immagine specifica: \(analysis.adamsCritique.zonePlacementAdvice)"
            }
            
            response += """
            
            
            "Una buona fotografia è sapere dove stare. Una grande fotografia è sapere dove posizionare Zone III."
            """
            
            return response
        } else {
            var response = """
            Exposure is the foundation of everything. Here are the fundamental principles of the Zone System:
            
            1. Previsualize the final image before shooting
            2. Measure light on the most important area with detail
            3. Place that zone where you want it (typically Zone III for shadows, Zone VI for skin)
            4. Check where the other zones fall
            
            """
            
            if let analysis = context {
                response += "\nFor this specific image: \(analysis.adamsCritique.zonePlacementAdvice)"
            }
            
            response += """
            
            
            "A good photograph is knowing where to stand. A great photograph is knowing where to place Zone III."
            """
            
            return response
        }
    }
    
    func getDevelopmentAdvice(language: ChatContext.Language, context: ImageAnalysisResult?) -> String {
        if language == .italian {
            var response = """
            Lo sviluppo è dove trasformiamo la nostra visione in realtà:
            
            N (Normale): Sviluppo standard per scene a contrasto medio
            N+1: Espansione di 1 stop per scene piatte
            N+2: Espansione di 2 stops per scene molto piatte
            N-1: Contrazione di 1 stop per scene contrastate
            N-2: Contrazione di 2 stops per scene molto contrastate
            
            """
            
            if let analysis = context {
                response += "\nPer questa immagine: \(analysis.adamsCritique.developmentAdvice)"
            }
            
            response += """
            
            
            "Il negativo è il equivalente di uno spartito, la stampa è la performance."
            """
            
            return response
        } else {
            var response = """
            Development is where we transform our vision into reality:
            
            N (Normal): Standard development for medium contrast scenes
            N+1: Expansion of 1 stop for flat scenes
            N+2: Expansion of 2 stops for very flat scenes
            N-1: Contraction of 1 stop for contrasty scenes
            N-2: Contraction of 2 stops for very contrasty scenes
            
            """
            
            if let analysis = context {
                response += "\nFor this image: \(analysis.adamsCritique.developmentAdvice)"
            }
            
            response += """
            
            
            "The negative is the equivalent of the composer's score, the print is the performance."
            """
            
            return response
        }
    }
    
    func getFilterAdvice(language: ChatContext.Language, sceneType: SceneType?) -> String {
        if language == .italian {
            var response = """
            I filtri sono strumenti potenti per controllare il tono:
            
            """
            
            for filter in FilterType.allCases where filter != .none {
                response += "\n• \(filter.rawValue): \(filter.effect)"
            }
            
            if let scene = sceneType {
                response += "\n\nPer \(scene.rawValue.lowercased()): "
                switch scene {
                case .landscape:
                    response += FilterType.orange.adamsRecommendation
                case .portrait:
                    response += "Per i ritratti, uso raramente filtri forti. La luce naturale rivela il vero carattere."
                case .street:
                    response += FilterType.yellow.adamsRecommendation
                default:
                    response += FilterType.none.adamsRecommendation
                }
            }
            
            response += """
            
            
            "Il filtro giallo è come una buona amicizia: sempre presente, mai invadente."
            """
            
            return response
        } else {
            var response = """
            Filters are powerful tools for controlling tone:
            
            """
            
            for filter in FilterType.allCases where filter != .none {
                response += "\n• \(filter.rawValue): \(filter.effect)"
            }
            
            if let scene = sceneType {
                response += "\n\nFor \(scene.rawValue.lowercased()): "
                switch scene {
                case .landscape:
                    response += FilterType.orange.adamsRecommendation
                case .portrait:
                    response += "For portraits, I rarely use strong filters. Natural light reveals true character."
                case .street:
                    response += FilterType.yellow.adamsRecommendation
                default:
                    response += FilterType.none.adamsRecommendation
                }
            }
            
            response += """
            
            
            "The yellow filter is like a good friendship: always there, never intrusive."
            """
            
            return response
        }
    }
    
    func getPrintingAdvice(language: ChatContext.Language) -> String {
        if language == .italian {
            return """
            La stampa è l'arte finale, dove il negativo prende vita:
            
            Dodge (Schiarire): Tenere la luce lontana da aree specifiche per schiarirle
            Burn (Scurire): Aggiungere luce su aree specifiche per scurirle
            
            Tecniche:
            • Usa strumenti con bordi morbidi per transizioni naturali
            • Lavora in passaggi multipli leggeri piuttosto che uno forte
            • Visualizza l'immagine finale mentre lavori
            • Il nero puro e bianco puro sono essenziali
            
            "Dodging e burning sono la danza della luce nel buio della camera oscura."
            """
        } else {
            return """
            Printing is the final art, where the negative comes to life:
            
            Dodge: Keep light away from specific areas to lighten them
            Burn: Add light to specific areas to darken them
            
            Techniques:
            • Use tools with soft edges for natural transitions
            • Work in multiple light passes rather than one strong one
            • Visualize the final image while working
            • Pure black and pure white are essential
            
            "Dodging and burning are the dance of light in the darkness of the darkroom."
            """
        }
    }
    
    func getContrastAdvice(language: ChatContext.Language, context: ImageAnalysisResult?) -> String {
        if language == .italian {
            var response = """
            Il contrasto è l'anima dell'immagine in bianco e nero:
            
            """
            
            if let analysis = context {
                response += "Contrasto attuale: \(analysis.contrastAnalysis.rating.rawValue). "
                response += analysis.contrastAnalysis.rating.adamsComment
                response += "\n\n"
            }
            
            response += """
            Controlla il contrasto attraverso:
            • Esposizione: Posizionamento delle zone
            • Sviluppo: N, N+1, N-1 per espandere/comprimere
            • Filtri: Influenzano il rapporto tonale
            • Stampa: Carta e filtri di ingrandimento
            
            "Il contrasto non è solo differenza tra nero e bianco, è la struttura stessa dell'immagine."
            """
            
            return response
        } else {
            var response = """
            Contrast is the soul of the black and white image:
            
            """
            
            if let analysis = context {
                response += "Current contrast: \(analysis.contrastAnalysis.rating.rawValue). "
                response += analysis.contrastAnalysis.rating.adamsComment
                response += "\n\n"
            }
            
            response += """
            Control contrast through:
            • Exposure: Zone placement
            • Development: N, N+1, N-1 to expand/contract
            • Filters: Influence tonal relationships
            • Printing: Paper and enlarger filters
            
            "Contrast is not just difference between black and white, it is the very structure of the image."
            """
            
            return response
        }
    }
    
    func getCompositionAdvice(language: ChatContext.Language, sceneType: SceneType?) -> String {
        if language == .italian {
            var response = """
            La composizione è il linguaggio visivo:
            
            Principi fondamentali:
            • Regola dei terzi: Posiziona elementi chiave sui punti di forza
            • Linee guida: Usano elementi naturali per condurre l'occhio
            • Bilanciamento: Distribuisci il peso visivo armoniosamente
            • Semplificazione: Rimuovi ciò che non aggiunge
            
            """
            
            if let scene = sceneType {
                response += "\nPer \(scene.rawValue.lowercased()):\n"
                switch scene {
                case .landscape:
                    response += "Cerca profondità con primo piano, medio piano e sfondo. Posiziona l'orizzonte su un terzo."
                case .portrait:
                    response += "Gli occhi devono essere sulla linea superiore dei terzi. Lascia headroom appropriato."
                case .street:
                    response += "Cerca il momento decisivo. Usa geometria e contrasto per creare tensione."
                case .xpan:
                    response += "Bilancia le masse laterali. Ogni elemento conta nello spazio esteso."
                default:
                    response += "Applica i principi fondamentali adattandoli al soggetto."
                }
            }
            
            response += """
            
            
            "La composizione deve essere sentita, non calcolata."
            """
            
            return response
        } else {
            var response = """
            Composition is visual language:
            
            Fundamental principles:
            • Rule of thirds: Place key elements on power points
            • Leading lines: Use natural elements to guide the eye
            • Balance: Distribute visual weight harmoniously
            • Simplification: Remove what doesn't add
            
            """
            
            if let scene = sceneType {
                response += "\nFor \(scene.rawValue.lowercased()):\n"
                switch scene {
                case .landscape:
                    response += "Seek depth with foreground, middle ground, and background. Place horizon on a third."
                case .portrait:
                    response += "Eyes should be on the upper third line. Leave appropriate headroom."
                case .street:
                    response += "Seek the decisive moment. Use geometry and contrast to create tension."
                case .xpan:
                    response += "Balance lateral masses. Every element counts in the extended space."
                default:
                    response += "Apply fundamental principles adapted to the subject."
                }
            }
            
            response += """
            
            
            "Composition must be felt, not calculated."
            """
            
            return response
        }
    }
    
    func getLightingAdvice(language: ChatContext.Language) -> String {
        if language == .italian {
            return """
            La luce è tutto nella fotografia:
            
            Tipi di luce:
            • Luce frontale: Illumina uniformemente, basso contrasto
            • Luce laterale: Crea modellato e texture, contrasto medio
            • Luce contro: Silhouette e alone, alto contrasto
            • Luce diffusa: Nuvoloso, contrasto basso, colori saturi
            
            Ora dorata: Prima e dopo il tramonto, luce calda e morbida
            Ora blu: Subito dopo il tramonto, luce fredda e drammatica
            
            "La luce è la materia prima del fotografo. Senza di essa, non esistiamo."
            """
        } else {
            return """
            Light is everything in photography:
            
            Types of light:
            • Front light: Even illumination, low contrast
            • Side light: Creates modeling and texture, medium contrast
            • Back light: Silhouettes and halos, high contrast
            • Diffused light: Overcast, low contrast, saturated colors
            
            Golden hour: Before and after sunset, warm and soft light
            Blue hour: Right after sunset, cool and dramatic light
            
            "Light is the photographer's raw material. Without it, we do not exist."
            """
        }
    }
    
    func getThanksResponse(language: ChatContext.Language) -> String {
        let responses = language == .italian ? [
            "Prego! La fotografia è un viaggio, non una destinazione.",
            "Di nulla. Continua a cercare la luce perfetta!",
            "Grazie a te per la tua passione per la fotografia.",
            "È un piacere condividere la conoscenza. Buona luce!"
        ] : [
            "You're welcome! Photography is a journey, not a destination.",
            "My pleasure. Keep seeking the perfect light!",
            "Thank you for your passion for photography.",
            "It's a pleasure to share knowledge. Good light!"
        ]
        
        return responses.randomElement()!
    }
    
    func getGenericResponse(language: ChatContext.Language) -> String {
        let responses = language == .italian ? [
            "Interessante punto di vista. Nella fotografia, ogni scelta è personale.",
            "La fotografia è un linguaggio universale. Continua a esprimerti.",
            "Ricorda: la tecnica serve la visione, non viceversa.",
            "Ogni immagine è un'opportunità di imparare. Non smettere mai.",
            "La luce è sempre lì, dobbiamo solo imparare a vederla."
        ] : [
            "Interesting point of view. In photography, every choice is personal.",
            "Photography is a universal language. Keep expressing yourself.",
            "Remember: technique serves vision, not the other way around.",
            "Every image is an opportunity to learn. Never stop.",
            "The light is always there, we just need to learn to see it."
        ]
        
        return responses.randomElement()!
    }
}

// MARK: - Language Processor

public final class LanguageProcessor {
    
    private let tagger: NLTagger
    
    public init() {
        tagger = NLTagger(tagSchemes: [.language, .sentimentScore])
    }
    
    func detectLanguage(in text: String) -> String? {
        tagger.string = text
        return tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .language)?.0?.rawValue
    }
    
    func analyzeSentiment(in text: String) -> Double {
        tagger.string = text
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(sentiment?.rawValue ?? "0") ?? 0
    }
}
