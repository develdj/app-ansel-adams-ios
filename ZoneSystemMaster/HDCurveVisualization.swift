// MARK: - H&D Curve Visualization
// Visualizzazione curve sensitometriche con Swift Charts

import Foundation
import SwiftUI
import Charts

// MARK: - H&D Curve Chart View

/// Vista grafico curva H&D per singola pellicola
public struct HDCurveChartView: View {
    public let film: FilmType
    public let development: DevelopmentType
    public let temperature: Double
    public let showZones: Bool
    
    @State private var selectedPoint: HDCurvePoint?
    
    public init(
        film: FilmType,
        development: DevelopmentType = .nNormal,
        temperature: Double = 20.0,
        showZones: Bool = true
    ) {
        self.film = film
        self.development = development
        self.temperature = temperature
        self.showZones = showZones
    }
    
    private var curveData: [HDCurvePoint] {
        EmulsionPhysicsEngine.shared.generateHDCurve(
            film: film,
            development: development,
            temperature: temperature
        )
    }
    
    private var gamma: Double {
        EmulsionPhysicsEngine.shared.calculateGamma(
            film: film,
            development: development,
            temperature: temperature
        )
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(film.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(development.rawValue) | \(String(format: "%.0f", temperature))°C")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Chart
            Chart(curveData) { point in
                // Curva principale
                LineMark(
                    x: .value("logH", point.logH),
                    y: .value("Density", point.density)
                )
                .foregroundStyle(curveColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                // Punti zona
                if showZones, let zone = point.zone {
                    PointMark(
                        x: .value("logH", point.logH),
                        y: .value("Density", point.density)
                    )
                    .foregroundStyle(zoneColor(zone))
                    .symbolSize(50)
                }
                
                // Area selezionata
                if let selected = selectedPoint,
                   abs(selected.logH - point.logH) < 0.05 {
                    RuleMark(x: .value("logH", point.logH))
                        .foregroundStyle(.red.opacity(0.3))
                }
            }
            .chartXAxisLabel("log₁₀ H (Exposure)")
            .chartYAxisLabel("Density (D)")
            .chartXScale(domain: 0...3)
            .chartYScale(domain: 0...2)
            .frame(height: 250)
            .chartBackground { chartProxy in
                // Zone markers
                if showZones {
                    GeometryReader { geometry in
                        ForEach(Zone.allCases, id: \.rawValue) { zone in
                            let logH = EmulsionPhysicsEngine.shared.zoneToLogH(zone)
                            if let xPosition = chartProxy.position(forX: logH) {
                                Rectangle()
                                    .fill(zoneColor(zone).opacity(0.1))
                                    .frame(width: geometry.size.width / 11)
                                    .position(x: xPosition, y: geometry.size.height / 2)
                                
                                Text("Z\(zone.rawValue)")
                                    .font(.system(size: 8))
                                    .foregroundColor(zoneColor(zone))
                                    .position(x: xPosition, y: geometry.size.height - 10)
                            }
                        }
                    }
                }
            }
            
            // Info footer
            HStack {
                Text("γ = \(String(format: "%.2f", gamma))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let point = selectedPoint {
                    Text("D: \(String(format: "%.2f", point.density)) | logH: \(String(format: "%.2f", point.logH))")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var curveColor: Color {
        switch development {
        case .nMinus2, .nMinus1:
            return .blue
        case .nNormal:
            return .green
        case .nPlus1, .nPlus2:
            return .red
        }
    }
    
    private func zoneColor(_ zone: Zone) -> Color {
        let colors: [Color] = [
            .black, .gray, .gray.opacity(0.7),
            .blue.opacity(0.6), .blue.opacity(0.4),
            .gray.opacity(0.5),
            .yellow.opacity(0.4), .yellow.opacity(0.6),
            .orange.opacity(0.7), .orange, .white
        ]
        return colors[zone.rawValue]
    }
}

// MARK: - Multi-Film Comparison Chart

/// Vista confronto multiple pellicole
public struct FilmComparisonChartView: View {
    public let films: [FilmType]
    public let development: DevelopmentType
    
    public init(
        films: [FilmType] = [.ilfordHP5Plus, .kodakTriX400, .kodakTMax400],
        development: DevelopmentType = .nNormal
    ) {
        self.films = films
        self.development = development
    }
    
    private var curvesData: [(film: FilmType, points: [HDCurvePoint])] {
        films.map { film in
            let points = EmulsionPhysicsEngine.shared.generateHDCurve(
                film: film,
                development: development
            )
            return (film, points)
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Film Comparison - \(development.rawValue) Development")
                .font(.headline)
            
            Chart {
                ForEach(curvesData, id: \.film.rawValue) { data in
                    ForEach(data.points, id: \.logH) { point in
                        LineMark(
                            x: .value("logH", point.logH),
                            y: .value("Density", point.density)
                        )
                        .foregroundStyle(by: .value("Film", data.film.rawValue))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartXAxisLabel("log₁₀ H (Exposure)")
            .chartYAxisLabel("Density (D)")
            .chartXScale(domain: 0...3)
            .chartYScale(domain: 0...2)
            .frame(height: 300)
            .chartLegend(position: .bottom, alignment: .center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Development Family Chart

/// Vista famiglia di curve per diversi sviluppi
public struct DevelopmentFamilyChartView: View {
    public let film: FilmType
    
    public init(film: FilmType = .ilfordHP5Plus) {
        self.film = film
    }
    
    private var curvesData: [(development: DevelopmentType, points: [HDCurvePoint])] {
        DevelopmentType.allCases.map { dev in
            let points = EmulsionPhysicsEngine.shared.generateHDCurve(
                film: film,
                development: dev
            )
            return (dev, points)
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(film.rawValue) - Development Family")
                .font(.headline)
            
            Chart {
                ForEach(curvesData, id: \.development.rawValue) { data in
                    ForEach(data.points, id: \.logH) { point in
                        LineMark(
                            x: .value("logH", point.logH),
                            y: .value("Density", point.density)
                        )
                        .foregroundStyle(by: .value("Dev", data.development.rawValue))
                        .lineStyle(StrokeStyle(
                            lineWidth: data.development == .nNormal ? 3 : 1.5
                        ))
                    }
                }
            }
            .chartXAxisLabel("log₁₀ H (Exposure)")
            .chartYAxisLabel("Density (D)")
            .chartXScale(domain: 0...3)
            .chartYScale(domain: 0...2)
            .frame(height: 300)
            .chartLegend(position: .bottom, alignment: .center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Zone Scale Visualization

/// Vista scala zone visuale
public struct ZoneScaleView: View {
    public let width: CGFloat
    public let height: CGFloat
    
    public init(width: CGFloat = 400, height: CGFloat = 60) {
        self.width = width
        self.height = height
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Zone.allCases, id: \.rawValue) { zone in
                Rectangle()
                    .fill(zoneColor(zone))
                    .frame(width: width / 11, height: height)
                    .overlay(
                        Text("\(zone.rawValue)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(zone.rawValue < 5 ? .white : .black)
                    )
            }
        }
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray, lineWidth: 1)
        )
    }
    
    private func zoneColor(_ zone: Zone) -> Color {
        let grayValue = Double(zone.rawValue) / 10.0
        return Color(white: grayValue)
    }
}

// MARK: - Zone Distribution Histogram

/// Istogramma distribuzione zone
public struct ZoneHistogramView: View {
    public let zoneMap: ZoneMap
    
    public init(zoneMap: ZoneMap) {
        self.zoneMap = zoneMap
    }
    
    private var histogramData: [(zone: Zone, count: Int, percentage: Double)] {
        let total = zoneMap.zones.count
        return Zone.allCases.map { zone in
            let count = zoneMap.histogram[zone] ?? 0
            let percentage = Double(count) / Double(total) * 100
            return (zone, count, percentage)
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zone Distribution")
                .font(.headline)
            
            Chart(histogramData, id: \.zone.rawValue) { item in
                BarMark(
                    x: .value("Zone", "Z\(item.zone.rawValue)"),
                    y: .value("Percentage", item.percentage)
                )
                .foregroundStyle(zoneColor(item.zone))
                
                RuleMark(y: .value("Average", 9.1)) // 100/11
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            }
            .chartYAxisLabel("% Pixels")
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func zoneColor(_ zone: Zone) -> Color {
        let grayValue = Double(zone.rawValue) / 10.0
        return Color(white: grayValue)
    }
}

// MARK: - Paper Response Curve Chart

/// Vista curva risposta carta
public struct PaperCurveChartView: View {
    public let grades: [PaperGrade]
    
    public init(grades: [PaperGrade] = [.grade1, .grade2, .grade3, .grade4]) {
        self.grades = grades
    }
    
    private var curvesData: [(grade: PaperGrade, points: [PaperCurvePoint])] {
        grades.map { grade in
            let points = EmulsionPhysicsEngine.shared.generatePaperCurve(paperGrade: grade)
            return (grade, points)
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paper Response Curves")
                .font(.headline)
            
            Chart {
                ForEach(curvesData, id: \.grade.rawValue) { data in
                    ForEach(data.points, id: \.logE) { point in
                        LineMark(
                            x: .value("logE", point.logE),
                            y: .value("Density", point.density)
                        )
                        .foregroundStyle(by: .value("Grade", "Grade \(data.grade.rawValue)"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartXAxisLabel("log₁₀ E (Exposure)")
            .chartYAxisLabel("Reflection Density")
            .chartXScale(domain: 0...2.5)
            .chartYScale(domain: 0...2.2)
            .frame(height: 250)
            .chartLegend(position: .bottom, alignment: .center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Combined Dashboard View

/// Dashboard completo con tutte le visualizzazioni
public struct ZoneSystemDashboardView: View {
    @State private var selectedFilm: FilmType = .ilfordHP5Plus
    @State private var selectedDevelopment: DevelopmentType = .nNormal
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Selezione
                HStack {
                    Picker("Film", selection: $selectedFilm) {
                        ForEach(FilmType.allCases, id: \.self) { film in
                            Text(film.rawValue).tag(film)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Development", selection: $selectedDevelopment) {
                        ForEach(DevelopmentType.allCases, id: \.self) { dev in
                            Text(dev.rawValue).tag(dev)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Scala zone
                ZoneScaleView()
                    .padding(.horizontal)
                
                // Curva H&D
                HDCurveChartView(
                    film: selectedFilm,
                    development: selectedDevelopment
                )
                .padding(.horizontal)
                
                // Confronto pellicole
                FilmComparisonChartView(development: selectedDevelopment)
                    .padding(.horizontal)
                
                // Famiglia sviluppo
                DevelopmentFamilyChartView(film: selectedFilm)
                    .padding(.horizontal)
                
                // Curve carta
                PaperCurveChartView()
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Preview

#Preview("H&D Curve") {
    HDCurveChartView(film: .ilfordHP5Plus, development: .nNormal)
        .padding()
}

#Preview("Film Comparison") {
    FilmComparisonChartView()
        .padding()
}

#Preview("Development Family") {
    DevelopmentFamilyChartView(film: .kodakTriX400)
        .padding()
}

#Preview("Zone Scale") {
    ZoneScaleView()
        .padding()
}

#Preview("Paper Curves") {
    PaperCurveChartView()
        .padding()
}

#Preview("Dashboard") {
    ZoneSystemDashboardView()
}
