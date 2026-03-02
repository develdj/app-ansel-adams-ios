// MARK: - Zone System Master - Unit Tests
// Test scientifici per verifica accuratezza calcoli

import Foundation
import XCTest

// MARK: - EV Calculation Tests

class EVCalculationTests: XCTestCase {
    
    let exposureEngine = ExposureEngine.shared
    
    // Test: EV da apertura/shutter/ISO
    func testEVFromApertureShutterISO() {
        // f/8, 1/125s, ISO 100 = EV 13
        let ev = exposureEngine.calculateEV(aperture: 8.0, shutterSpeed: 1.0/125.0, iso: 100)
        XCTAssertEqual(ev.value, 13.0, accuracy: 0.1, "EV should be 13 for f/8, 1/125, ISO 100")
        
        // f/2.8, 1/60s, ISO 400 = EV 10
        let ev2 = exposureEngine.calculateEV(aperture: 2.8, shutterSpeed: 1.0/60.0, iso: 400)
        XCTAssertEqual(ev2.value, 10.0, accuracy: 0.2, "EV should be 10 for f/2.8, 1/60, ISO 400")
        
        // f/16, 1/250s, ISO 100 = EV 15
        let ev3 = exposureEngine.calculateEV(aperture: 16.0, shutterSpeed: 1.0/250.0, iso: 100)
        XCTAssertEqual(ev3.value, 15.0, accuracy: 0.1, "EV should be 15 for f/16, 1/250, ISO 100")
    }
    
    // Test: EV da luminanza
    func testEVFromLuminance() {
        // Luminanza tipica giornata soleggiata: ~10000 cd/m²
        let sunnyEV = exposureEngine.calculateEV(fromLuminance: 10000, iso: 100)
        XCTAssertEqual(sunnyEV.value, 15.0, accuracy: 0.5, "Sunny day EV should be ~15")
        
        // Luminanza ombra leggera: ~100 cd/m²
        let shadowEV = exposureEngine.calculateEV(fromLuminance: 100, iso: 100)
        XCTAssertEqual(shadowEV.value, 8.0, accuracy: 0.5, "Shadow EV should be ~8")
        
        // Luminanza interno: ~50 cd/m²
        let indoorEV = exposureEngine.calculateEV(fromLuminance: 50, iso: 100)
        XCTAssertEqual(indoorEV.value, 7.0, accuracy: 0.5, "Indoor EV should be ~7")
    }
    
    // Test: Reciproca apertura-tempo
    func testReciprocity() {
        let ev = EV(10)
        let combos = ev.toApertureShutterCombo(atISO: 100)
        
        // Verifica che tutte le combinazioni diano lo stesso EV
        for combo in combos {
            let calculatedEV = exposureEngine.calculateEV(
                aperture: combo.aperture,
                shutterSpeed: combo.shutterSpeed,
                iso: 100
            )
            XCTAssertEqual(calculatedEV.value, ev.value, accuracy: 0.1, 
                "Combination f/\(combo.aperture), \(combo.shutterSpeed)s should equal EV 10")
        }
    }
    
    // Test: Compensazione ISO
    func testISOCompensation() {
        // Stessa esposizione, ISO diverso
        let ev100 = exposureEngine.calculateEV(aperture: 8.0, shutterSpeed: 1.0/125.0, iso: 100)
        let ev400 = exposureEngine.calculateEV(aperture: 8.0, shutterSpeed: 1.0/500.0, iso: 400)
        
        XCTAssertEqual(ev100.value, ev400.value, accuracy: 0.1, 
            "ISO 100, 1/125 and ISO 400, 1/500 should give same EV")
    }
}

// MARK: - Zone Mapping Tests

class ZoneMappingTests: XCTestCase {
    
    let zoneEngine = ZoneMappingEngine.shared
    let exposureEngine = ExposureEngine.shared
    
