// InstaxPrinter.swift
// Zone System Master - Instax BLE Integration
// Modelli stampante e comandi specifici

import Foundation
import UIKit

// MARK: - InstaxPrinter

public struct InstaxPrinter {
    
    // MARK: - Properties
    
    public let model: InstaxPrinterModel
    public let name: String
    public let address: String
    public var info: InstaxPrinterInfo?
    
    // MARK: - Computed Properties
    
    public var imageSize: CGSize {
        model.imageSize
    }
    
    public var chunkSize: Int {
        model.chunkSize
    }
    
    public var maxFileSize: Int {
        model.maxFileSize
    }
    
    public var filmFormat: String {
        model.filmFormat
    }
    
    // MARK: - Initialization
    
    public init(model: InstaxPrinterModel, name: String, address: String, info: InstaxPrinterInfo? = nil) {
        self.model = model
        self.name = name
        self.address = address
        self.info = info
    }
    
    // MARK: - Comandi
    
    /// Crea pacchetto richiesta info versione
    public func createVersionInfoPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .supportFunctionAndVersionInfo,
            subCode: 0x00
        )
    }
    
    /// Crea pacchetto richiesta info dispositivo
    public func createDeviceInfoPacket(type: InstaxInfoType) -> InstaxPacket {
        return InstaxPacket(
            eventType: .deviceInfoService,
            subCode: 0x00,
            payload: Data([type.rawValue])
        )
    }
    
    /// Crea pacchetto richiesta info funzioni
    public func createFunctionInfoPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .supportFunctionInfo,
            subCode: 0x00
        )
    }
    
    /// Crea pacchetto identificazione
    public func createIdentifyPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .identifyInformation,
            subCode: 0x10
        )
    }
    
    /// Crea pacchetto spegnimento
    public func createShutdownPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .shutDown,
            subCode: 0x00
        )
    }
    
    /// Crea pacchetto reset
    public func createResetPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .reset,
            subCode: 0x01
        )
    }
    
    /// Crea pacchetto connessione BLE
    public func createBLEConnectPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .bleConnect,
            subCode: 0x03
        )
    }
    
    /// Crea pacchetto inizio download immagine
    public func createImageDownloadStartPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .printImageDownloadStart,
            subCode: 0x00
        )
    }
    
    /// Crea pacchetto dati immagine
    public func createImageDataPacket(data: Data) -> InstaxPacket {
        return InstaxPacket(
            eventType: .printImageDownloadData,
            subCode: 0x00,
            payload: data
        )
    }
    
    /// Crea pacchetto fine download immagine
    public func createImageDownloadEndPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .printImageDownloadEnd,
            subCode: 0x00
        )
    }
    
    /// Crea pacchetto cancella download
    public func createImageDownloadCancelPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .printImageDownloadCancel,
            subCode: 0x03
        )
    }
    
    /// Crea pacchetto stampa immagine
    public func createPrintImagePacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .printImage,
            subCode: 0x80
        )
    }
    
    /// Crea pacchetto espulsione pellicola
    public func createRejectFilmCoverPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .rejectFilmCover,
            subCode: 0x81
        )
    }
    
    /// Crea pacchetto info accelerometro
    public func createXYZAxisInfoPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .xyzAxisInfo,
            subCode: 0x00
        )
    }
    
    /// Crea pacchetto pattern LED
    public func createLEDPatternPacket(pattern: LEDPattern) -> InstaxPacket {
        let payload = pattern.toData()
        return InstaxPacket(
            eventType: .ledPatternSettings,
            subCode: 0x01,
            payload: payload
        )
    }
    
    /// Crea pacchetto info aggiuntive
    public func createAdditionalInfoPacket() -> InstaxPacket {
        return InstaxPacket(
            eventType: .additionalPrinterInfo,
            subCode: 0x10
        )
    }
}

// MARK: - LED Pattern

