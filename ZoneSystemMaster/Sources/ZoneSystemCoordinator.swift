// MARK: - Zone System Coordinator
// Coordinator principale per integrazione di tutti i componenti
// Swift 6.0 - Apple Intelligence On-Device AI Engine

import Foundation
import UIKit
import SwiftUI

/// Coordinator principale che gestisce l'intero flusso di analisi
@MainActor
public final class ZoneSystemCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentAnalysis: ImageAnalysisResult?
    @Published public var isAnalyzing: Bool = false
    @Published public var analysisError: Error?
    @Published public var analysisHistory: [ImageAnalysisResult] = []
    
    // MARK: - Components
    
    public let critiqueEngine: AICritiqueEngine
    public let zoneAnalyzer: ZoneAnalyzer
    public let compositionAnalyzer: CompositionAnalyzer
    public let chatbot: AdamsChatbot
    public let suggestionEngine: SuggestionEngine
    
    // MARK: - Settings
    
    public var userPreferences: UserPreferences
    
    // MARK: - Initialization
    
    public init(preferences: UserPreferences = UserPreferences()) {
        self.critiqueEngine = AICritiqueEngine()
        self.zoneAnalyzer = ZoneAnalyzer()
        self.compositionAnalyzer = CompositionAnalyzer()
        self.chatbot = AdamsChatbot()
        self.suggestionEngine = SuggestionEngine(preferences: preferences)
        self.userPreferences = preferences
        
        // Carica storico se disponibile
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    /// Analizza un'immagine completa
    public func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        analysisError = nil
        
        do {
            let result = try await critiqueEngine.analyzeImage(image)
            
            await MainActor.run {
                self.currentAnalysis = result
                self.analysisHistory.append(result)
                self.isAnalyzing = false
                
                // Salva in storico
                saveHistory()
            }
        } catch {
            await MainActor.run {
                self.analysisError = error
                self.isAnalyzing = false
            }
        }
    }
    
    /// Analisi rapida per preview
    public func quickAnalyze(_ image: UIImage) async -> QuickAnalysisResult? {
        do {
            return try await critiqueEngine.quickAnalyze(image)
        } catch {
            self.analysisError = error
            return nil
        }
    }
    
    /// Analisi batch
    public func analyzeBatch(images: [UIImage], progressHandler: ((Int, Int) -> Void)? = nil) async -> [ImageAnalysisResult] {
        var results: [ImageAnalysisResult] = []
        let total = images.count
        
        for (index, image) in images.enumerated() {
            await analyzeImage(image)
            
            if let result = currentAnalysis {
                results.append(result)
            }
            
            progressHandler?(index + 1, total)
        }
        
        return results
    }
    
    /// Ottieni suggerimenti per analisi corrente
    public func getSuggestions() -> SuggestionSet? {
        guard let analysis = currentAnalysis else { return nil }
        return suggestionEngine.generateSuggestions(for: analysis)
    }
    
    /// Ottieni suggerimento rapido
    public func getQuickSuggestion() -> String {
        guard let analysis = currentAnalysis else { return "Nessuna analisi disponibile" }
        return suggestionEngine.generateQuickSuggestion(for: analysis)
    }
    
    /// Invia messaggio al chatbot
    public func chatWithAdams(_ message: String) async throws -> ChatMessage {
        if let analysis = currentAnalysis {
            return try await chatbot.sendMessage(message, withAnalysis: analysis)
        } else {
            return try await chatbot.sendMessage(message)
        }
    }
    
    /// Resetta analisi corrente
    public func resetAnalysis() {
        currentAnalysis = nil
        analysisError = nil
    }
    
    /// Cancella storico
    public func clearHistory() {
        analysisHistory.removeAll()
        saveHistory()
    }
    
    /// Esporta analisi
    public func exportAnalysis(_ analysis: ImageAnalysisResult) -> Data? {
        let exportData = AnalysisExport(
            analysis: analysis,
            exportDate: Date(),
            version: "1.0"
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    /// Confronta due analisi
    public func compareAnalyses(_ analysis1: ImageAnalysisResult, _ analysis2: ImageAnalysisResult) -> AnalysisComparison {
        return AnalysisComparison(
            analysis1: analysis1,
            analysis2: analysis2,
            technicalScoreDiff: analysis1.technicalScore - analysis2.technicalScore,
            artisticScoreDiff: analysis1.artisticScore - analysis2.artisticScore,
            dynamicRangeDiff: analysis1.dynamicRange.dynamicRangeStops - analysis2.dynamicRange.dynamicRangeStops,
            contrastDiff: analysis1.contrastAnalysis.globalContrast - analysis2.contrastAnalysis.globalContrast
        )
    }
    
    // MARK: - Private Methods
    
    private func loadHistory() {
        // Implementazione caricamento da UserDefaults o file
        // Placeholder
    }
    
    private func saveHistory() {
        // Implementazione salvataggio
        // Placeholder
    }
}

// MARK: - Analysis Export

public struct AnalysisExport: Codable {
    public let analysis: ImageAnalysisResult
    public let exportDate: Date
    public let version: String
    
    // Codable conformance per ImageAnalysisResult
    enum CodingKeys: String, CodingKey {
        case analysis
        case exportDate
        case version
    }
}

// MARK: - Analysis Comparison

public struct AnalysisComparison: Sendable {
    public let analysis1: ImageAnalysisResult
    public let analysis2: ImageAnalysisResult
    public let technicalScoreDiff: Double
    public let artisticScoreDiff: Double
    public let dynamicRangeDiff: Double
    public let contrastDiff: Double
    
    public var betterTechnical: ImageAnalysisResult {
        technicalScoreDiff > 0 ? analysis1 : analysis2
    }
    
    public var betterArtistic: ImageAnalysisResult {
        artisticScoreDiff > 0 ? analysis1 : analysis2
    }
    
    public var summary: String {
        var parts: [String] = []
        
        if abs(technicalScoreDiff) > 5 {
            parts.append("Differenza tecnica: \(Int(abs(technicalScoreDiff))) punti")
        }
        
        if abs(artisticScoreDiff) > 5 {
            parts.append("Differenza artistica: \(Int(abs(artisticScoreDiff))) punti")
        }
        
        if abs(dynamicRangeDiff) > 1 {
            parts.append("Differenza gamma: \(String(format: "%.1f", abs(dynamicRangeDiff))) stops")
        }
        
        return parts.joined(separator: "\n")
    }
}

// MARK: - SwiftUI View Extensions

public extension ZoneSystemCoordinator {
    /// View principale per analisi
    func analysisView(for image: UIImage) -> some View {
        AnalysisContainerView(coordinator: self, image: image)
    }
    
    /// View per chatbot
    func chatbotView() -> some View {
        AdamsChatView(analysis: currentAnalysis)
    }
    
    /// View dashboard analisi
    func dashboardView() -> some View {
        Group {
            if let analysis = currentAnalysis {
                AnalysisDashboard(analysis: analysis)
            } else {
                EmptyAnalysisView()
            }
        }
    }
}

// MARK: - Analysis Container View

struct AnalysisContainerView: View {
    @ObservedObject var coordinator: ZoneSystemCoordinator
    let image: UIImage
    
    var body: some View {
        VStack {
            if coordinator.isAnalyzing {
                AnalyzingView()
            } else if let error = coordinator.analysisError {
                ErrorView(error: error) {
                    Task {
                        await coordinator.analyzeImage(image)
                    }
                }
            } else if let analysis = coordinator.currentAnalysis {
                AnalysisDashboard(analysis: analysis)
            } else {
                ReadyToAnalyzeView(image: image) {
                    Task {
                        await coordinator.analyzeImage(image)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct AnalyzingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analisi in corso...")
                .font(.headline)
            
            Text("Ansel sta studiando la tua immagine")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ErrorView: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Errore nell'analisi")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onRetry) {
                Label("Riprova", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct ReadyToAnalyzeView: View {
    let image: UIImage
    let onAnalyze: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)
            
            Text("Pronto per l'analisi")
                .font(.headline)
            
            Text("Tocca il pulsante per ricevere la critica di Ansel Adams")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAnalyze) {
                Label("Analizza con Ansel", systemImage: "camera.aperture")
                    .font(.headline)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.gray, .black],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct EmptyAnalysisView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Nessuna analisi disponibile")
                .font(.headline)
            
            Text("Carica un'immagine per iniziare l'analisi")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    let coordinator = ZoneSystemCoordinator()
    
    let sampleAnalysis = ImageAnalysisResult(
        zoneDistribution: ZoneDistribution(percentages: [.zone5: 100]),
        dynamicRange: DynamicRangeAnalysis(minLuminance: 0, maxLuminance: 255),
        contrastAnalysis: ContrastAnalysis(globalContrast: 40, localContrast: 30, shadowDetail: 0.5, highlightDetail: 0.5),
        compositionAnalysis: CompositionAnalysis(
            sceneType: .landscape,
            ruleOfThirdsScore: 0.7,
            leadingLines: [],
            balanceScore: 0.8,
            focalPoint: nil,
            horizonLine: nil,
            symmetryScore: 0.5
        ),
        sceneType: .landscape,
        technicalScore: 75,
        artisticScore: 80,
        adamsCritique: AdamsCritique(
            overallComment: "Bel paesaggio",
            technicalComment: "Tecnicamente buono",
            artisticComment: "Buona composizione",
            zonePlacementAdvice: "Zone III sulle ombre",
            developmentAdvice: "N normale",
            printingAdvice: "Dodgi leggermente",
            filterSuggestion: nil
        ),
        suggestions: []
    )
    
    coordinator.currentAnalysis = sampleAnalysis
    
    return coordinator.dashboardView()
}
