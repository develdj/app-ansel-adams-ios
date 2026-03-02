// InstaxBLETests.swift
// Zone System Master - Instax BLE Integration
// Test unitari per il framework Instax BLE

import XCTest
@testable import InstaxBLE

// MARK: - InstaxPacket Tests

class InstaxPacketTests: XCTestCase {
    
    func testPacketCreation() {
        let packet = InstaxPacket(
            eventType: .printImageDownloadStart,
            subCode: 0x00,
            payload: Data()
        )
        
        let data = packet.toData()
        
        XCTAssertEqual(data.count, 7) // Header(2) + Length(2) + OpCode(2) + Checksum(1)
        XCTAssertEqual(data[0], 0x41) // 'A'
        XCTAssertEqual(data[1], 0x62) // 'b'
        XCTAssertEqual(data[2], 0x00) // Length high
        XCTAssertEqual(data[3], 0x07) // Length low
        XCTAssertEqual(data[4], 0x10) // Event type
        XCTAssertEqual(data[5], 0x00) // Subcode
    }
    
    func testPacketWithPayload() {
        let payload = Data([0x01, 0x02, 0x03])
        let packet = InstaxPacket(
            eventType: .printImageDownloadData,
            subCode: 0x01,
            payload: payload
        )
        
        let data = packet.toData()
        
        XCTAssertEqual(data.count, 10) // 7 + 3 payload
        XCTAssertEqual(data[6], 0x01)
        XCTAssertEqual(data[7], 0x02)
        XCTAssertEqual(data[8], 0x03)
    }
    
    func testChecksumValidation() {
        let packet = InstaxPacket(
            eventType: .printImage,
            subCode: 0x80
        )
        
        let data = packet.toData()
        let isValid = InstaxPacket.validateChecksum(packet: data)
        
        XCTAssertTrue(isValid)
    }
    
    func testInvalidChecksum() {
        var data = Data([0x41, 0x62, 0x00, 0x07, 0x10, 0x00, 0x00])
        data[6] = 0xFF // Checksum errato
        
        let isValid = InstaxPacket.validateChecksum(packet: data)
        
        XCTAssertFalse(isValid)
    }
}

// MARK: - InstaxPrinterModel Tests

class InstaxPrinterModelTests: XCTestCase {
    
    func testImageSizes() {
        let miniSize = InstaxPrinterModel.miniLink.imageSize
        XCTAssertEqual(miniSize.width, 600)
        XCTAssertEqual(miniSize.height, 800)
        
        let squareSize = InstaxPrinterModel.squareLink.imageSize
        XCTAssertEqual(squareSize.width, 800)
        XCTAssertEqual(squareSize.height, 800)
        
        let wideSize = InstaxPrinterModel.linkWide.imageSize
        XCTAssertEqual(wideSize.width, 1260)
        XCTAssertEqual(wideSize.height, 840)
    }
    
    func testChunkSizes() {
        XCTAssertEqual(InstaxPrinterModel.miniLink.chunkSize, 900)
        XCTAssertEqual(InstaxPrinterModel.squareLink.chunkSize, 1808)
        XCTAssertEqual(InstaxPrinterModel.linkWide.chunkSize, 900)
    }
    
    func testMaxFileSizes() {
        for model in InstaxPrinterModel.allCases {
            XCTAssertEqual(model.maxFileSize, 105 * 1024)
        }
    }
    
    func testModelFromDeviceName() {
        XCTAssertEqual(InstaxPrinterModel.fromDeviceName("INSTAX-Mini-12345678"), .miniLink)
        XCTAssertEqual(InstaxPrinterModel.fromDeviceName("INSTAX-Square-12345678"), .squareLink)
        XCTAssertEqual(InstaxPrinterModel.fromDeviceName("INSTAX-Wide-12345678"), .linkWide)
        XCTAssertEqual(InstaxPrinterModel.fromDeviceName("INSTAX-Mini LiPlay"), .miniLiPlay)
    }
    
    func testSupportsAdvancedFeatures() {
        XCTAssertTrue(InstaxPrinterModel.miniLink2.supportsAdvancedFeatures)
        XCTAssertTrue(InstaxPrinterModel.miniLink3.supportsAdvancedFeatures)
        XCTAssertTrue(InstaxPrinterModel.squareLink.supportsAdvancedFeatures)
        XCTAssertFalse(InstaxPrinterModel.miniLink.supportsAdvancedFeatures)
    }
}

// MARK: - ImagePreprocessor Tests

class ImagePreprocessorTests: XCTestCase {
    
