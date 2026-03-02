// MARK: - Zone System Master
// Scientific Exposure Engine per Sistema Zonale di Ansel Adams
// Swift 6.0 - Precisione Double
//
// Riferimenti teorici:
// - "The Negative" - Ansel Adams
// - "The Print" - Ansel Adams
// - "Examples: The Making of 40 Photographs" - Ansel Adams
//
// Formule implementate:
// - EV = log₂(N² / t) - log₂(S / 100)
// - EV = log₂(L × S / K)
// - Zone = round(log₂(L / L_mid)) + 5
// - H&D: D = Dmin + (Dmax - Dmin) × (1 - exp(-γ × logH))
// - HFOV = 2 × arctan(sensor_width / (2 × focal_length))

import Foundation
import SwiftUI

// MARK: - Module Export

/// Punto di accesso principale al modulo Zone System Master
public enum ZoneSystemMaster {
    
    /// Versione del modulo
    public static let version = "1.0.0"
    
    /// Autore
    public static let author = "Scientific Photography Engine"
    
    /// Riferimenti teorici
    public static let references = [
        "Ansel Adams - The Negative",
        "Ansel Adams - The Print",
        "Ansel Adams - Examples: The Making of 40 Photographs",
        "Hurter & Driffield - Photographic Researches (1890)"
    ]
    
    // MARK: - Engine Access
    
    /// Accesso all'ExposureEngine
    public static var exposure: ExposureEngine { ExposureEngine.shared }
    
    /// Accesso al ZoneMappingEngine
    public static var zoneMapping: ZoneMappingEngine { ZoneMappingEngine.shared }
    
    /// Accesso all'EmulsionPhysicsEngine
    public static var emulsion: EmulsionPhysicsEngine { EmulsionPhysicsEngine.shared }
    
    /// Accesso al PanoramicCompositionEngine
    public static var panoramic: PanoramicCompositionEngine { PanoramicCompositionEngine.shared }
    
    // MARK: - Quick Calculations
    
    /// Calcola EV rapidamente
    public static func calculateEV(aperture: Double, shutterSpeed: Double, iso: Double) -> EV {
        return exposure.calculateEV(aperture: aperture, shutterSpeed: shutterSpeed, iso: iso)
    }
    
    /// Calcola impostazioni per Zone III
    public static func calculateZoneIIIExposure(
        shadowLuminance: Double,
        midGrayLuminance: Double,
        iso: Double
    ) -> ExposureSettings {
        return exposure.calculateZoneIIExposure(
            shadowLuminance: shadowLuminance,
            midGrayLuminance: midGrayLuminance,
            iso: iso
        )
    }
    
    /// Genera curva H&D
    public static func generateHDCurve(
        film: FilmType,
        development: DevelopmentType
    ) -> [HDCurvePoint] {
        return emulsion.generateHDCurve(film: film, development: development)
    }
    
    /// Analizza sensitività pellicola
    public static func analyzeFilm(_ film: FilmType) -> SensitivityAnalysis {
        return emulsion.analyzeSensitivity(film: film)
    }
    
    // MARK: - Constants
    
    /// Costanti fisiche fotografia
    public enum Constants {
        /// Costante calibrazione esposimetro (K)
        public static let calibrationK: Double = 12.5
        
        /// Costante calibrazione luminanza (C)
        public static let calibrationC: Double = 320
        
        /// Reflectance grigio medio
        public static let midGrayReflectance: Double = 0.18
        
        /// Step logH per stop (log₂)
        public static let logHPerStop: Double = 0.30103
        
        /// Temperatura riferimento sviluppo
        public static let referenceTemperature: Double = 20.0
        
        /// Circle of confusion standard 35mm
        public static let coc35mm: Double = 0.03
        
        /// Gamma standard pellicola
        public static let standardGamma: Double = 0.65
    }
    
    // MARK: - Utility Functions
    
    /// Converte stops in fattore lineare
    public static func stopsToFactor(_ stops: Double) -> Double {
        return pow(2, stops)
    }
    
    /// Converte fattore lineare in stops
    public static func factorToStops(_ factor: Double) -> Double {
        return log2(factor)
    }
    
    /// Converte EV in luminanza
    public static func evToLuminance(_ ev: EV, iso: Double) -> Double {
        return exposure.calculateLuminance(fromEV: ev, iso: iso)
    }
    
    /// Converte luminanza in EV
    public static func luminanceToEV(_ luminance: Double, iso: Double) -> EV {
        return exposure.calculateEV(fromLuminance: luminance, iso: iso)
    }
    
    // MARK: - Validation
    