public struct LEDPattern {
    public let colors: [LEDColor]
    public let speed: UInt8
    public let repeatCount: UInt8
    public let timing: Timing
    
    public enum Timing: UInt8 {
        case normal = 0
        case onPrint = 1
        case onPrintComplete = 2
        case patternSwitch = 3
    }
    
    public struct LEDColor {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        
        public init(red: UInt8, green: UInt8, blue: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
        }
        
        /// Colore BGR per protocollo Instax
        public var bgrData: Data {
            return Data([blue, green, red])
        }
    }
    
    public init(colors: [LEDColor], speed: UInt8 = 5, repeatCount: UInt8 = 255, timing: Timing = .normal) {
        self.colors = colors
        self.speed = speed
        self.repeatCount = repeatCount
        self.timing = timing
    }
    
    public func toData() -> Data {
        var data = Data()
        data.append(timing.rawValue)
        data.append(UInt8(colors.count))
        data.append(speed)
        data.append(repeatCount)
        
        for color in colors {
            data.append(color.bgrData)
        }
        
        return data
    }
}

// MARK: - Pattern Predefiniti

public extension LEDPattern {
    /// Pattern arcobaleno
    static func rainbow(speed: UInt8 = 5) -> LEDPattern {
        let colors: [LEDColor] = [
            .init(red: 255, green: 0, blue: 0),    // Rosso
            .init(red: 255, green: 127, blue: 0),  // Arancione
            .init(red: 255, green: 255, blue: 0),  // Giallo
            .init(red: 0, green: 255, blue: 0),    // Verde
            .init(red: 0, green: 0, blue: 255),    // Blu
            .init(red: 75, green: 0, blue: 130),   // Indaco
            .init(red: 148, green: 0, blue: 211)   // Viola
        ]
        return LEDPattern(colors: colors, speed: speed, repeatCount: 255)
    }
    
    /// Pattern pulsante rosso
    static func pulseRed(speed: UInt8 = 3) -> LEDPattern {
        let colors: [LEDColor] = [
            .init(red: 255, green: 0, blue: 0),
            .init(red: 128, green: 0, blue: 0),
            .init(red: 64, green: 0, blue: 0),
            .init(red: 128, green: 0, blue: 0)
        ]
        return LEDPattern(colors: colors, speed: speed, repeatCount: 255)
    }
    
    /// Pattern pulsante verde
    static func pulseGreen(speed: UInt8 = 3) -> LEDPattern {
        let colors: [LEDColor] = [
            .init(red: 0, green: 255, blue: 0),
            .init(red: 0, green: 128, blue: 0),
            .init(red: 0, green: 64, blue: 0),
            .init(red: 0, green: 128, blue: 0)
        ]
        return LEDPattern(colors: colors, speed: speed, repeatCount: 255)
    }
    
    /// Pattern pulsante blu
    static func pulseBlue(speed: UInt8 = 3) -> LEDPattern {
        let colors: [LEDColor] = [
            .init(red: 0, green: 0, blue: 255),
            .init(red: 0, green: 0, blue: 128),
            .init(red: 0, green: 0, blue: 64),
            .init(red: 0, green: 0, blue: 128)
        ]
        return LEDPattern(colors: colors, speed: speed, repeatCount: 255)
    }
    
    /// Pattern bianco fisso
    static func solidWhite() -> LEDPattern {
        let colors: [LEDColor] = [
            .init(red: 255, green: 255, blue: 255)
        ]
        return LEDPattern(colors: colors, speed: 0, repeatCount: 255)
    }
    
    /// Pattern spento
    static func off() -> LEDPattern {
        let colors: [LEDColor] = [
            .init(red: 0, green: 0, blue: 0)
        ]
        return LEDPattern(colors: colors, speed: 0, repeatCount: 0)
    }
    
