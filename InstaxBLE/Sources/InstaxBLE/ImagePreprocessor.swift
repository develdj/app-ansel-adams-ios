// ImagePreprocessor.swift
// Zone System Master - Instax BLE Integration
// Preprocessing immagini per stampa Instax (B/N, resize, dithering)

import UIKit
import CoreImage
import ImageIO
import MobileCoreServices

// MARK: - ImagePreprocessor

@MainActor
public final class ImagePreprocessor {
    
    // MARK: - Properties
    
    public static let shared = ImagePreprocessor()
    
    /// Qualità JPEG (0.0 - 1.0)
    public var jpegQuality: CGFloat = 0.92
    
    /// Abilita dithering
    public var enableDithering = true
    
    /// Tipo di dithering
    public var ditheringType: DitheringType = .floydSteinberg
    
    /// Abilita conversione B/N
    public var convertToBlackAndWhite = true
    
    /// Contrasto per B/N (0.0 - 2.0)
    public var blackAndWhiteContrast: CGFloat = 1.1
    
    /// Soglia per B/N (0.0 - 1.0)
    public var blackAndWhiteThreshold: CGFloat = 0.5
    
    // MARK: - Dithering Type
    
    public enum DitheringType {
        case none
        case floydSteinberg
        case atkinson
        case jarvisJudiceNinke
        case stucki
        case burkes
        case sierra
        case ordered(BayerMatrixSize)
        
        public enum BayerMatrixSize: Int {
            case two = 2
            case four = 4
            case eight = 8
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Preprocessa un'immagine per la stampa Instax
    public func preprocessImage(
        _ image: UIImage,
        for model: InstaxPrinterModel
    ) async throws -> Data {
        
        // 1. Ridimensiona l'immagine
        let resizedImage = try await resizeImage(image, to: model.imageSize)
        
        // 2. Converti in B/N se richiesto
        var processedImage = resizedImage
        if convertToBlackAndWhite {
            processedImage = try await convertToBlackAndWhite(resizedImage)
        }
        
        // 3. Applica dithering se richiesto
        if enableDithering && ditheringType != .none {
            processedImage = try await applyDithering(processedImage, type: ditheringType)
        }
        
        // 4. Comprimi in JPEG
        let jpegData = try await compressToJPEG(processedImage, maxSize: model.maxFileSize)
        
        return jpegData
    }
    
    /// Preprocessa un'immagine con parametri personalizzati
    public func preprocessImage(
        _ image: UIImage,
        targetSize: CGSize,
        convertToBW: Bool = true,
        applyDithering: Bool = true,
        maxFileSize: Int = 105 * 1024
    ) async throws -> Data {
        
        // 1. Ridimensiona
        let resizedImage = try await resizeImage(image, to: targetSize)
        
        // 2. Converti in B/N
        var processedImage = resizedImage
        if convertToBW {
            processedImage = try await convertToBlackAndWhite(resizedImage)
        }
        
        // 3. Applica dithering
        if applyDithering {
            processedImage = try await applyDithering(processedImage, type: ditheringType)
        }
        
        // 4. Comprimi
        let jpegData = try await compressToJPEG(processedImage, maxFileSize: maxFileSize)
        
        return jpegData
    }
    
    /// Verifica se l'immagine è valida per la stampa
    public func validateImage(_ image: UIImage, for model: InstaxPrinterModel) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        
        let width = cgImage.width
        let height = cgImage.height
        let expectedSize = model.imageSize
        
        // Verifica dimensioni
        return width == Int(expectedSize.width) && height == Int(expectedSize.height)
    }
    
    // MARK: - Private Methods
    
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) async throws -> UIImage {
        return await Task.detached(priority: .userInitiated) {
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }.value
    }
    
    private func convertToBlackAndWhite(_ image: UIImage) async throws -> UIImage {
        return await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return image }
            
            let ciImage = CIImage(cgImage: cgImage)
            