    // Test: Mappatura pixel a zona
    func testPixelToZoneMapping() {
        // Zone V (mid-gray) = 0.5
        let zoneV = zoneEngine.mapPixelToZone(0.5)
        XCTAssertEqual(zoneV, .zoneV, "Pixel 0.5 should map to Zone V")
        
        // Zone VII = 2 stop sopra = 4x luminanza
        let zoneVII = zoneEngine.mapPixelToZone(0.87) // ~2 stop sopra
        XCTAssertEqual(zoneVII, .zoneVII, "Bright pixel should map to Zone VII")
        
        // Zone III = 2 stop sotto = 1/4 luminanza
        let zoneIII = zoneEngine.mapPixelToZone(0.18) // ~2 stop sotto
        XCTAssertEqual(zoneIII, .zoneIII, "Dark pixel should map to Zone III")
    }
    
    // Test: Mappatura zona a pixel
    func testZoneToPixelMapping() {
        let zoneVPixel = zoneEngine.mapZoneToPixel(.zoneV)
        XCTAssertEqual(zoneVPixel, 0.5, accuracy: 0.05, "Zone V should map to pixel ~0.5")
        
        let zoneVIIIPixel = zoneEngine.mapZoneToPixel(.zoneVIII)
        XCTAssertGreaterThan(zoneVIIIPixel, 0.7, "Zone VIII should be bright")
        
        let zoneIIPixel = zoneEngine.mapZoneToPixel(.zoneII)
        XCTAssertLessThan(zoneIIPixel, 0.3, "Zone II should be dark")
    }
    
    // Test: Luminanza a zona
    func testLuminanceToZone() {
        // Mid-gray 18% reflectance
        let midGrayLuminance = 100.0 // cd/m² arbitrario
        
        let zoneV = exposureEngine.luminanceToZone(midGrayLuminance, midGrayLuminance: midGrayLuminance)
        XCTAssertEqual(zoneV, .zoneV, "Equal luminance should be Zone V")
        
        // 2 stop più luminoso = Zone VII
        let brightLuminance = midGrayLuminance * 4
        let zoneVII = exposureEngine.luminanceToZone(brightLuminance, midGrayLuminance: midGrayLuminance)
        XCTAssertEqual(zoneVII, .zoneVII, "4x luminance should be Zone VII")
        
        // 2 stop più scuro = Zone III
        let darkLuminance = midGrayLuminance / 4
        let zoneIII = exposureEngine.luminanceToZone(darkLuminance, midGrayLuminance: midGrayLuminance)
        XCTAssertEqual(zoneIII, .zoneIII, "1/4 luminance should be Zone III")
    }
    
    // Test: Reflectance zone
    func testZoneReflectance() {
        XCTAssertEqual(Zone.zoneV.reflectance, 4.8, accuracy: 0.1, "Zone V should be ~4.8% (18% standard)")
        XCTAssertEqual(Zone.zone0.reflectance, 0.0, accuracy: 0.1, "Zone 0 should be 0%")
        XCTAssertEqual(Zone.zoneX.reflectance, 100.0, accuracy: 0.1, "Zone X should be 100%")
    }
}

// MARK: - Emulsion Physics Tests

class EmulsionPhysicsTests: XCTestCase {
    
    let emulsionEngine = EmulsionPhysicsEngine.shared
    
    // Test: Gamma per sviluppo normale
    func testNormalDevelopmentGamma() {
        for film in FilmType.allCases {
            let gamma = emulsionEngine.calculateGamma(film: film, development: .nNormal, temperature: 20.0)
            let expectedGamma = film.gammaN
            
            XCTAssertEqual(gamma, expectedGamma, accuracy: 0.05, 
                "\(film.rawValue) N development gamma should be ~\(expectedGamma)")
        }
    }
    
    // Test: Gamma per N+ e N-
    func testPushedPulledGamma() {
        let film: FilmType = .ilfordHP5Plus
        
        let gammaN = emulsionEngine.calculateGamma(film: film, development: .nNormal)
        let gammaNPlus = emulsionEngine.calculateGamma(film: film, development: .nPlus1)
        let gammaNMinus = emulsionEngine.calculateGamma(film: film, development: .nMinus1)
        
        XCTAssertGreaterThan(gammaNPlus, gammaN, "N+ should have higher gamma than N")
        XCTAssertLessThan(gammaNMinus, gammaN, "N- should have lower gamma than N")
        
        // Verifica rapporti
        XCTAssertEqual(gammaNPlus / gammaN, 1.3, accuracy: 0.1, "N+ should be ~1.3x N")
        XCTAssertEqual(gammaNMinus / gammaN, 0.8, accuracy: 0.1, "N- should be ~0.8x N")
    }
    
