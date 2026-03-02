// MARK: - Zone System Master - Examples
// Esempi pratici di utilizzo degli engine

import Foundation

// MARK: - Example 1: Basic Exposure Calculation

func exampleBasicExposure() {
    print("\n" + "=" * 60)
    print("EXAMPLE 1: Basic Exposure Calculation")
    print("=" * 60)
    
    let exposureEngine = ExposureEngine.shared
    
    // Scenario: Giornata soleggiata, ISO 100
    // Luminanza misurata: 8000 cd/m²
    let sceneLuminance = 8000.0
    let iso = 100.0
    
    // Calcola EV scena
    let sceneEV = exposureEngine.calculateEV(fromLuminance: sceneLuminance, iso: iso)
    print("Scene EV: \(sceneEV)")
    
    // Genera combinazioni apertura/tempo
    let combinations = sceneEV.toApertureShutterCombo(atISO: iso)
    
    print("\nPossible exposure combinations:")
    for combo in combinations.prefix(5) {
        let shutterStr = combo.shutterSpeed >= 1 
            ? String(format: "%.0f\"", combo.shutterSpeed)
            : "1/\(Int(round(1.0 / combo.shutterSpeed)))"
        print("  f/\(String(format: "%.1f", combo.aperture)) | \(shutterStr)")
    }
    
    // Scelta specifica
    let chosenAperture = 8.0
    let chosenShutter = 1.0/250.0
    let calculatedEV = exposureEngine.calculateEV(aperture: chosenAperture, shutterSpeed: chosenShutter, iso: iso)
    
    print("\nChosen: f/\(chosenAperture) | 1/250s | ISO \(Int(iso))")
    print("Calculated EV: \(calculatedEV)")
}

// MARK: - Example 2: Zone System Exposure

func exampleZoneSystemExposure() {
    print("\n" + "=" * 60)
    print("EXAMPLE 2: Zone System Exposure (Ansel Adams Method)")
    print("=" * 60)
    
    let exposureEngine = ExposureEngine.shared
    
    // Scenario: Paesaggio con ombre profonde
    // Ombra più scura con dettaglio: 20 cd/m²
    // Grigio medio scena: 80 cd/m²
    let shadowLuminance = 20.0
    let midGrayLuminance = 80.0
    let iso = 400.0
    
    print("Scene: Landscape with deep shadows")
    print("  Shadow luminance: \(shadowLuminance) cd/m²")
    print("  Mid-gray luminance: \(midGrayLuminance) cd/m²")
    print("  ISO: \(Int(iso))")
    
    // Metodo Ansel Adams: posiziona ombre in Zona III
    let settings = exposureEngine.calculateZoneIIExposure(
        shadowLuminance: shadowLuminance,
        midGrayLuminance: midGrayLuminance,
        iso: iso,
        preferredAperture: 11.0
    )
    
    print("\n📸 Zone III Exposure Settings:")
    print("  \(settings.description)")
    
    // Calcola dove finiranno le luci
    let highlightLuminance = midGrayLuminance * 16 // 4 stop sopra
    let highlightZone = exposureEngine.luminanceToZone(highlightLuminance, midGrayLuminance: midGrayLuminance)
    print("\n📊 Expected Zone Placement:")
    print("  Shadows (Zone III): Detail preserved")
    print("  Mid-gray (Zone V): Normal")
    print("  Highlights (Zone \(highlightZone.rawValue)): \(highlightZone.description)")
    
    // Raccomandazione sviluppo
    let zoneSpread = highlightZone.rawValue - 3
    print("\n🎞️ Development Recommendation:")
    switch zoneSpread {
    case ...5:
        print("  Zone spread: \(zoneSpread) stops → N+1 (increase contrast)")
    case 6...8:
        print("  Zone spread: \(zoneSpread) stops → N (normal development)")
    default:
        print("  Zone spread: \(zoneSpread) stops → N-1 (reduce contrast)")
    }
}

// MARK: - Example 3: Film Characteristics Comparison

