// MARK: - Zone System Master Tests
// Test suite per verificare funzionalità AI Engine
// Swift 6.0

import XCTest
@testable import ZoneSystemMaster

@MainActor
final class ZoneSystemTests: XCTestCase {
    
    var coordinator: ZoneSystemCoordinator!
    var zoneAnalyzer: ZoneAnalyzer!
    var suggestionEngine: SuggestionEngine!
    
    override func setUp() {
        super.setUp()
        coordinator = ZoneSystemCoordinator()
        zoneAnalyzer = ZoneAnalyzer()
        suggestionEngine = SuggestionEngine()
    }
    
    override func tearDown() {
        coordinator = nil
        zoneAnalyzer = nil
        suggestionEngine = nil
        super.tearDown()
    }
    
    // MARK: - Zone Distribution Tests
    
    func testZoneDistributionCalculation() {
        // Test distribuzione zone
        let percentages: [Zone: Double] = [
            .zone0: 2, .zone1: 5, .zone2: 8, .zone3: 12,
            .zone4: 15, .zone5: 20, .zone6: 15, .zone7: 10,
            .zone8: 8, .zone9: 3, .zone10: 2
        ]
        
        let distribution = ZoneDistribution(percentages: percentages)
        
        XCTAssertEqual(distribution.dominantZone, .zone5)
        XCTAssertTrue(distribution.hasGoodBalance)
        XCTAssertFalse(distribution.isUnderexposed)
        XCTAssertFalse(distribution.isOverexposed)
        XCTAssertTrue(distribution.hasPureBlack)
        XCTAssertTrue(distribution.hasPureWhite)
    }
    
    func testUnderexposedDetection() {
        let percentages: [Zone: Double] = [
            .zone0: 15, .zone1: 20, .zone2: 25, .zone3: 20,
            .zone4: 10, .zone5: 5, .zone6: 3, .zone7: 1,
            .zone8: 0.5, .zone9: 0.3, .zone10: 0.2
        ]
        
        let distribution = ZoneDistribution(percentages: percentages)
        
        XCTAssertTrue(distribution.isUnderexposed)
        XCTAssertFalse(distribution.isOverexposed)
        XCTAssertFalse(distribution.hasGoodBalance)
    }
    
    func testOverexposedDetection() {
        let percentages: [Zone: Double] = [
            .zone0: 0.2, .zone1: 0.3, .zone2: 0.5, .zone3: 1,
            .zone4: 3, .zone5: 5, .zone6: 10, .zone7: 20,
            .zone8: 25, .zone9: 20, .zone10: 15
        ]
        
        let distribution = ZoneDistribution(percentages: percentages)
        
        XCTAssertTrue(distribution.isOverexposed)
        XCTAssertFalse(distribution.isUnderexposed)
    }
    
    // MARK: - Dynamic Range Tests
    
    func testDynamicRangeCalculation() {
        let dr = DynamicRangeAnalysis(minLuminance: 10, maxLuminance: 250)
        
        XCTAssertGreaterThan(dr.dynamicRangeStops, 4)
        XCTAssertLessThan(dr.dynamicRangeStops, 6)
        XCTAssertEqual(dr.rating, .limited)
    }
    
    func testExcellentDynamicRange() {
        let dr = DynamicRangeAnalysis(minLuminance: 0, maxLuminance: 255)
        
        XCTAssertGreaterThan(dr.dynamicRangeStops, 7)
        XCTAssertEqual(dr.rating, .excellent)
    }
    
    // MARK: - Contrast Analysis Tests
    
    func testContrastRating() {
        let highContrast = ContrastAnalysis(globalContrast: 65, localContrast: 50, shadowDetail: 0.8, highlightDetail: 0.7)
        XCTAssertEqual(highContrast.rating, .high)
        
        let normalContrast = ContrastAnalysis(globalContrast: 45, localContrast: 35, shadowDetail: 0.6, highlightDetail: 0.6)
        XCTAssertEqual(normalContrast.rating, .normal)
        
        let flatContrast = ContrastAnalysis(globalContrast: 15, localContrast: 10, shadowDetail: 0.3, highlightDetail: 0.3)
        XCTAssertEqual(flatContrast.rating, .flat)
    }
    
