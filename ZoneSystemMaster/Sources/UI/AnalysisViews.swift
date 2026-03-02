// MARK: - Analysis Views
// Componenti UI SwiftUI per visualizzazione analisi
// Swift 6.0

import SwiftUI
import Charts

// MARK: - Zone Histogram View

public struct ZoneHistogramView: View {
    public let zoneDistribution: ZoneDistribution
    public var showColors: Bool = true
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distribuzione Zone")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Barre istogramma
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Zone.allCases, id: \.self) { zone in
                    ZoneBar(
                        zone: zone,
                        percentage: zoneDistribution.percentages[zone] ?? 0,
                        color: zoneColor(zone),
                        showColors: showColors
                    )
                }
            }
            .frame(height: 150)
            
            // Legenda
            HStack {
                ForEach([Zone.zone0, Zone.zone5, Zone.zone10], id: \.self) { zone in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(zoneColor(zone))
                            .frame(width: 8, height: 8)
                        Text(zone == .zone0 ? "Nero" : zone == .zone5 ? "Medio" : "Bianco")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func zoneColor(_ zone: Zone) -> Color {
        let gray = Double(zone.rgbValue) / 255.0
        return Color(white: gray)
    }
}

struct ZoneBar: View {
    let zone: Zone
    let percentage: Double
    let color: Color
    let showColors: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Percentuale
            Text("\(Int(percentage))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(-90))
                .frame(width: 20)
            
            // Barra
            RoundedRectangle(cornerRadius: 2)
                .fill(showColors ? color : Color.gray.opacity(0.3 + Double(zone.rawValue) * 0.07))
                .frame(width: 24)
                .frame(height: max(4, CGFloat(percentage) * 1.2))
            
            // Label zona
            Text("\(zone.rawValue)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Dynamic Range View

public struct DynamicRangeView: View {
    public let dynamicRange: DynamicRangeAnalysis
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gamma Dinamica")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Indicatore stops
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(dynamicRange.dynamicRangeStops, specifier: "%.1f")")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(rangeColor)
                    
                    Text("stops")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Dettagli
                VStack(alignment: .trailing, spacing: 8) {
                    Label(dynamicRange.rating.rawValue, systemImage: "waveform.path")
                        .font(.subheadline)
                        .foregroundColor(rangeColor)
                    
                    Text("Rapporto: 1:\(Int(dynamicRange.contrastRatio))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Range: \(Int(dynamicRange.minLuminance))-\(Int(dynamicRange.maxLuminance))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Barra visuale
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Sfondo gradiente
                    LinearGradient(
                        colors: [.black, .gray, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 20)
                    .cornerRadius(4)
                    
                    // Indicatori min/max
                    let minPos = CGFloat(dynamicRange.minLuminance / 255.0) * geometry.size.width
                    let maxPos = CGFloat(dynamicRange.maxLuminance / 255.0) * geometry.size.width
                    
                    // Range attivo
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: maxPos - minPos, height: 20)
                        .offset(x: minPos)
                    
                    // Marker
                    Triangle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: minPos - 5, y: -12)
                    
                    Triangle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .rotationEffect(.degrees(180))
                        .offset(x: maxPos - 5, y: 22)
                }
            }
            .frame(height: 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var rangeColor: Color {
        switch dynamicRange.rating {
        case .excellent: return .green
        case .good: return .blue
        case .limited: return .orange
        case .compressed: return .red
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Contrast Analysis View

public struct ContrastAnalysisView: View {
    public let contrastAnalysis: ContrastAnalysis
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analisi Contrasto")
                .font(.headline)
            
            // Rating principale
            HStack {
                Image(systemName: "circle.righthalf.filled")
                    .font(.title2)
                    .foregroundColor(contrastColor)
                
                VStack(alignment: .leading) {
                    Text(contrastAnalysis.rating.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(contrastAnalysis.rating.adamsComment)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Divider()
            
            // Metriche dettagliate
            HStack(spacing: 20) {
                MetricView(
                    title: "Globale",
                    value: "\(Int(contrastAnalysis.globalContrast))",
                    icon: "slider.horizontal.3"
                )
                
                MetricView(
                    title: "Locale",
                    value: "\(Int(contrastAnalysis.localContrast))",
                    icon: "square.grid.2x2"
                )
            }
            
            // Dettaglio ombre e luci
            HStack(spacing: 20) {
                DetailMeterView(
                    title: "Dettaglio Ombre",
                    value: contrastAnalysis.shadowDetail,
                    color: .blue
                )
                
                DetailMeterView(
                    title: "Dettaglio Luci",
                    value: contrastAnalysis.highlightDetail,
                    color: .yellow
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var contrastColor: Color {
        switch contrastAnalysis.rating {
        case .high: return .green
        case .normal: return .blue
        case .low: return .orange
        case .flat: return .red
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }
        }
    }
}

struct DetailMeterView: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(value * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Adams Critique View

public struct AdamsCritiqueView: View {
    public let critique: AdamsCritique
    @State private var expandedSection: ExpandedSection? = nil
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "quote.opening")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Cosa dice Ansel")
                    .font(.headline)
                
                Spacer()
            }
            
            // Commento generale
            Text(critique.overallComment)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            
            // Sezioni espandibili
            VStack(spacing: 8) {
                CritiqueSection(
                    title: "Analisi Tecnica",
                    content: critique.technicalComment,
                    icon: "gearshape.2",
                    isExpanded: expandedSection == .technical
                ) {
                    withAnimation {
                        expandedSection = expandedSection == .technical ? nil : .technical
                    }
                }
                
                CritiqueSection(
                    title: "Analisi Artistica",
                    content: critique.artisticComment,
                    icon: "paintbrush",
                    isExpanded: expandedSection == .artistic
                ) {
                    withAnimation {
                        expandedSection = expandedSection == .artistic ? nil : .artistic
                    }
                }
                
                CritiqueSection(
                    title: "Posizionamento Zone",
                    content: critique.zonePlacementAdvice,
                    icon: "ruler",
                    isExpanded: expandedSection == .zonePlacement
                ) {
                    withAnimation {
                        expandedSection = expandedSection == .zonePlacement ? nil : .zonePlacement
                    }
                }
                
                CritiqueSection(
                    title: "Sviluppo",
                    content: critique.developmentAdvice,
                    icon: "timer",
                    isExpanded: expandedSection == .development
                ) {
                    withAnimation {
                        expandedSection = expandedSection == .development ? nil : .development
                    }
                }
                
                CritiqueSection(
                    title: "Stampa",
                    content: critique.printingAdvice,
                    icon: "printer",
                    isExpanded: expandedSection == .printing
                ) {
                    withAnimation {
                        expandedSection = expandedSection == .printing ? nil : .printing
                    }
                }
                
                if let filter = critique.filterSuggestion {
                    CritiqueSection(
                        title: "Filtro Consigliato",
                        content: filter,
                        icon: "camera.filters",
                        isExpanded: expandedSection == .filter
                    ) {
                        withAnimation {
                            expandedSection = expandedSection == .filter ? nil : .filter
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private enum ExpandedSection {
        case technical, artistic, zonePlacement, development, printing, filter
    }
}

struct CritiqueSection: View {
    let title: String
    let content: String
    let icon: String
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .padding(.leading, 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Suggestions List View

public struct SuggestionsListView: View {
    public let suggestions: [TechnicalSuggestion]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggerimenti")
                .font(.headline)
            
            if suggestions.isEmpty {
                Text("Nessun suggerimento disponibile")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct SuggestionCard: View {
    let suggestion: TechnicalSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: suggestion.priority.icon)
                    .foregroundColor(priorityColor)
                
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(suggestion.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.2))
                    .foregroundColor(categoryColor)
                    .cornerRadius(4)
            }
            
            Text(suggestion.description)
                .font(.caption)
                .foregroundColor(.primary)
            
            Text("\"\(suggestion.adamsQuote)\"")
                .font(.caption2)
                .italic()
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(priorityColor.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(priorityColor.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(8)
    }
    
    private var priorityColor: Color {
        switch suggestion.priority {
        case .critical: return .red
        case .important: return .orange
        case .suggestion: return .blue
        }
    }
    
    private var categoryColor: Color {
        switch suggestion.category {
        case .exposure: return .purple
        case .development: return .blue
        case .printing: return .green
        case .filters: return .orange
        case .composition: return .pink
        case .lighting: return .yellow
        }
    }
}

// MARK: - Score View

public struct ScoreView: View {
    public let technicalScore: Double
    public let artisticScore: Double
    
    public var body: some View {
        HStack(spacing: 20) {
            ScoreRing(
                score: technicalScore,
                title: "Tecnico",
                color: .blue
            )
            
            ScoreRing(
                score: artisticScore,
                title: "Artistico",
                color: .purple
            )
            
            ScoreRing(
                score: (technicalScore + artisticScore) / 2,
                title: "Totale",
                color: .green
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ScoreRing: View {
    let score: Double
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(score))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Main Analysis Dashboard

public struct AnalysisDashboard: View {
    public let analysis: ImageAnalysisResult
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Punteggi
                ScoreView(
                    technicalScore: analysis.technicalScore,
                    artisticScore: analysis.artisticScore
                )
                
                // Info scena
                SceneInfoView(sceneType: analysis.sceneType)
                
                // Istogramma zone
                ZoneHistogramView(zoneDistribution: analysis.zoneDistribution)
                
                // Gamma dinamica
                DynamicRangeView(dynamicRange: analysis.dynamicRange)
                
                // Analisi contrasto
                ContrastAnalysisView(contrastAnalysis: analysis.contrastAnalysis)
                
                // Critica Adams
                AdamsCritiqueView(critique: analysis.adamsCritique)
                
                // Suggerimenti
                SuggestionsListView(suggestions: analysis.suggestions)
            }
            .padding()
        }
    }
}

struct SceneInfoView: View {
    let sceneType: SceneType
    
    var body: some View {
        HStack {
            Image(systemName: sceneIcon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text("Tipo Scena")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(sceneType.rawValue)
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var sceneIcon: String {
        switch sceneType {
        case .landscape: return "mountain.2"
        case .portrait: return "person.crop.rectangle"
        case .street: return "building.2"
        case .xpan: return "panorama"
        case .architecture: return "building.columns"
        case .macro: return "leaf"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Preview Provider

#Preview {
    let sampleDistribution = ZoneDistribution(
        percentages: [
            .zone0: 2, .zone1: 5, .zone2: 8, .zone3: 12,
            .zone4: 15, .zone5: 20, .zone6: 15, .zone7: 10,
            .zone8: 8, .zone9: 3, .zone10: 2
        ]
    )
    
    let sampleAnalysis = ImageAnalysisResult(
        zoneDistribution: sampleDistribution,
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
            overallComment: "Un bellissimo paesaggio con buona gamma dinamica.",
            technicalComment: "Tecnicamente solido con buon dettaglio.",
            artisticComment: "Composizione ben bilanciata.",
            zonePlacementAdvice: "Posiziona Zone III sulle ombre.",
            developmentAdvice: "Sviluppo N standard.",
            printingAdvice: "Dodgi leggermente le ombre.",
            filterSuggestion: "Filtro arancio #16"
        ),
        suggestions: [
            TechnicalSuggestion(
                category: .exposure,
                priority: .important,
                title: "Esposizione corretta",
                description: "L'esposizione è ben bilanciata.",
                adamsQuote: "La luce è tutto."
            )
        ]
    )
    
    AnalysisDashboard(analysis: sampleAnalysis)
}