    /// Pattern stampa completata
    static func printComplete() -> LEDPattern {
        let colors: [LEDColor] = [
            .init(red: 0, green: 255, blue: 0),
            .init(red: 255, green: 255, blue: 255)
        ]
        return LEDPattern(colors: colors, speed: 10, repeatCount: 3, timing: .onPrintComplete)
    }
    
    /// Pattern errore
    static func error() -> LEDPattern {
        let colors: [LEDColor] = [
            .init(red: 255, green: 0, blue: 0)
        ]
        return LEDPattern(colors: colors, speed: 2, repeatCount: 10)
    }
}

// MARK: - InstaxPrinterModel Extension

public extension InstaxPrinterModel {
    /// Crea una stampante dal nome dispositivo
    static func fromDeviceName(_ name: String) -> InstaxPrinterModel? {
        // Estrai modello dal nome (es. "INSTAX-Mini-12345678")
        let lowercased = name.lowercased()
        
        if lowercased.contains("square") {
            return .squareLink
        } else if lowercased.contains("wide") {
            return .linkWide
        } else if lowercased.contains("mini") {
            if lowercased.contains("liplay") {
                return .miniLiPlay
            } else if lowercased.contains("link 3") || lowercased.contains("link3") {
                return .miniLink3
            } else if lowercased.contains("link 2") || lowercased.contains("link2") {
                return .miniLink2
            } else {
                return .miniLink
            }
        }
        
        return nil
    }
    
    /// Verifica se il modello supporta funzioni avanzate
    var supportsAdvancedFeatures: Bool {
        switch self {
        case .miniLink2, .miniLink3, .squareLink:
            return true
        default:
            return false
        }
    }
    
    /// Verifica se il modello supporta accelerometro
    var supportsAccelerometer: Bool {
        switch self {
        case .miniLink2, .miniLink3:
            return true
        default:
            return false
        }
    }
    
    /// Verifica se il modello supporta LED personalizzati
    var supportsCustomLED: Bool {
        switch self {
        case .miniLink2, .miniLink3:
            return true
        default:
            return false
        }
    }
    
    /// Versione Bluetooth
    var bluetoothVersion: String {
        switch self {
        case .miniLink3:
            return "5.1"
        default:
            return "4.2"
        }
    }
}

// MARK: - Printer Status

public struct PrinterStatus {
    public let isReady: Bool
    public let isPrinting: Bool
    public let hasPaper: Bool
    public let batteryLevel: Int
    public let isCharging: Bool
    public let errorCode: Int?
    
    public var isError: Bool {
        errorCode != nil
    }
    
    public var description: String {
        if let error = errorCode {
            return "Errore: \(error)"
        }
        if isPrinting {
            return "Stampa in corso..."
        }
        if !hasPaper {
            return "Carta esaurita"
        }
        if batteryLevel < 10 {
            return "Batteria scarica"
        }
        return "Pronta"
    }
}

// MARK: - Print Settings

public struct InstaxPrintSettings {
    public var copies: Int = 1
    public var brightness: Double = 0.0
    public var contrast: Double = 1.0
    public var saturation: Double = 1.0
    public var sharpness: Double = 0.0
    public var applyFilter: InstaxFilter?
    
    public enum InstaxFilter {
        case none
        case monochrome
        case sepia
        case vivid
        case natural
        
        public var description: String {
            switch self {
            case .none: return "Nessuno"
            case .monochrome: return "Bianco e Nero"
            case .sepia: return "Seppia"
            case .vivid: return "Vivido"
            case .natural: return "Naturale"
            }
        }
    }
    
    public static let `default` = InstaxPrintSettings()
    
    public init(
        copies: Int = 1,
        brightness: Double = 0.0,
        contrast: Double = 1.0,
        saturation: Double = 1.0,
        sharpness: Double = 0.0,
        applyFilter: InstaxFilter? = nil
    ) {
        self.copies = copies
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.sharpness = sharpness
        self.applyFilter = applyFilter
    }
}