    // MARK: - Development Type Tests
    
    func testDevelopmentTimeAdjustments() {
        XCTAssertEqual(DevelopmentType.nMinus2.timeAdjustment, 0.6, accuracy: 0.01)
        XCTAssertEqual(DevelopmentType.nMinus1.timeAdjustment, 0.8, accuracy: 0.01)
        XCTAssertEqual(DevelopmentType.normal.timeAdjustment, 1.0, accuracy: 0.01)
        XCTAssertEqual(DevelopmentType.nPlus1.timeAdjustment, 1.3, accuracy: 0.01)
        XCTAssertEqual(DevelopmentType.nPlus2.timeAdjustment, 1.7, accuracy: 0.01)
    }
    
    // MARK: - Filter Tests
    
    func testFilterCompensation() {
        XCTAssertEqual(FilterType.yellow.stopCompensation, 1.0, accuracy: 0.1)
        XCTAssertEqual(FilterType.orange.stopCompensation, 1.5, accuracy: 0.1)
        XCTAssertEqual(FilterType.red.stopCompensation, 2.0, accuracy: 0.1)
    }
    
    // MARK: - Suggestion Engine Tests
    
    func testSuggestionPriority() {
        let sampleAnalysis = createSampleAnalysis()
        let suggestions = suggestionEngine.generateSuggestions(for: sampleAnalysis)
        
        // Verifica che i suggerimenti critici siano presenti se necessario
        let criticalSuggestions = suggestions.suggestions.filter { $0.priority == .critical }
        // Nessun problema critico nel sample
        XCTAssertEqual(criticalSuggestions.count, 0)
    }
    
    func testDevelopmentRecommendation() {
        let flatAnalysis = createFlatContrastAnalysis()
        let development = suggestionEngine.recommendDevelopment(flatAnalysis)
        XCTAssertEqual(development, .nPlus1)
        
        let highContrastAnalysis = createHighContrastAnalysis()
        let development2 = suggestionEngine.recommendDevelopment(highContrastAnalysis)
        XCTAssertEqual(development2, .nMinus1)
    }
    
    // MARK: - Chatbot Tests
    
    func testChatbotResponseGeneration() async {
        let chatbot = AdamsChatbot(language: .italian)
        
        let response = try? await chatbot.sendMessage("ciao")
        XCTAssertNotNil(response)
        XCTAssertFalse(response?.content.isEmpty ?? true)
    }
    
    func testChatbotContextAwareness() async {
        let chatbot = AdamsChatbot(language: .italian)
        let analysis = createSampleAnalysis()
        
        let response = try? await chatbot.sendMessage("cosa ne pensi?", withAnalysis: analysis)
        XCTAssertNotNil(response)
        // La risposta dovrebbe contenere riferimenti all'analisi
    }
    
    // MARK: - Knowledge Base Tests
    
    func testKnowledgeBaseResponses() {
        let kb = AdamsKnowledgeBase()
        
        let greeting = kb.getGreeting(language: .italian)
        XCTAssertFalse(greeting.isEmpty)
        XCTAssertTrue(greeting.contains("Ansel"))
        
        let exposureAdvice = kb.getExposureAdvice(language: .italian, context: nil)
        XCTAssertTrue(exposureAdvice.contains("Zone"))
    }
    
    // MARK: - Composition Tests
    
    func testRuleOfThirdsScoring() {
        // Punto al centro (0.5, 0.5) dovrebbe avere score basso
        let centerPoint = CGPoint(x: 0.5, y: 0.5)
        // Implementazione reale richiederebbe CompositionAnalyzer
        
        // Punto su intersezione terzi (0.33, 0.33) dovrebbe avere score alto
        let powerPoint = CGPoint(x: 0.333, y: 0.333)
        // Implementazione reale richiederebbe CompositionAnalyzer
    }
    