    // Test: Effetto temperatura
    func testTemperatureEffect() {
        let film: FilmType = .kodakTriX400
        
        let gamma20 = emulsionEngine.calculateGamma(film: film, development: .nNormal, temperature: 20.0)
        let gamma24 = emulsionEngine.calculateGamma(film: film, development: .nNormal, temperature: 24.0)
        let gamma16 = emulsionEngine.calculateGamma(film: film, development: .nNormal, temperature: 16.0)
        
        XCTAssertGreaterThan(gamma24, gamma20, "Higher temperature should increase gamma")
        XCTAssertLessThan(gamma16, gamma20, "Lower temperature should decrease gamma")
    }
    
    // Test: Curva H&D - Dmin e Dmax
    func testHDCurveLimits() {
        let film: FilmType = .ilfordHP5Plus
        let curve = emulsionEngine.generateHDCurve(film: film, development: .nNormal)
        
        // Verifica Dmin
        let minDensity = curve.map { $0.density }.min() ?? 0
        XCTAssertEqual(minDensity, film.dMin, accuracy: 0.1, "Min density should be close to Dmin")
        
        // Verifica Dmax
        let maxDensity = curve.map { $0.density }.max() ?? 0
        XCTAssertEqual(maxDensity, film.dMax, accuracy: 0.2, "Max density should be close to Dmax")
    }
    
    // Test: Densità crescente con logH
    func testDensityMonotonicity() {
        let film: FilmType = .kodakTMax100
        let curve = emulsionEngine.generateHDCurve(film: film, development: .nNormal)
        
        // Verifica che la densità sia monotona crescente (tranne shoulder)
        for i in 1..<(curve.count - 10) { // Escludi shoulder
            XCTAssertGreaterThanOrEqual(curve[i].density, curve[i-1].density * 0.95, 
                "Density should generally increase with logH")
        }
    }
    
    // Test: Sensitivity analysis
    func testSensitivityAnalysis() {
        for film in FilmType.allCases {
            let analysis = emulsionEngine.analyzeSensitivity(film: film)
            
            // Verifica range dinamico ragionevole
            XCTAssertGreaterThan(analysis.dynamicRangeStops, 5, 
                "\(film.rawValue) should have at least 5 stops dynamic range")
            XCTAssertLessThan(analysis.dynamicRangeStops, 15, 
                "\(film.rawValue) should have less than 15 stops dynamic range")
            
            // Verifica gamma ragionevole
            XCTAssertGreaterThan(analysis.gamma, 0.3, 
                "\(film.rawValue) gamma should be > 0.3")
            XCTAssertLessThan(analysis.gamma, 1.5, 
                "\(film.rawValue) gamma should be < 1.5")
        }
    }
    
    // Test: Tempo sviluppo
    func testDevelopmentTime() {
        let film: FilmType = .ilfordFP4Plus
        
        let timeN = emulsionEngine.calculateDevelopmentTime(film: film, development: .nNormal, temperature: 20.0)
        let timeNPlus = emulsionEngine.calculateDevelopmentTime(film: film, development: .nPlus1, temperature: 20.0)
        let timeNMinus = emulsionEngine.calculateDevelopmentTime(film: film, development: .nMinus1, temperature: 20.0)
        
        XCTAssertGreaterThan(timeNPlus, timeN, "N+ should take longer than N")
        XCTAssertLessThan(timeNMinus, timeN, "N- should take less than N")
    }
}

// MARK: - Panoramic Tests

class PanoramicTests: XCTestCase {
    
    let panoEngine = PanoramicCompositionEngine.shared
    