    /// Verifica coerenza calcoli
    public static func validateCalculations() -> Bool {
        // Test EV ↔ Zone
        let midGrayEV = EV(10)
        for zone in Zone.allCases {
            let zoneEV = EV(midGrayEV.value + Double(zone.rawValue - 5))
            let calculatedZone = exposure.evToZone(zoneEV, midGrayEV: midGrayEV)
            if calculatedZone != zone {
                return false
            }
        }
        
        // Test reciprocità
        let ev = EV(10)
        let combos = ev.toApertureShutterCombo(atISO: 100)
        for combo in combos {
            let calculatedEV = exposure.calculateEV(
                aperture: combo.aperture,
                shutterSpeed: combo.shutterSpeed,
                iso: 100
            )
            if abs(calculatedEV.value - ev.value) > 0.1 {
                return false
            }
        }
        
        return true
    }
}

// MARK: - SwiftUI Integration

/// View principale per integrazione SwiftUI
public struct ZoneSystemMasterView: View {
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard
            ZoneSystemDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)
            
            // Exposure Calculator
            ExposureCalculatorView()
                .tabItem {
                    Label("Exposure", systemImage: "camera.aperture")
                }
                .tag(1)
            
            // Zone Mapper
            ZoneMapperView()
                .tabItem {
                    Label("Zones", systemImage: "square.grid.2x2")
                }
                .tag(2)
            
            // Film Database
            FilmDatabaseView()
                .tabItem {
                    Label("Films", systemImage: "film")
                }
                .tag(3)
            
            // Panoramic
            PanoramicToolsView()
                .tabItem {
                    Label("Panoramic", systemImage: "panorama")
                }
                .tag(4)
        }
    }
}

// MARK: - Sub-Views

/// Calcolatore esposizione
public struct ExposureCalculatorView: View {
    @State private var aperture: Double = 8.0
    @State private var shutterSpeed: Double = 1.0/125.0
    @State private var iso: Double = 100
    @State private var luminance: Double = 1000
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Camera Settings")) {
                    HStack {
                        Text("Aperture")
                        Spacer()
                        Text("f/\(String(format: "%.1f", aperture))")
                    }
                    Slider(value: $aperture, in: 1.4...32, step: 0.1)
                    
                    HStack {
                        Text("Shutter Speed")
                        Spacer()
                        Text(shutterSpeed >= 1 
                            ? "\(String(format: "%.0f", shutterSpeed))\""
                            : "1/\(Int(round(1.0 / shutterSpeed)))"
                        )
                    }
                    Slider(value: $shutterSpeed, in: 1.0/4000.0...30.0)
                    
                    HStack {
                        Text("ISO")
                        Spacer()
                        Text("\(Int(iso))")
                    }
                    Slider(value: $iso, in: 25...6400, step: 25)
                }
                
                Section(header: Text("Results")) {
                    let ev = ZoneSystemMaster.calculateEV(
                        aperture: aperture,
                        shutterSpeed: shutterSpeed,
                        iso: iso
                    )
                    HStack {
                        Text("Exposure Value")
                        Spacer()
                        Text("EV \(String(format: "%.1f", ev.value))")
                            .fontWeight(.bold)
                    }
                    
                    let sceneEV = ZoneSystemMaster.exposure.calculateEV(
                        fromLuminance: luminance,
                        iso: iso
                    )
                    HStack {
                        Text("Scene Luminance")
                        Spacer()
                        Text("\(Int(luminance)) cd/m²")
                    }
                    Slider(value: $luminance, in: 1...50000, step: 100)
                    
                    HStack {
                        Text("Scene EV")
                        Spacer()
                        Text("EV \(String(format: "%.1f", sceneEV.value))")
                    }
                    
                    let compensation = sceneEV.value - ev.value
                    HStack {
                        Text("Compensation Needed")
                        Spacer()
                        Text("\(compensation > 0 ? "+" : "")\(String(format: "%.1f", compensation)) EV")
                            .foregroundColor(compensation > 0 ? .red : (compensation < 0 ? .blue : .green))
                    }
                }
            }
            .navigationTitle("Exposure Calculator")
        }
    }
}

/// Mapper zone
public struct ZoneMapperView: View {
    @State private var selectedZone: Zone = .zoneV
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Scala zone
                ZoneScaleView(width: 350, height: 80)
                