            // Crea filtro per conversione B/N
            guard let filter = CIFilter(name: "CIPhotoEffectMono") else {
                return image
            }
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            
            guard let outputImage = filter.outputImage,
                  let cgOutput = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
                return image
            }
            
            // Applica contrasto
            let contrastedImage = self.applyContrast(cgOutput, contrast: self.blackAndWhiteContrast)
            
            return UIImage(cgImage: contrastedImage)
        }.value
    }
    
    private func applyContrast(_ cgImage: CGImage, contrast: CGFloat) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let filter = CIFilter(name: "CIColorControls") else {
            return cgImage
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        
        guard let outputImage = filter.outputImage,
              let cgOutput = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return cgImage
        }
        
        return cgOutput
    }
    
    private func applyDithering(_ image: UIImage, type: DitheringType) async throws -> UIImage {
        return await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return image }
            
            let width = cgImage.width
            let height = cgImage.height
            
            // Crea bitmap context
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let bitmapInfo = CGImageAlphaInfo.none.rawValue
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return image
            }
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            guard let buffer = context.data?.assumingMemoryBound(to: UInt8.self) else {
                return image
            }
            
            // Applica dithering
            switch type {
            case .floydSteinberg:
                self.applyFloydSteinbergDithering(buffer, width: width, height: height)
            case .atkinson:
                self.applyAtkinsonDithering(buffer, width: width, height: height)
            case .jarvisJudiceNinke:
                self.applyJarvisJudiceNinkeDithering(buffer, width: width, height: height)
            case .stucki:
                self.applyStuckiDithering(buffer, width: width, height: height)
            case .burkes:
                self.applyBurkesDithering(buffer, width: width, height: height)
            case .sierra:
                self.applySierraDithering(buffer, width: width, height: height)
            case .ordered(let size):
                self.applyOrderedDithering(buffer, width: width, height: height, matrixSize: size)
            case .none:
                break
            }
            
            // Crea immagine dal buffer
            guard let outputCgImage = context.makeImage() else {
                return image
            }
            
            return UIImage(cgImage: outputCgImage)
        }.value
    }
    
    // MARK: - Dithering Algorithms
    
    private func applyFloydSteinbergDithering(_ buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int) {
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = Int(buffer[index])
                let newPixel = oldPixel < 128 ? 0 : 255
                buffer[index] = UInt8(newPixel)
                
                let error = oldPixel - newPixel
                
                // Diffondi errore
                if x + 1 < width {
                    buffer[index + 1] = UInt8(min(255, max(0, Int(buffer[index + 1]) + error * 7 / 16)))
                }
                if y + 1 < height {
                    if x > 0 {
                        buffer[index + width - 1] = UInt8(min(255, max(0, Int(buffer[index + width - 1]) + error * 3 / 16)))
                    }
                    buffer[index + width] = UInt8(min(255, max(0, Int(buffer[index + width]) + error * 5 / 16)))
                    if x + 1 < width {
                        buffer[index + width + 1] = UInt8(min(255, max(0, Int(buffer[index + width + 1]) + error * 1 / 16)))
                    }
                }
            }
        }
    }
    
    private func applyAtkinsonDithering(_ buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int) {
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = Int(buffer[index])
                let newPixel = oldPixel < 128 ? 0 : 255
                buffer[index] = UInt8(newPixel)
                
                let error = (oldPixel - newPixel) / 8
                
                // Diffondi errore (pattern Atkinson)
                let offsets = [
                    (1, 0), (2, 0),
                    (-1, 1), (0, 1), (1, 1),
                    (0, 2)
                ]
                
                for (dx, dy) in offsets {
                    let nx = x + dx
                    let ny = y + dy
                    if nx >= 0 && nx < width && ny < height {
                        let nIndex = ny * width + nx
                        buffer[nIndex] = UInt8(min(255, max(0, Int(buffer[nIndex]) + error)))
                    }
                }
            }
        }
    }
    
    private func applyJarvisJudiceNinkeDithering(_ buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int) {
        let matrix: [(Int, Int, Int)] = [
            (1, 0, 7), (2, 0, 5),
            (-2, 1, 3), (-1, 1, 5), (0, 1, 7), (1, 1, 5), (2, 1, 3),
            (-2, 2, 1), (-1, 2, 3), (0, 2, 5), (1, 2, 3), (2, 2, 1)
        ]
        let divisor = 48
        
        applyErrorDiffusionDithering(buffer, width: width, height: height, matrix: matrix, divisor: divisor)
    }
    
    private func applyStuckiDithering(_ buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int) {
        let matrix: [(Int, Int, Int)] = [
            (1, 0, 8), (2, 0, 4),
            (-2, 1, 2), (-1, 1, 4), (0, 1, 8), (1, 1, 4), (2, 1, 2),
            (-2, 2, 1), (-1, 2, 2), (0, 2, 4), (1, 2, 2), (2, 2, 1)
        ]
        let divisor = 42
        
        applyErrorDiffusionDithering(buffer, width: width, height: height, matrix: matrix, divisor: divisor)
    }
    
    private func applyBurkesDithering(_ buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int) {
        let matrix: [(Int, Int, Int)] = [
            (1, 0, 8), (2, 0, 4),
            (-2, 1, 2), (-1, 1, 4), (0, 1, 8), (1, 1, 4), (2, 1, 2)
        ]
        let divisor = 32
        
        applyErrorDiffusionDithering(buffer, width: width, height: matrix: matrix, divisor: divisor)
    }
    
    private func applySierraDithering(_ buffer: UnsafeMutablePointer<UInt8>, width: Int, height: Int) {
        let matrix: [(Int, Int, Int)] = [
            (1, 0, 5), (2, 0, 3),
            (-2, 1, 2), (-1, 1, 4), (0, 1, 5), (1, 1, 4), (2, 1, 2),
            (-1, 2, 2), (0, 2, 3), (1, 2, 2)
        ]
        let divisor = 32
        
        applyErrorDiffusionDithering(buffer, width: width, height: height, matrix: matrix, divisor: divisor)
    }
    
    private func applyErrorDiffusionDithering(
        _ buffer: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        matrix: [(Int, Int, Int)],
        divisor: Int
    ) {
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = Int(buffer[index])
                let newPixel = oldPixel < 128 ? 0 : 255
                buffer[index] = UInt8(newPixel)
                
                let error = oldPixel - newPixel
                
                for (dx, dy, weight) in matrix {
                    let nx = x + dx
                    let ny = y + dy
                    if nx >= 0 && nx < width && ny < height {
                        let nIndex = ny * width + nx
                        let newValue = Int(buffer[nIndex]) + (error * weight / divisor)
                        buffer[nIndex] = UInt8(min(255, max(0, newValue)))
                    }
                }
            }
        }
    }
    
    private func applyOrderedDithering(
        _ buffer: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        matrixSize: DitheringType.BayerMatrixSize
    ) {
        let matrix: [[Int]]
        
        switch matrixSize {
        case .two:
            matrix = [
                [0, 2],
                [3, 1]
            ]
        case .four:
            matrix = [
                [0, 8, 2, 10],
                [12, 4, 14, 6],
                [3, 11, 1, 9],
                [15, 7, 13, 5]
            ]
        case .eight:
            matrix = [
                [0, 32, 8, 40, 2, 34, 10, 42],
                [48, 16, 56, 24, 50, 18, 58, 26],
                [12, 44, 4, 36, 14, 46, 6, 38],
                [60, 28, 52, 20, 62, 30, 54, 22],
                [3, 35, 11, 43, 1, 33, 9, 41],
                [51, 19, 59, 27, 49, 17, 57, 25],
                [15, 47, 7, 39, 13, 45, 5, 37],
                [63, 31, 55, 23, 61, 29, 53, 21]
            ]
        }
        
        let size = matrixSize.rawValue
        let threshold = size * size
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixel = Int(buffer[index])
                let thresholdValue = (matrix[y % size][x % size] * 256) / threshold
                buffer[index] = pixel < thresholdValue ? 0 : 255
            }
        }
    }
    
    private func compressToJPEG(_ image: UIImage, maxSize: Int) async throws -> Data {
        return try await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else {
                throw InstaxError.invalidImage
            }
            
            // Prova diverse qualità
            var quality = self.jpegQuality
            var jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
            
            // Riduci qualità se necessario
            while let data = jpegData, data.count > maxSize && quality > 0.1 {
                quality -= 0.05
                jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
            }
            
            guard let finalData = jpegData else {
                throw InstaxError.invalidImage
            }
            
            return finalData
        }.value
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Verifica se l'immagine è in formato B/N
    public var isGrayscale: Bool {
        guard let cgImage = cgImage else { return false }
        return cgImage.colorSpace?.model == .monochrome
    }
    
    /// Dimensioni in pixel
    public var pixelSize: CGSize {
        guard let cgImage = cgImage else { return .zero }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }
}