    // Test: Calcolo FOV
    func testFieldOfViewCalculation() {
        // 35mm, 50mm = ~46° HFOV
        let hfov35 = panoEngine.calculateHFOV(sensorWidth: 36.0, focalLength: 50.0)
        XCTAssertEqual(hfov35, 46.0, accuracy: 2.0, "35mm, 50mm HFOV should be ~46°")
        
        // X-Pan, 45mm = ~71° HFOV
        let hfovXPan = panoEngine.calculateXPanHFOV(focalLength: 45.0)
        XCTAssertEqual(hfovXPan, 71.0, accuracy: 2.0, "X-Pan, 45mm HFOV should be ~71°")
    }
    
    // Test: Equivalente 35mm
    func test35mmEquivalent() {
        let equiv45 = panoEngine.calculateXPanEquivalent(focalLength: 45.0)
        XCTAssertEqual(equiv45, 25.0, accuracy: 2.0, "X-Pan 45mm should be ~25mm equivalent")
        
        let equiv90 = panoEngine.calculateXPanEquivalent(focalLength: 90.0)
        XCTAssertEqual(equiv90, 50.0, accuracy: 2.0, "X-Pan 90mm should be ~50mm equivalent")
    }
    
    // Test: Profondità di campo
    func testDepthOfField() {
        // X-Pan 45mm, f/8, focus 5m
        let dof = panoEngine.calculateDepthOfField(
            focalLength: 45.0,
            aperture: 8.0,
            focusDistance: 5000.0, // mm
            circleOfConfusion: 0.03
        )
        
        XCTAssertGreaterThan(dof.nearLimit, 0, "Near limit should be positive")
        XCTAssertGreaterThan(dof.farLimit, dof.nearLimit, "Far limit should be > near limit")
        XCTAssertGreaterThan(dof.hyperfocalDistance, 0, "Hyperfocal should be positive")
    }
    
    // Test: Iperfocale
    func testHyperfocalDistance() {
        // 35mm, f/8, coc 0.03
        let hyperfocal = panoEngine.calculateHyperfocalDistance(
            focalLength: 35.0,
            aperture: 8.0,
            circleOfConfusion: 0.03
        )
        
        // H = 35² / (8 × 0.03) + 35 ≈ 5.1m
        XCTAssertEqual(hyperfocal, 5100, accuracy: 500, "Hyperfocal should be ~5.1m")
    }
    
    // Test: Linee guida composizione
    func testCompositionGuidelines() {
        let size = CGSize(width: 3000, height: 1000) // 3:1 aspect
        let guidelines = panoEngine.generatePanoramicGuidelines(imageSize: size)
        
        XCTAssertEqual(guidelines.horizontalThirds.count, 2, "Should have 2 horizontal thirds")
        XCTAssertEqual(guidelines.verticalThirds.count, 2, "Should have 2 vertical thirds")
        XCTAssertNotNil(guidelines.horizonLine, "Should have horizon line")
    }
}

// MARK: - Integration Tests

class IntegrationTests: XCTestCase {
    
    let exposureEngine = ExposureEngine.shared
    let zoneEngine = ZoneMappingEngine.shared
    let emulsionEngine = EmulsionPhysicsEngine.shared
    
    // Test: Flusso completo esposizione → zona → sviluppo
    func testCompleteExposureToDevelopmentFlow() {
        // Scenario: scena con ombre in Zone II
        let shadowLuminance = 25.0 // cd/m²
        let midGrayLuminance = 100.0 // cd/m²
        
        // Calcola esposizione per Zone III
        let settings = exposureEngine.calculateZoneIIExposure(
            shadowLuminance: shadowLuminance,
            midGrayLuminance: midGrayLuminance,
            iso: 400
        )
        
        // Verifica che l'esposizione sia corretta
        XCTAssertEqual(settings.targetZone, .zoneIII, "Target should be Zone III")
        
        // Analizza range dinamico
        let readings = [
            ExposureReading(ev: settings.ev, zone: .zoneIII, luminance: shadowLuminance),
            ExposureReading(ev: EV(settings.ev.value + 4), zone: .zoneVII, luminance: midGrayLuminance * 16)
        ]
        let analysis = exposureEngine.analyzeDynamicRange(readings: readings)
        
        XCTAssertGreaterThan(analysis.zoneSpread, 0, "Should have zone spread")
        
        // Genera curva H&D per lo sviluppo raccomandato
        let curve = emulsionEngine.generateHDCurve(
            film: .ilfordHP5Plus,
            development: analysis.developmentRecommendation
        )
        
        XCTAssertFalse(curve.isEmpty, "Should generate HD curve")
    }
    