func exampleFilmComparison() {
    print("\n" + "=" * 60)
    print("EXAMPLE 3: Film Characteristics Comparison")
    print("=" * 60)
    
    let emulsionEngine = EmulsionPhysicsEngine.shared
    
    let films: [FilmType] = [.ilfordHP5Plus, .ilfordFP4Plus, .kodakTriX400, .kodakTMax100, .kodakTMax400]
    
    print("\n📊 Film Sensitivity Analysis (N Development, 20°C):")
    print(String(format: "%-20s | %-8s | %-10s | %-12s", "Film", "Gamma", "ISO", "Range(stops)"))
    print("-" * 60)
    
    for film in films {
        let analysis = emulsionEngine.analyzeSensitivity(film: film)
        print(String(format: "%-20s | %-8.2f | %-10.0f | %-12.1f",
            film.rawValue,
            analysis.gamma,
            analysis.effectiveISO,
            analysis.dynamicRangeStops
        ))
    }
    
    // Confronto sviluppo
    print("\n🎞️ Development Comparison (Ilford HP5 Plus):")
    print(String(format: "%-10s | %-8s | %-12s", "Dev", "Gamma", "Time(min)"))
    print("-" * 40)
    
    for development in DevelopmentType.allCases {
        let gamma = emulsionEngine.calculateGamma(film: .ilfordHP5Plus, development: development)
        let time = emulsionEngine.calculateDevelopmentTime(film: .ilfordHP5Plus, development: development)
        print(String(format: "%-10s | %-8.2f | %-12.1f",
            development.rawValue,
            gamma,
            time
        ))
    }
}

// MARK: - Example 4: Temperature Effect on Development

func exampleTemperatureEffect() {
    print("\n" + "=" * 60)
    print("EXAMPLE 4: Temperature Effect on Development")
    print("=" * 60)
    
    let emulsionEngine = EmulsionPhysicsEngine.shared
    let film: FilmType = .kodakTriX400
    
    let temperatures = [16.0, 18.0, 20.0, 22.0, 24.0, 26.0]
    
    print("\n🌡️ Temperature Effect on \(film.rawValue) (N Development):")
    print(String(format: "%-8s | %-8s | %-12s", "Temp(°C)", "Gamma", "Time(min)"))
    print("-" * 35)
    
    for temp in temperatures {
        let gamma = emulsionEngine.calculateGamma(film: film, development: .nNormal, temperature: temp)
        let time = emulsionEngine.calculateDevelopmentTime(film: film, development: .nNormal, temperature: temp)
        print(String(format: "%-8.0f | %-8.2f | %-12.1f", temp, gamma, time))
    }
    
    print("\n💡 Note: Higher temperature increases gamma and requires shorter development time")
}

// MARK: - Example 5: X-Pan Panoramic Calculations

func exampleXPanCalculations() {
    print("\n" + "=" * 60)
    print("EXAMPLE 5: X-Pan Panoramic Format Calculations")
    print("=" * 60)
    
    let panoEngine = PanoramicCompositionEngine.shared
    
    // X-Pan con obiettivi disponibili
    let focalLengths = [30.0, 45.0, 90.0]
    
    print("\n🌄 X-Pan Format Specifications:")
    print("  Format: 24x65mm (1:2.7 aspect ratio)")
    
    print("\n📐 Field of View by Focal Length:")
    print(String(format: "%-10s | %-12s | %-12s | %-15s", "Focal(mm)", "HFOV(°)", "VFOV(°)", "35mm Equiv."))
    print("-" * 60)
    
    for focal in focalLengths {
        let hfov = panoEngine.calculateXPanHFOV(focalLength: focal)
        let vfov = panoEngine.calculateXPanVFOV(focalLength: focal)
        let equiv = panoEngine.calculateXPanEquivalent(focalLength: focal)
        
        print(String(format: "%-10.0f | %-12.1f | %-12.1f | %-15.0f",
            focal, hfov, vfov, equiv))
    }
    
    // Profondità di campo
    print("\n🔍 Depth of Field (45mm, f/8, focus at 5m):")
    let dof = panoEngine.calculateDepthOfField(
        focalLength: 45.0,
        aperture: 8.0,
        focusDistance: 5000.0
    )
    print("  \(dof.description)")
    
    // Suggerimenti composizione
    print("\n💡 Composition Tips for Landscape:")
    let tips = panoEngine.getXPanCompositionTips(sceneType: .landscape)
    for tip in tips {
        print("  • \(tip)")
    }
}

// MARK: - Example 6: Dynamic Range Analysis