                // Selettore zona
                Picker("Zone", selection: $selectedZone) {
                    ForEach(Zone.allCases, id: \.rawValue) { zone in
                        Text("Zone \(zone.rawValue)").tag(zone)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                
                // Info zona
                VStack(alignment: .leading, spacing: 12) {
                    Text(selectedZone.description)
                        .font(.headline)
                    
                    HStack {
                        Text("Reflectance:")
                        Spacer()
                        Text("\(String(format: "%.1f", selectedZone.reflectance))%")
                    }
                    
                    HStack {
                        Text("Target Density:")
                        Spacer()
                        Text("\(String(format: "%.2f", selectedZone.densityTarget))")
                    }
                    
                    // Pixel value preview
                    let pixelValue = ZoneMappingEngine.shared.mapZoneToPixel(selectedZone)
                    HStack {
                        Text("Pixel Value:")
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: pixelValue))
                            .frame(width: 40, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Zone Mapper")
        }
    }
}

/// Database pellicole
public struct FilmDatabaseView: View {
    @State private var selectedFilm: FilmType = .ilfordHP5Plus
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Film")) {
                    Picker("Film", selection: $selectedFilm) {
                        ForEach(FilmType.allCases, id: \.self) { film in
                            Text(film.rawValue).tag(film)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Film Characteristics")) {
                    let analysis = ZoneSystemMaster.analyzeFilm(selectedFilm)
                    
                    HStack {
                        Text("Nominal ISO")
                        Spacer()
                        Text("\(selectedFilm.nominalISO)")
                    }
                    
                    HStack {
                        Text("Effective ISO")
                        Spacer()
                        Text("\(Int(analysis.effectiveISO))")
                    }
                    
                    HStack {
                        Text("Gamma (N)")
                        Spacer()
                        Text("\(String(format: "%.2f", analysis.gamma))")
                    }
                    
                    HStack {
                        Text("Dynamic Range")
                        Spacer()
                        Text("\(String(format: "%.1f", analysis.dynamicRangeStops)) stops")
                    }
                    
                    HStack {
                        Text("Dmin")
                        Spacer()
                        Text("\(String(format: "%.2f", analysis.dMin))")
                    }
                    
                    HStack {
                        Text("Dmax")
                        Spacer()
                        Text("\(String(format: "%.2f", analysis.dMax))")
                    }
                }
                
                Section(header: Text("Development Times (D-76 1+1, 20°C)")) {
                    ForEach(DevelopmentType.allCases, id: \.self) { dev in
                        let time = ZoneSystemMaster.emulsion.calculateDevelopmentTime(
                            film: selectedFilm,
                            development: dev
                        )
                        HStack {
                            Text(dev.rawValue)
                            Spacer()
                            Text("\(String(format: "%.1f", time)) min")
                        }
                    }
                }
                
                Section(header: Text("Recommended EI")) {
                    ForEach(selectedFilm.recommendedEI, id: \.self) { ei in
                        Text("\(ei)")
                    }
                }
            }
            .navigationTitle("Film Database")
        }
    }
}

/// Strumenti panoramici
public struct PanoramicToolsView: View {
    @State private var focalLength: Double = 45.0
    @State private var aperture: Double = 8.0
    @State private var focusDistance: Double = 5000.0
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("X-Pan Settings")) {
                    HStack {
                        Text("Focal Length")
                        Spacer()
                        Text("\(Int(focalLength))mm")
                    }
                    Slider(value: $focalLength, in: 30...90, step: 1)
                    
                    HStack {
                        Text("Aperture")
                        Spacer()
                        Text("f/\(Int(aperture))")
                    }
                    Slider(value: $aperture, in: 2.8...22, step: 0.5)
                    
                    HStack {
                        Text("Focus Distance")
                        Spacer()
                        Text("\(String(format: "%.1f", focusDistance / 1000))m")
                    }
                    Slider(value: $focusDistance, in: 1000...20000, step: 500)
                }
                
                Section(header: Text("Field of View")) {
                    let hfov = ZoneSystemMaster.panoramic.calculateXPanHFOV(focalLength: focalLength)
                    let vfov = ZoneSystemMaster.panoramic.calculateXPanVFOV(focalLength: focalLength)
                    let equiv = ZoneSystemMaster.panoramic.calculateXPanEquivalent(focalLength: focalLength)
                    
                    HStack {
                        Text("Horizontal FOV")
                        Spacer()
                        Text("\(String(format: "%.1f", hfov))°")
                    }
                    
                    HStack {
                        Text("Vertical FOV")
                        Spacer()
                        Text("\(String(format: "%.1f", vfov))°")
                    }
                    
                    HStack {
                        Text("35mm Equivalent")
                        Spacer()
                        Text("\(Int(equiv))mm")
                    }
                }
                
                Section(header: Text("Depth of Field")) {
                    let dof = ZoneSystemMaster.panoramic.calculateDepthOfField(
                        focalLength: focalLength,
                        aperture: aperture,
                        focusDistance: focusDistance
                    )
                    
                    HStack {
                        Text("Near Limit")
                        Spacer()
                        Text("\(String(format: "%.2f", dof.nearLimit))m")
                    }
                    
                    HStack {
                        Text("Far Limit")
                        Spacer()
                        Text(dof.farLimit == .infinity ? "∞" : "\(String(format: "%.2f", dof.farLimit))m")
                    }
                    
                    HStack {
                        Text("Hyperfocal")
                        Spacer()
                        Text("\(String(format: "%.2f", dof.hyperfocalDistance))m")
                    }
                }
                
                Section(header: Text("Composition Tips")) {
                    let tips = ZoneSystemMaster.panoramic.getXPanCompositionTips(sceneType: .landscape)
                    ForEach(tips, id: \.self) { tip in
                        Text("• \(tip)")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Panoramic Tools")
        }
    }
}

// MARK: - Preview

#Preview("Zone System Master") {
    ZoneSystemMasterView()
}