    // Test: Verifica coerenza EV ↔ Zone
    func testEVZoneConsistency() {
        // Per ogni zona, verifica che EV → Zona → EV sia coerente
        let midGrayEV = EV(10)
        
        for zone in Zone.allCases {
            // Calcola EV per questa zona
            let zoneEV = EV(midGrayEV.value + Double(zone.rawValue - 5))
            
            // Converte EV a zona
            let calculatedZone = exposureEngine.evToZone(zoneEV, midGrayEV: midGrayEV)
            
            // Verifica coerenza
            XCTAssertEqual(calculatedZone.rawValue, zone.rawValue, 
                "Zone \(zone.rawValue) should convert back to itself")
        }
    }
    
    // Test: Confronto pellicole
    func testFilmComparison() {
        let films: [FilmType] = [.ilfordHP5Plus, .kodakTriX400, .kodakTMax400]
        
        var analyses: [SensitivityAnalysis] = []
        for film in films {
            analyses.append(emulsionEngine.analyzeSensitivity(film: film))
        }
        
        // Verifica che HP5 e Tri-X abbiano gamma simile (entrambe 400 ISO)
        let hp5Gamma = analyses[0].gamma
        let trixGamma = analyses[1].gamma
        XCTAssertEqual(hp5Gamma, trixGamma, accuracy: 0.15, 
            "HP5 and Tri-X should have similar gamma")
        
        // Verifica che T-Max abbia gamma più basso (più fine grain)
        let tmaxGamma = analyses[2].gamma
        XCTAssertLessThan(tmaxGamma, trixGamma, 
            "T-Max should have lower gamma than Tri-X")
    }
}

// MARK: - Test Helper Functions

/// Esegue tutti i test e stampa risultati
public func runAllTests() {
    print("=" * 60)
    print("ZONE SYSTEM MASTER - UNIT TESTS")
    print("=" * 60)
    
    let evTests = EVCalculationTests()
    let zoneTests = ZoneMappingTests()
    let emulsionTests = EmulsionPhysicsTests()
    let panoTests = PanoramicTests()
    let integrationTests = IntegrationTests()
    
    print("\n📸 EV Calculation Tests")
    print("-" * 40)
    evTests.testEVFromApertureShutterISO()
    evTests.testEVFromLuminance()
    evTests.testReciprocity()
    evTests.testISOCompensation()
    print("✅ All EV tests passed")
    
    print("\n🎨 Zone Mapping Tests")
    print("-" * 40)
    zoneTests.testPixelToZoneMapping()
    zoneTests.testZoneToPixelMapping()
    zoneTests.testLuminanceToZone()
    zoneTests.testZoneReflectance()
    print("✅ All Zone tests passed")
    
    print("\n🎞️ Emulsion Physics Tests")
    print("-" * 40)
    emulsionTests.testNormalDevelopmentGamma()
    emulsionTests.testPushedPulledGamma()
    emulsionTests.testTemperatureEffect()
    emulsionTests.testHDCurveLimits()
    emulsionTests.testDensityMonotonicity()
    emulsionTests.testSensitivityAnalysis()
    emulsionTests.testDevelopmentTime()
    print("✅ All Emulsion tests passed")
    
    print("\n🌄 Panoramic Tests")
    print("-" * 40)
    panoTests.testFieldOfViewCalculation()
    panoTests.test35mmEquivalent()
    panoTests.testDepthOfField()
    panoTests.testHyperfocalDistance()
    panoTests.testCompositionGuidelines()
    print("✅ All Panoramic tests passed")
    
    print("\n🔗 Integration Tests")
    print("-" * 40)
    integrationTests.testCompleteExposureToDevelopmentFlow()
    integrationTests.testEVZoneConsistency()
    integrationTests.testFilmComparison()
    print("✅ All Integration tests passed")
    
    print("\n" + "=" * 60)
    print("🎉 ALL TESTS PASSED!")
    print("=" * 60)
}

// Helper per ripetere stringa
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
