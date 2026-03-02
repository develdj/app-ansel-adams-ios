// InstaxBLEExtensions.swift
// Zone System Master - Instax BLE Integration
// Estensioni utili per il framework Instax BLE

import UIKit
import CoreBluetooth

// MARK: - Data Extensions

extension Data {
    /// Converte i dati in stringa esadecimale
    public var hexString: String {
        return map { String(format: "%02x", $0) }.joined(separator: " ")
    }
    
    /// Converte i dati in stringa binaria
    public var binaryString: String {
        return map { String($0, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0) }.joined(separator: " ")
    }
    
    /// Legge un UInt16 in big-endian
    public func readUInt16BE(at offset: Int) -> UInt16? {
        guard count >= offset + 2 else { return nil }
        return (UInt16(self[offset]) << 8) | UInt16(self[offset + 1])
    }
    
    /// Legge un UInt32 in big-endian
    public func readUInt32BE(at offset: Int) -> UInt32? {
        guard count >= offset + 4 else { return nil }
        return (UInt32(self[offset]) << 24) |
               (UInt32(self[offset + 1]) << 16) |
               (UInt32(self[offset + 2]) << 8) |
               UInt32(self[offset + 3])
    }
    
    /// Crea dati da un array di UInt8
    public init(bytes: UInt8...) {
        self = Data(bytes)
    }
}

// MARK: - String Extensions

extension String {
    /// Converte una stringa esadecimale in Data
    public var hexData: Data? {
        var data = Data()
        let trimmed = self.replacingOccurrences(of: " ", with: "")
        
        guard trimmed.count % 2 == 0 else { return nil }
        
        for i in stride(from: 0, to: trimmed.count, by: 2) {
            let start = trimmed.index(trimmed.startIndex, offsetBy: i)
            let end = trimmed.index(start, offsetBy: 2)
            let byteString = trimmed[start..<end]
            
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }
        
        return data
    }
}

// MARK: - CBPeripheral Extensions

extension CBPeripheral {
    /// Nome leggibile della stampante
    public var displayName: String {
        return name ?? "Stampante sconosciuta"
    }
    
    /// Indirizzo MAC formattato
    public var formattedAddress: String {
        return identifier.uuidString.prefix(8).uppercased()
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Ridimensiona l'immagine mantenendo le proporzioni
    public func scaled(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Ridimensiona l'immagine per riempire una dimensione target
    public func scaledToFill(_ targetSize: CGSize) -> UIImage {
        let scale = max(targetSize.width / size.width, targetSize.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            let origin = CGPoint(
                x: (targetSize.width - newSize.width) / 2,
                y: (targetSize.height - newSize.height) / 2
            )
            self.draw(in: CGRect(origin: origin, size: newSize))
        }
    }
    
    /// Ridimensiona l'immagine per adattarsi a una dimensione target
    public func scaledToFit(_ targetSize: CGSize) -> UIImage {
        let scale = min(targetSize.width / size.width, targetSize.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return scaled(to: newSize)
    }
    
    /// Ritaglia l'immagine a un rettangolo
    public func cropped(to rect: CGRect) -> UIImage? {
        guard let cgImage = cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
    
    /// Ruota l'immagine
    public func rotated(by degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        let newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
    
    /// Converte in grayscale
    public func toGrayscale() -> UIImage? {
        guard let cgImage = cgImage else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let grayImage = context.makeImage() else { return nil }
        return UIImage(cgImage: grayImage, scale: scale, orientation: imageOrientation)
    }
    
    /// Applica contrasto
    public func adjustingContrast(_ contrast: CGFloat) -> UIImage? {
        guard let cgImage = cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        
        guard let outputImage = filter.outputImage,
              let cgOutput = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgOutput, scale: scale, orientation: imageOrientation)
    }
    
    /// Applica luminosità
    public func adjustingBrightness(_ brightness: CGFloat) -> UIImage? {
        guard let cgImage = cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        
        guard let outputImage = filter.outputImage,
              let cgOutput = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgOutput, scale: scale, orientation: imageOrientation)
    }
    
    /// Applica saturazione
    public func adjustingSaturation(_ saturation: CGFloat) -> UIImage? {
        guard let cgImage = cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorControls") else { return nil }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        
        guard let outputImage = filter.outputImage,
              let cgOutput = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgOutput, scale: scale, orientation: imageOrientation)
    }
    
    /// Dimensione file stimata in bytes
    public var estimatedFileSize: Int {
        guard let cgImage = cgImage else { return 0 }
        return cgImage.width * cgImage.height * 4 // RGBA
    }
}

// MARK: - CGSize Extensions

extension CGSize {
    /// Aspect ratio (larghezza / altezza)
    public var aspectRatio: CGFloat {
        guard height != 0 else { return 1 }
        return width / height
    }
    
    /// Verifica se le dimensioni sono valide
    public var isValid: Bool {
        width > 0 && height > 0
    }
    
    /// Verifica se è in landscape
    public var isLandscape: Bool {
        width > height
    }
    
    /// Verifica se è in portrait
    public var isPortrait: Bool {
        height > width
    }
    
    /// Verifica se è quadrata
    public var isSquare: Bool {
        width == height
    }
}

// MARK: - CGFloat Extensions

extension CGFloat {
    /// Limita il valore a un range
    public func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Int Extensions

extension Int {
    /// Formatta come percentuale
    public var percentageString: String {
        return "\(self)%"
    }
    
    /// Formatta come dimensione file
    public var fileSizeString: String {
        let bytes = Double(self)
        let kb = bytes / 1024
        let mb = kb / 1024
        
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.1f KB", kb)
        } else {
            return "\(self) bytes"
        }
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Formatta come tempo
    public var timeString: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%d sec", seconds)
        }
    }
}

// MARK: - Date Extensions

extension Date {
    /// Formatta come stringa relativa
    public var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Array Extensions

extension Array {
    /// Divide l'array in chunk di dimensione specificata
    public func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Attendi con timeout
    public static func sleep(seconds: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Logger

public struct InstaxLogger {
    public static var isEnabled = true
    
    public static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        let filename = (file as NSString).lastPathComponent
        print("[InstaxBLE] [\(filename):\(line)] \(function): \(message)")
    }
    
    public static func logData(_ data: Data, label: String = "Data") {
        guard isEnabled else { return }
        print("[InstaxBLE] \(label): \(data.hexString)")
    }
    
    public static func logError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        let filename = (file as NSString).lastPathComponent
        print("[InstaxBLE] [ERROR] [\(filename):\(line)] \(function): \(error.localizedDescription)")
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let instaxPrinterConnected = Notification.Name("instaxPrinterConnected")
    static let instaxPrinterDisconnected = Notification.Name("instaxPrinterDisconnected")
    static let instaxPrintStarted = Notification.Name("instaxPrintStarted")
    static let instaxPrintCompleted = Notification.Name("instaxPrintCompleted")
    static let instaxPrintFailed = Notification.Name("instaxPrintFailed")
    static let instaxPrintProgress = Notification.Name("instaxPrintProgress")
}

// MARK: - UserInfo Keys

public extension String {
    static let instaxPrinterInfoKey = "instaxPrinterInfo"
    static let instaxPrintJobKey = "instaxPrintJob"
    static let instaxPrintProgressKey = "instaxPrintProgress"
    static let instaxErrorKey = "instaxError"
}