    var preprocessor: ImagePreprocessor!
    
    override func setUp() {
        super.setUp()
        preprocessor = ImagePreprocessor.shared
    }
    
    func testJPEGQualityRange() {
        XCTAssertGreaterThanOrEqual(preprocessor.jpegQuality, 0.0)
        XCTAssertLessThanOrEqual(preprocessor.jpegQuality, 1.0)
    }
    
    func testContrastRange() {
        XCTAssertGreaterThanOrEqual(preprocessor.blackAndWhiteContrast, 0.0)
    }
    
    func testDitheringTypes() {
        let types: [ImagePreprocessor.DitheringType] = [
            .none,
            .floydSteinberg,
            .atkinson,
            .jarvisJudiceNinke,
            .stucki,
            .burkes,
            .sierra,
            .ordered(.two),
            .ordered(.four),
            .ordered(.eight)
        ]
        
        XCTAssertEqual(types.count, 10)
    }
}

// MARK: - InstaxError Tests

class InstaxErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        let errors: [InstaxError] = [
            .bluetoothNotAvailable,
            .bluetoothPoweredOff,
            .bluetoothUnauthorized,
            .printerNotFound,
            .connectionTimeout,
            .connectionFailed,
            .serviceNotFound,
            .characteristicNotFound,
            .writeFailed,
            .invalidImage,
            .imageTooLarge,
            .imageWrongSize,
            .printCancelled,
            .printerBusy,
            .outOfPaper,
            .batteryLow,
            .printerError,
            .checksumInvalid,
            .unexpectedResponse,
            .timeout,
            .unknown
        ]
        
        for error in errors {
            XCTAssertNotNil(error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}

// MARK: - LEDPattern Tests

class LEDPatternTests: XCTestCase {
    
    func testLEDPatternCreation() {
        let colors = [
            LEDPattern.LEDColor(red: 255, green: 0, blue: 0),
            LEDPattern.LEDColor(red: 0, green: 255, blue: 0)
        ]
        
        let pattern = LEDPattern(
            colors: colors,
            speed: 5,
            repeatCount: 255,
            timing: .normal
        )
        
        let data = pattern.toData()
        
        XCTAssertEqual(data[0], 0x00) // Timing
        XCTAssertEqual(data[1], 0x02) // Numero colori
        XCTAssertEqual(data[2], 0x05) // Speed
        XCTAssertEqual(data[3], 0xFF) // Repeat
        
        // BGR data
        XCTAssertEqual(data[4], 0x00) // Blue
        XCTAssertEqual(data[5], 0x00) // Green
        XCTAssertEqual(data[6], 0xFF) // Red
    }
    
    func testPredefinedPatterns() {
        let rainbow = LEDPattern.rainbow()
        XCTAssertEqual(rainbow.colors.count, 7)
        
        let pulseRed = LEDPattern.pulseRed()
        XCTAssertEqual(pulseRed.colors.count, 4)
        
        let solidWhite = LEDPattern.solidWhite()
        XCTAssertEqual(solidWhite.colors.count, 1)
        
        let off = LEDPattern.off()
        XCTAssertEqual(off.colors.count, 1)
        XCTAssertEqual(off.repeatCount, 0)
    }
}

// MARK: - Data Extensions Tests

class DataExtensionsTests: XCTestCase {
    
    func testHexString() {
        let data = Data([0x41, 0x62, 0x10, 0x00])
        XCTAssertEqual(data.hexString, "41 62 10 00")
    }
    
    func testReadUInt16BE() {
        let data = Data([0x12, 0x34])
        XCTAssertEqual(data.readUInt16BE(at: 0), 0x1234)
    }
    
    func testReadUInt32BE() {
        let data = Data([0x12, 0x34, 0x56, 0x78])
        XCTAssertEqual(data.readUInt32BE(at: 0), 0x12345678)
    }
    
    func testChunks() {
        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        let chunks = data.chunks(ofCount: 3)
        
        XCTAssertEqual(chunks.count, 4)
        XCTAssertEqual(chunks[0], Data([1, 2, 3]))
        XCTAssertEqual(chunks[1], Data([4, 5, 6]))
        XCTAssertEqual(chunks[2], Data([7, 8, 9]))
        XCTAssertEqual(chunks[3], Data([10]))
    }
}

// MARK: - CGSize Extensions Tests

class CGSizeExtensionsTests: XCTestCase {
    
    func testAspectRatio() {
        let size = CGSize(width: 600, height: 800)
        XCTAssertEqual(size.aspectRatio, 0.75)
    }
    
    func testIsValid() {
        XCTAssertTrue(CGSize(width: 100, height: 100).isValid)
        XCTAssertFalse(CGSize(width: 0, height: 100).isValid)
        XCTAssertFalse(CGSize(width: 100, height: 0).isValid)
    }
    
    func testOrientation() {
        XCTAssertTrue(CGSize(width: 800, height: 600).isLandscape)
        XCTAssertTrue(CGSize(width: 600, height: 800).isPortrait)
        XCTAssertTrue(CGSize(width: 800, height: 800).isSquare)
    }
}

// MARK: - InstaxPrintSettings Tests

class InstaxPrintSettingsTests: XCTestCase {
    
    func testDefaultSettings() {
        let settings = InstaxPrintSettings.default
        
        XCTAssertEqual(settings.copies, 1)
        XCTAssertEqual(settings.brightness, 0.0)
        XCTAssertEqual(settings.contrast, 1.0)
        XCTAssertEqual(settings.saturation, 1.0)
        XCTAssertEqual(settings.sharpness, 0.0)
        XCTAssertNil(settings.applyFilter)
    }
    
    func testFilterDescriptions() {
        let filters: [InstaxPrintSettings.InstaxFilter] = [
            .none, .monochrome, .sepia, .vivid, .natural
        ]
        
        for filter in filters {
            XCTAssertFalse(filter.description.isEmpty)
        }
    }
}

// MARK: - InstaxPrinterInfo Tests

class InstaxPrinterInfoTests: XCTestCase {
    
    func testPrinterInfoCreation() {
        let info = InstaxPrinterInfo(
            name: "INSTAX-12345678",
            address: "FA:AB:BC:11:22:33",
            model: .miniLink,
            batteryPercentage: 85,
            batteryState: 1,
            isCharging: false,
            photosLeft: 8,
            imageSize: CGSize(width: 600, height: 800),
            firmwareVersion: "1.0.0"
        )
        
        XCTAssertEqual(info.name, "INSTAX-12345678")
        XCTAssertEqual(info.model, .miniLink)
        XCTAssertEqual(info.batteryPercentage, 85)
        XCTAssertEqual(info.photosLeft, 8)
    }
}

// MARK: - Performance Tests

class PerformanceTests: XCTestCase {
    
    func testPacketCreationPerformance() {
        measure {
            for _ in 0..<10000 {
                let packet = InstaxPacket(
                    eventType: .printImageDownloadData,
                    subCode: 0x01,
                    payload: Data([0x01, 0x02, 0x03, 0x04, 0x05])
                )
                _ = packet.toData()
            }
        }
    }
    
    func testChecksumValidationPerformance() {
        let packet = InstaxPacket(
            eventType: .printImage,
            subCode: 0x80
        )
        let data = packet.toData()
        
        measure {
            for _ in 0..<10000 {
                _ = InstaxPacket.validateChecksum(packet: data)
            }
        }
    }
}

// MARK: - Integration Tests

class IntegrationTests: XCTestCase {
    
    func testPrintWorkflow() {
        // Simula workflow di stampa completo
        let model = InstaxPrinterModel.miniLink
        
        // 1. Crea pacchetti
        let startPacket = InstaxPacket(
            eventType: .printImageDownloadStart,
            subCode: 0x00
        )
        
        let dataPacket = InstaxPacket(
            eventType: .printImageDownloadData,
            subCode: 0x01,
            payload: Data(repeating: 0xFF, count: model.chunkSize)
        )
        
        let endPacket = InstaxPacket(
            eventType: .printImageDownloadEnd,
            subCode: 0x02
        )
        
        let printPacket = InstaxPacket(
            eventType: .printImage,
            subCode: 0x80
        )
        
        // 2. Verifica pacchetti
        XCTAssertEqual(startPacket.toData().count, 7)
        XCTAssertEqual(dataPacket.toData().count, 7 + model.chunkSize)
        XCTAssertEqual(endPacket.toData().count, 7)
        XCTAssertEqual(printPacket.toData().count, 7)
        
        // 3. Verifica checksum
        XCTAssertTrue(InstaxPacket.validateChecksum(packet: startPacket.toData()))
        XCTAssertTrue(InstaxPacket.validateChecksum(packet: dataPacket.toData()))
        XCTAssertTrue(InstaxPacket.validateChecksum(packet: endPacket.toData()))
        XCTAssertTrue(InstaxPacket.validateChecksum(packet: printPacket.toData()))
    }
}