func exampleDynamicRangeAnalysis() {
    print("\n" + "=" * 60)
    print("EXAMPLE 6: Scene Dynamic Range Analysis")
    print("=" * 60)
    
    let exposureEngine = ExposureEngine.shared
    
    // Simula letture da scena ad alto contrasto
    let readings = [
        ExposureReading(ev: EV(8), zone: .zoneIII, luminance: 25),
        ExposureReading(ev: EV(9), zone: .zoneIV, luminance: 50),
        ExposureReading(ev: EV(10), zone: .zoneV, luminance: 100),
        ExposureReading(ev: EV(11), zone: .zoneVI, luminance: 200),
        ExposureReading(ev: EV(12), zone: .zoneVII, luminance: 400),
        ExposureReading(ev: EV(13), zone: .zoneVIII, luminance: 800)
    ]
    
    print("\n📊 Simulated Scene Readings:")
    for reading in readings {
        print("  Zone \(reading.zone.rawValue): EV \(String(format: "%.0f", reading.ev.value)), \(String(format: "%.0f", reading.luminance)) cd/m²")
    }
    
    let analysis = exposureEngine.analyzeDynamicRange(readings: readings)
    
    print("\n📈 Dynamic Range Analysis:")
    print("  Zone Range: Zone \(analysis.minZone.rawValue) to Zone \(analysis.maxZone.rawValue)")
    print("  Zone Spread: \(analysis.zoneSpread) stops")
    print("  Scene Type: \(analysis.description)")
    print("  Recommended Development: \(analysis.developmentRecommendation.rawValue)")
    
    // Confronto con capacità pellicola
    let emulsionEngine = EmulsionPhysicsEngine.shared
    let filmAnalysis = emulsionEngine.analyzeSensitivity(film: .ilfordHP5Plus)
    
    print("\n🎞️ Film Capability (Ilford HP5 Plus):")
    print("  Dynamic Range: \(String(format: "%.1f", filmAnalysis.dynamicRangeStops)) stops")
    
    if analysis.zoneSpread > Int(filmAnalysis.dynamicRangeStops) {
        print("  ⚠️ Scene exceeds film dynamic range - consider N- development or HDR")
    } else {
        print("  ✅ Scene fits within film dynamic range")
    }
}

// MARK: - Example 7: Split Grade Printing

func exampleSplitGradePrinting() {
    print("\n" + "=" * 60)
    print("EXAMPLE 7: Split Grade Printing Calculation")
    print("=" * 60)
    
    let emulsionEngine = EmulsionPhysicsEngine.shared
    
    // Negativo con range densità 0.4 - 1.8
    let negativeRange = 0.4...1.8
    
    print("\n🖨️ Split Grade Printing Setup:")
    print("  Negative density range: \(negativeRange.lowerBound) - \(negativeRange.upperBound)")
    
    let splitGrade = emulsionEngine.calculateSplitGradeExposure(
        negativeDensityRange: negativeRange,
        paperGrades: (soft: .grade1, hard: .grade4)
    )
    
    print("\n📐 Exposure Settings:")
    print("  \(splitGrade.description)")
    
    // Curve carta
    print("\n📊 Paper Curve Characteristics:")
    for grade in [PaperGrade.grade1, PaperGrade.grade2, PaperGrade.grade3, PaperGrade.grade4] {
        print("  Grade \(grade.rawValue): Contrast Index = \(String(format: "%.1f", grade.contrastIndex))")
    }
}

// MARK: - Example 8: Exposure Compensation

func exampleExposureCompensation() {
    print("\n" + "=" * 60)
    print("EXAMPLE 8: Exposure Compensation for Zone Placement")
    print("=" * 60)
    
    let exposureEngine = ExposureEngine.shared
    
    // Esposizione base
    let baseSettings = ExposureSettings(
        aperture: 8.0,
        shutterSpeed: 1.0/125.0,
        iso: 100,
        ev: EV(13),
        targetZone: .zoneV
    )
    
    print("\n📸 Base Exposure:")
    print("  \(baseSettings.description)")
    
    // Compensazioni per diverse zone target
    print("\n📊 Exposure Compensation for Different Zone Targets:")
    print(String(format: "%-12s | %-10s | %-12s | %-12s", "Target Zone", "EV Shift", "Aperture", "Shutter"))
    print("-" * 55)
    
    for zone in [Zone.zoneIII, .zoneIV, .zoneV, .zoneVI, .zoneVII] {
        let compensation = exposureEngine.exposureCompensation(from: .zoneV, to: zone)
        let adjustedSettings = exposureEngine.applyCompensation(compensation, to: baseSettings)
        
        let shutterStr = adjustedSettings.shutterSpeed >= 1
            ? String(format: "%.0f\"", adjustedSettings.shutterSpeed)
            : "1/\(Int(round(1.0 / adjustedSettings.shutterSpeed)))"
        
        print(String(format: "%-12s | %-+10.1f | %-12.1f | %-12s",
            "Zone \(zone.rawValue)",
            compensation,
            adjustedSettings.aperture,
            shutterStr
        ))
    }
}

// MARK: - Run All Examples

public func runAllExamples() {
    exampleBasicExposure()
    exampleZoneSystemExposure()
    exampleFilmComparison()
    exampleTemperatureEffect()
    exampleXPanCalculations()
    exampleDynamicRangeAnalysis()
    exampleSplitGradePrinting()
    exampleExposureCompensation()
    
    print("\n" + "=" * 60)
    print("✅ ALL EXAMPLES COMPLETED")
    print("=" * 60)
}

// Helper
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
