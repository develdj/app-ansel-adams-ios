//
//  ZoneSystemMasterTests.swift
//  Zone System Master - Photo Editor Engine
//  Unit tests
//

import XCTest
@testable import ZoneSystemMaster

@MainActor
final class ZoneSystemMasterTests: XCTestCase {
    
    var engine: EditorEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        engine = EditorEngine()
        XCTAssertNotNil(engine, "EditorEngine should initialize")
    }
    
    override func tearDown() async throws {
        engine = nil
        try await super.tearDown()
    }
    
    // MARK: - Zone System Tests
    
    func testZoneSystemConstants() {
        XCTAssertEqual(ZoneSystem.zoneCount, 11)
        XCTAssertEqual(ZoneSystem.middleGrayZone, 5)
        XCTAssertEqual(ZoneSystem.zoneLuminance.count, 11)
    }
    
    func testZoneDescriptions() {
        XCTAssertEqual(ZoneSystem.zoneDescriptions.count, 11)
        XCTAssertTrue(ZoneSystem.zoneDescriptions[0].contains("Pure black"))
        XCTAssertTrue(ZoneSystem.zoneDescriptions[10].contains("Pure white"))
    }
    
    // MARK: - Luminosity Mask Tests
    
    func testLuminosityMaskTypes() {
        let allTypes = LuminosityMaskType.allCases
        XCTAssertEqual(allTypes.count, 5)
        
        // Test zone ranges
        XCTAssertEqual(LuminosityMaskType.lights.zoneRange, 7.5...10.0)
        XCTAssertEqual(LuminosityMaskType.darks.zoneRange, 0.0...2.5)
        XCTAssertEqual(LuminosityMaskType.midtones.zoneRange, 4.5...5.5)
    }
    
    func testLuminosityMaskEngineInitialization() {
        let maskEngine = engine.luminosityMaskEngine
        XCTAssertNotNil(maskEngine)
        XCTAssertEqual(maskEngine.maskCount, 0)
    }
    
    // MARK: - Film Type Tests
    
    func testFilmTypes() {
        let allFilms = FilmType.allCases
        XCTAssertEqual(allFilms.count, 8)
        
        // Test ISO values
        XCTAssertEqual(FilmType.hp5.iso, 400)
        XCTAssertEqual(FilmType.triX.iso, 400)
        XCTAssertEqual(FilmType.delta100.iso, 100)
        XCTAssertEqual(FilmType.panF.iso, 50)
    }
    
    func testFilmCharacteristics() {
        let hp5 = FilmType.hp5.grainCharacteristic
        XCTAssertEqual(hp5.intensity, 0.8, accuracy: 0.01)
        XCTAssertEqual(hp5.size, 1.0, accuracy: 0.01)
        
        let triX = FilmType.triX.grainCharacteristic
        XCTAssertEqual(triX.intensity, 1.2, accuracy: 0.01)
        XCTAssertGreaterThan(triX.intensity, hp5.intensity)
    }
    
    // MARK: - Paper Grade Tests
    
    func testPaperGrades() {
        let allGrades = PaperGrade.allCases
        XCTAssertEqual(allGrades.count, 7)
        
        // Test contrast factors
        XCTAssertEqual(PaperGrade.grade00.contrastFactor, 0.30, accuracy: 0.01)
        XCTAssertEqual(PaperGrade.grade2.contrastFactor, 1.00, accuracy: 0.01)
        XCTAssertEqual(PaperGrade.grade5.contrastFactor, 2.80, accuracy: 0.01)
    }
    
    // MARK: - Dodge & Burn Tests
    
    func testDodgeBurnSettings() {
        let settings = DodgeBurnSettings(
            mode: .dodge,
            intensity: 0.5,
            exposureTime: 1.0,
            brushSize: 50.0,
            brushHardness: 0.5,
            brushShape: .circle,
            gamma: 1.0
        )
        
        XCTAssertEqual(settings.mode, .dodge)
        XCTAssertEqual(settings.intensity, 0.5)
        XCTAssertEqual(settings.brushSize, 50.0)
    }
    
    func testDodgeBurnToolInitialization() {
        let tool = engine.dodgeBurnTool
        XCTAssertNotNil(tool)
        XCTAssertEqual(tool.strokeCount, 0)
        XCTAssertFalse(tool.canUndo)
        XCTAssertFalse(tool.canRedo)
    }
    
    // MARK: - Curve Editor Tests
    
    func testCurveControlPoint() {
        let point = CurveControlPoint(x: 0.5, y: 0.5)
        XCTAssertEqual(point.x, 0.5)
        XCTAssertEqual(point.y, 0.5)
        XCTAssertFalse(point.isFixed)
        
        let fixedPoint = CurveControlPoint.blackPoint
        XCTAssertTrue(fixedPoint.isFixed)
        XCTAssertEqual(fixedPoint.x, 0)
        XCTAssertEqual(fixedPoint.y, 0)
    }
    
    func testTonalCurveSettings() {
        let settings = TonalCurveSettings(
            blackPoint: 0.02,
            whitePoint: 0.98,
            gamma: 1.1,
            toe: 0.1,
            shoulder: 0.1,
            contrast: 1.2
        )
        
        XCTAssertEqual(settings.blackPoint, 0.02)
        XCTAssertEqual(settings.whitePoint, 0.98)
        XCTAssertEqual(settings.gamma, 1.1)
    }
    
    func testFilmCurveTypes() {
        let linearPoints = FilmCurveType.linear.defaultPoints
        XCTAssertEqual(linearPoints.count, 3)
        
        let sCurvePoints = FilmCurveType.sCurve.defaultPoints
        XCTAssertEqual(sCurvePoints.count, 5)
        
        let anselAdamsPoints = FilmCurveType.anselAdams.defaultPoints
        XCTAssertGreaterThanOrEqual(anselAdamsPoints.count, 5)
    }
    
    // MARK: - Annotation Tests
    
    func testAnnotationElement() {
        let element = AnnotationElement(
            type: .circle,
            points: [CGPoint(x: 100, y: 100)],
            color: .red,
            lineWidth: 2.0,
            text: "Test"
        )
        
        XCTAssertEqual(element.type, .circle)
        XCTAssertEqual(element.points.count, 1)
        XCTAssertEqual(element.lineWidth, 2.0)
    }
    
    func testZoneMarkerAnnotation() {
        let marker = AnnotationElement.zoneMarker(zone: 5, at: CGPoint(x: 100, y: 100))
        XCTAssertEqual(marker.type, .circle)
        XCTAssertEqual(marker.text, "Z5")
    }
    
    // MARK: - Export Settings Tests
    
    func testExportSettings() {
        let settings = ExportSettings(
            format: .tiff,
            quality: 1.0,
            resolution: .original,
            colorSpace: .grayGamma22,
            includeMetadata: true
        )
        
        XCTAssertEqual(settings.format, .tiff)
        XCTAssertEqual(settings.quality, 1.0)
        XCTAssertEqual(settings.resolution, .original)
        XCTAssertEqual(settings.colorSpace, .grayGamma22)
        XCTAssertTrue(settings.includeMetadata)
    }
    
    func testExportFormatExtensions() {
        XCTAssertEqual(ExportFormat.tiff.fileExtension, "tiff")
        XCTAssertEqual(ExportFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ExportFormat.png.fileExtension, "png")
        XCTAssertEqual(ExportFormat.heic.fileExtension, "heic")
    }
    
    // MARK: - Layer Tests
    
    func testLayerManager() {
        let layerManager = engine.layerManager
        XCTAssertNotNil(layerManager)
        XCTAssertEqual(layerManager.layers.count, 0)
    }
    
    func testAdjustmentLayer() {
        let layer = AdjustmentLayer(
            name: "Test Adjustment",
            adjustmentType: .contrast(1.2)
        )
        
        XCTAssertEqual(layer.name, "Test Adjustment")
        XCTAssertEqual(layer.type, .adjustment)
        XCTAssertTrue(layer.isVisible)
    }
    
    // MARK: - Extensions Tests
    
    func testColorHexConversion() {
        let color = Color(hex: "#FF0000")
        let hexString = color.toHex()
        XCTAssertTrue(hexString.contains("FF0000"))
    }
    
    func testFloatClamping() {
        let value: Float = 1.5
        let clamped = value.clamped(to: 0...1)
        XCTAssertEqual(clamped, 1.0)
    }
    
    func testCGPointDistance() {
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 3, y: 4)
        XCTAssertEqual(point1.distance(to: point2), 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testMaskGenerationPerformance() async throws {
        let maskEngine = engine.luminosityMaskEngine
        
        measure {
            Task {
                await maskEngine.generateMask(type: .lights)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullProcessingPipeline() async throws {
        // This would test the full processing pipeline
        // with a sample image
        
        // Configure settings
        engine.bwSettings = BWConversionSettings(
            redFilter: 0.299,
            greenFilter: 0.587,
            blueFilter: 0.114,
            contrast: 1.2,
            brightness: 0.0
        )
        
        engine.curveSettings = TonalCurveSettings(
            blackPoint: 0.02,
            whitePoint: 0.98,
            gamma: 1.0,
            toe: 0.1,
            shoulder: 0.1,
            contrast: 1.1
        )
        
        // Verify settings are applied
        XCTAssertEqual(engine.bwSettings.contrast, 1.2)
        XCTAssertEqual(engine.curveSettings.blackPoint, 0.02)
    }
}

// MARK: - Film Database Tests

extension ZoneSystemMasterTests {
    
    func testFilmDatabase() {
        let hp5 = FilmDatabase.hp5Plus
        XCTAssertEqual(hp5.name, "Ilford HP5 Plus")
        XCTAssertEqual(hp5.iso, 400)
        
        let triX = FilmDatabase.triX
        XCTAssertEqual(triX.name, "Kodak Tri-X")
        XCTAssertGreaterThan(triX.grainIntensity, hp5.grainIntensity)
    }
    
    func testAllFilms() {
        let allFilms = FilmDatabase.allFilms
        XCTAssertEqual(allFilms.count, 8)
        
        for film in allFilms {
            XCTAssertGreaterThan(film.iso, 0)
            XCTAssertGreaterThan(film.grainIntensity, 0)
        }
    }
}

// MARK: - Grain Settings Tests

extension ZoneSystemMasterTests {
    
    func testGrainSettings() {
        var settings = GrainSettings(
            filmType: .hp5,
            intensity: 0.5,
            grainSize: 1.0,
            pushPull: 1.0
        )
        
        let effectiveIntensity = settings.effectiveIntensity
        XCTAssertGreaterThan(effectiveIntensity, settings.intensity)
        
        // Test push/pull effect
        settings.pushPull = 2.0
        let pushedIntensity = settings.effectiveIntensity
        XCTAssertGreaterThan(pushedIntensity, effectiveIntensity)
    }
}
