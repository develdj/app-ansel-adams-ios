// InstaxTypes.swift
// Zone System Master - Instax BLE Integration
// Contiene tipi, costanti e strutture per il protocollo Instax BLE

import Foundation
import CoreBluetooth

// MARK: - UUID BLE Instax

public struct InstaxUUID {
    /// Service UUID per tutte le stampanti Instax Link
    public static let service = CBUUID(string: "70954782-2d83-473d-9e5f-81e1d02d5273")
    
    /// Characteristic per scrivere comandi alla stampante
    public static let writeCharacteristic = CBUUID(string: "70954783-2d83-473d-9e5f-81e1d02d5273")
    
    /// Characteristic per ricevere notifiche dalla stampante
    public static let notifyCharacteristic = CBUUID(string: "70954784-2d83-473d-9e5f-81e1d02d5273")
}

// MARK: - Modelli Stampante

public enum InstaxPrinterModel: String, CaseIterable, Identifiable {
    case miniLink = "Instax Mini Link"
    case miniLink2 = "Instax Mini Link 2"
    case miniLink3 = "Instax Mini Link 3"
    case miniLiPlay = "Instax Mini LiPlay"
    case squareLink = "Instax Square Link"
    case linkWide = "Instax Link Wide"
    
    public var id: String { rawValue }
    
    /// Dimensioni immagine richieste (width, height)
    public var imageSize: CGSize {
        switch self {
        case .miniLink, .miniLink2, .miniLink3, .miniLiPlay:
            return CGSize(width: 600, height: 800)
        case .squareLink:
            return CGSize(width: 800, height: 800)
        case .linkWide:
            return CGSize(width: 1260, height: 840)
        }
    }
    
    /// Dimensione chunk per trasferimento dati
    public var chunkSize: Int {
        switch self {
        case .miniLink, .miniLink2, .miniLink3, .miniLiPlay, .linkWide:
            return 900
        case .squareLink:
            return 1808
        }
    }
    
    /// Dimensione massima file (in bytes)
    public var maxFileSize: Int {
        return 105 * 1024 // 105KB
    }
    
    /// Formato pellicola
    public var filmFormat: String {
        switch self {
        case .miniLink, .miniLink2, .miniLink3, .miniLiPlay:
            return "Instax Mini (54×86mm)"
        case .squareLink:
            return "Instax Square (72×72mm)"
        case .linkWide:
            return "Instax Wide (108×86mm)"
        }
    }
    
    /// Identificatore per scan BLE
    public var deviceNamePrefix: String {
        return "INSTAX-"
    }
}

// MARK: - Event Type (Comandi)

public enum InstaxEventType: UInt8 {
    case supportFunctionAndVersionInfo = 0x00
    case deviceInfoService = 0x01
    case supportFunctionInfo = 0x02
    case identifyInformation = 0x10
    
    case shutDown = 0x00
    case reset = 0x01
    case autoSleepSettings = 0x02
    case bleConnect = 0x03
    
    case printImageDownloadStart = 0x00
    case printImageDownloadData = 0x01
    case printImageDownloadEnd = 0x02
    case printImageDownloadCancel = 0x03
    case printImage = 0x80
    case rejectFilmCover = 0x81
    
    case xyzAxisInfo = 0x00
    case ledPatternSettings = 0x01
    case axisActionSettings = 0x02
    case additionalPrinterInfo = 0x10
}

// MARK: - Info Type

public enum InstaxInfoType: UInt8 {
    case imageSupportInfo = 0
    case batteryInfo = 1
    case printerFunctionInfo = 2
    case printHistoryInfo = 3
    case cameraFunctionInfo = 4
    case cameraHistoryInfo = 5
}

// MARK: - Stato Connessione

public enum InstaxConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case disconnecting
    case error(InstaxError)
    
    public var description: String {
        switch self {
        case .disconnected: return "Disconnesso"
        case .scanning: return "Scansione..."
        case .connecting: return "Connessione..."
        case .connected: return "Connesso"
        case .disconnecting: return "Disconnessione..."
        case .error(let error): return "Errore: \(error.localizedDescription)"
        }
    }
}

// MARK: - Stato Stampa

public enum InstaxPrintState: Equatable {
    case idle
    case preparing
    case sending(progress: Double)
    case printing
    case completed
    case cancelled
    case error(InstaxError)
    
    public var description: String {
        switch self {
        case .idle: return "In attesa"
        case .preparing: return "Preparazione..."
        case .sending(let progress): return "Invio: \(Int(progress * 100))%"
        case .printing: return "Stampa in corso..."
        case .completed: return "Completata"
        case .cancelled: return "Annullata"
        case .error(let error): return "Errore: \(error.localizedDescription)"
        }
    }
}

// MARK: - Errori