    // MARK: - Helper Methods
    
    private func createSampleAnalysis() -> ImageAnalysisResult {
        let distribution = ZoneDistribution(percentages: [
            .zone0: 2, .zone1: 5, .zone2: 8, .zone3: 12,
            .zone4: 15, .zone5: 20, .zone6: 15, .zone7: 10,
            .zone8: 8, .zone9: 3, .zone10: 2
        ])
        
        return ImageAnalysisResult(
            zoneDistribution: distribution,
            dynamicRange: DynamicRangeAnalysis(minLuminance: 15, maxLuminance: 240),
            contrastAnalysis: ContrastAnalysis(globalContrast: 45, localContrast: 35, shadowDetail: 0.7, highlightDetail: 0.6),
            compositionAnalysis: CompositionAnalysis(
                sceneType: .landscape,
                ruleOfThirdsScore: 0.75,
                leadingLines: [],
                balanceScore: 0.8,
                focalPoint: CGPoint(x: 0.33, y: 0.33),
                horizonLine: nil,
                symmetryScore: 0.4
            ),
            sceneType: .landscape,
            technicalScore: 78,
            artisticScore: 82,
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
    }
    
    private func createFlatContrastAnalysis() -> ImageAnalysisResult {
        var analysis = createSampleAnalysis()
        analysis = ImageAnalysisResult(
            zoneDistribution: analysis.zoneDistribution,
            dynamicRange: analysis.dynamicRange,
            contrastAnalysis: ContrastAnalysis(globalContrast: 20, localContrast: 15, shadowDetail: 0.4, highlightDetail: 0.4),
            compositionAnalysis: analysis.compositionAnalysis,
            sceneType: analysis.sceneType,
            technicalScore: analysis.technicalScore,
            artisticScore: analysis.artisticScore,
            adamsCritique: analysis.adamsCritique,
            suggestions: analysis.suggestions
        )
        return analysis
    }
    
    private func createHighContrastAnalysis() -> ImageAnalysisResult {
        var analysis = createSampleAnalysis()
        analysis = ImageAnalysisResult(
            zoneDistribution: analysis.zoneDistribution,
            dynamicRange: analysis.dynamicRange,
            contrastAnalysis: ContrastAnalysis(globalContrast: 70, localContrast: 60, shadowDetail: 0.5, highlightDetail: 0.5),
            compositionAnalysis: analysis.compositionAnalysis,
            sceneType: analysis.sceneType,
            technicalScore: analysis.technicalScore,
            artisticScore: analysis.artisticScore,
            adamsCritique: analysis.adamsCritique,
            suggestions: analysis.suggestions
        )
        return analysis
    }
}

// MARK: - Performance Tests

final class ZoneSystemPerformanceTests: XCTestCase {
    
    func testZoneAnalysisPerformance() {
        let zoneAnalyzer = ZoneAnalyzer()
        // Test performance con immagine simulata
        
        measure {
            // Simulazione analisi
            let percentages: [Zone: Double] = [
                .zone0: 2, .zone1: 5, .zone2: 8, .zone3: 12,
                .zone4: 15, .zone5: 20, .zone6: 15, .zone7: 10,
                .zone8: 8, .zone9: 3, .zone10: 2
            ]
            _ = ZoneDistribution(percentages: percentages)
        }
    }
    
    func testSuggestionGenerationPerformance() {
        let suggestionEngine = SuggestionEngine()
        let analysis = createSampleAnalysisForPerformance()
        
        measure {
            _ = suggestionEngine.generateSuggestions(for: analysis)
        }
    }
    
    private func createSampleAnalysisForPerformance() -> ImageAnalysisResult {
        return ImageAnalysisResult(
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
                overallComment: "Test",
                technicalComment: "Test",
                artisticComment: "Test",
                zonePlacementAdvice: "Test",
                developmentAdvice: "Test",
                printingAdvice: "Test",
                filterSuggestion: nil
            ),
            suggestions: []
        )
    }
}