public enum InstaxError: Error, LocalizedError, Equatable {
    case bluetoothNotAvailable
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case printerNotFound
    case connectionTimeout
    case connectionFailed
    case serviceNotFound
    case characteristicNotFound
    case writeFailed
    case invalidImage
    case imageTooLarge
    case imageWrongSize
    case printCancelled
    case printerBusy
    case outOfPaper
    case batteryLow
    case printerError
    case checksumInvalid
    case unexpectedResponse
    case timeout
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .bluetoothNotAvailable:
            return "Bluetooth non disponibile"
        case .bluetoothPoweredOff:
            return "Bluetooth spento"
        case .bluetoothUnauthorized:
            return "Autorizzazione Bluetooth mancante"
        case .printerNotFound:
            return "Stampante non trovata"
        case .connectionTimeout:
            return "Timeout connessione"
        case .connectionFailed:
            return "Connessione fallita"
        case .serviceNotFound:
            return "Servizio BLE non trovato"
        case .characteristicNotFound:
            return "Characteristic BLE non trovata"
        case .writeFailed:
            return "Scrittura fallita"
        case .invalidImage:
            return "Immagine non valida"
        case .imageTooLarge:
            return "Immagine troppo grande"
        case .imageWrongSize:
            return "Dimensioni immagine non corrette"
        case .printCancelled:
            return "Stampa annullata"
        case .printerBusy:
            return "Stampante occupata"
        case .outOfPaper:
            return "Carta esaurita"
        case .batteryLow:
            return "Batteria scarica"
        case .printerError:
            return "Errore stampante"
        case .checksumInvalid:
            return "Checksum non valido"
        case .unexpectedResponse:
            return "Risposta inattesa"
        case .timeout:
            return "Timeout"
        case .unknown:
            return "Errore sconosciuto"
        }
    }
}

// MARK: - Informazioni Stampante

public struct InstaxPrinterInfo {
    public let name: String
    public let address: String
    public let model: InstaxPrinterModel?
    public let batteryPercentage: Int
    public let batteryState: Int
    public let isCharging: Bool
    public let photosLeft: Int
    public let imageSize: CGSize
    public let firmwareVersion: String?
    
    public init(
        name: String,
        address: String,
        model: InstaxPrinterModel? = nil,
        batteryPercentage: Int = 0,
        batteryState: Int = 0,
        isCharging: Bool = false,
        photosLeft: Int = 0,
        imageSize: CGSize = .zero,
        firmwareVersion: String? = nil
    ) {
        self.name = name
        self.address = address
        self.model = model
        self.batteryPercentage = batteryPercentage
        self.batteryState = batteryState
        self.isCharging = isCharging
        self.photosLeft = photosLeft
        self.imageSize = imageSize
        self.firmwareVersion = firmwareVersion
    }
}

// MARK: - Job di Stampa

public struct InstaxPrintJob: Identifiable {
    public let id = UUID()
    public let image: UIImage
    public let model: InstaxPrinterModel
    public let date: Date
    public var state: InstaxPrintState
    public var retryCount: Int
    
    public init(
        image: UIImage,
        model: InstaxPrinterModel,
        state: InstaxPrintState = .idle,
        retryCount: Int = 0
    ) {
        self.image = image
        self.model = model
        self.date = Date()
        self.state = state
        self.retryCount = retryCount
    }
}

// MARK: - Pacchetto Instax

public struct InstaxPacket {
    public let header: UInt16  // 0x4162 (client to printer) o 0x6142 (printer to client)
    public let length: UInt16
    public let opCode: (UInt8, UInt8)
    public let payload: Data
    public let checksum: UInt8
    
    /// Header per messaggi client -> printer
    public static let clientHeader: UInt16 = 0x4162  // 'Ab'
    
    /// Header per messaggi printer -> client
    public static let printerHeader: UInt16 = 0x6142  // 'aB'
    
    public init(eventType: InstaxEventType, subCode: UInt8, payload: Data = Data()) {
        self.header = InstaxPacket.clientHeader
        self.opCode = (eventType.rawValue, subCode)
        self.payload = payload
        self.length = UInt16(7 + payload.count)
        self.checksum = InstaxPacket.calculateChecksum(
            header: self.header,
            length: self.length,
            opCode: self.opCode,
            payload: self.payload
        )
    }
    
    public func toData() -> Data {
        var data = Data()
        data.append(UInt8((header >> 8) & 0xFF))
        data.append(UInt8(header & 0xFF))
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(UInt8(length & 0xFF))
        data.append(opCode.0)
        data.append(opCode.1)
        data.append(payload)
        data.append(checksum)
        return data
    }
    
    public static func calculateChecksum(
        header: UInt16,
        length: UInt16,
        opCode: (UInt8, UInt8),
        payload: Data
    ) -> UInt8 {
        var sum: UInt32 = 0
        sum += UInt32((header >> 8) & 0xFF)
        sum += UInt32(header & 0xFF)
        sum += UInt32((length >> 8) & 0xFF)
        sum += UInt32(length & 0xFF)
        sum += UInt32(opCode.0)
        sum += UInt32(opCode.1)
        for byte in payload {
            sum += UInt32(byte)
        }
        return UInt8((255 - (sum & 255)) & 255)
    }
    
    public static func validateChecksum(packet: Data) -> Bool {
        guard packet.count >= 7 else { return false }
        var sum: UInt32 = 0
        for i in 0..<(packet.count - 1) {
            sum += UInt32(packet[i])
        }
        let calculated = UInt8((sum + UInt32(packet[packet.count - 1])) & 255)
        return calculated == 255
    }
}

// MARK: - Costanti

public struct InstaxConstants {
    /// Timeout per connessione (secondi)
    public static let connectionTimeout: TimeInterval = 30.0
    
    /// Timeout per risposta (secondi)
    public static let responseTimeout: TimeInterval = 10.0
    
    /// Timeout per stampa completa (secondi)
    public static let printTimeout: TimeInterval = 120.0
    
    /// Dimensione massima pacchetto BLE
    public static let maxPacketSize = 182
    
    /// Numero massimo retry
    public static let maxRetries = 3
    
    /// Ritardo tra retry (secondi)
    public static let retryDelay: TimeInterval = 1.0
}
