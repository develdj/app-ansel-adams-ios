//
//  Extensions.swift
//  Zone System Master - Photo Editor Engine
//  Utility extensions
//

import Foundation
import SwiftUI
import CoreImage
import Metal

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert to hex string
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
    
    /// Get luminance value (0-1)
    var luminance: Double {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return 0
        }
        // Standard luminance formula
        return 0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2]
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Resize image to target size
    func resized(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Get average color
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
    
    /// Convert to grayscale
    func toGrayscale() -> UIImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectMono") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        guard let output = currentFilter.outputImage else { return nil }
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}

// MARK: - CIImage Extensions

extension CIImage {
    /// Get histogram data
    func histogram() -> HistogramData {
        guard let filter = CIFilter(name: "CIAreaHistogram") else { return HistogramData() }
        filter.setValue(self, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        filter.setValue(256, forKey: "inputCount")
        filter.setValue(1, forKey: "inputScale")
        
        guard let outputImage = filter.outputImage else { return HistogramData() }
        
        var histogramData = HistogramData()
        let context = CIContext()
        
        var bitmap = [UInt32](repeating: 0, count: 256 * 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 256 * 4 * 4, bounds: CGRect(x: 0, y: 0, width: 256, height: 1), format: .RGBA8, colorSpace: nil)
        
        for i in 0..<256 {
            histogramData.red[i] = bitmap[i * 4]
            histogramData.green[i] = bitmap[i * 4 + 1]
            histogramData.blue[i] = bitmap[i * 4 + 2]
            histogramData.luminance[i] = bitmap[i * 4 + 3]
        }
        
        return histogramData
    }
    
    /// Apply gamma correction
    func gammaAdjusted(_ gamma: CGFloat) -> CIImage? {
        let filter = CIFilter.gammaAdjust()
        filter.inputImage = self
        filter.power = Float(gamma)
        return filter.outputImage
    }
    
    /// Get luminance image
    var luminanceImage: CIImage? {
        let filter = CIFilter(colorMonochrome: self, color: CIColor(red: 0.299, green: 0.587, blue: 0.114), intensity: 1.0)
        return filter?.outputImage
    }
}

// MARK: - MTLTexture Extensions

extension MTLTexture {
    /// Get texture size as CGSize
    var size: CGSize {
        CGSize(width: CGFloat(width), height: CGFloat(height))
    }
    
    /// Convert to UIImage
    func toUIImage() -> UIImage? {
        let bytesPerPixel = 4
        let imageByteCount = width * height * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: imageByteCount)
        
        let region = MTLRegionMake2D(0, 0, width, height)
        getBytes(&bytes, bytesPerRow: width * bytesPerPixel, from: region, mipmapLevel: 0)
        
        guard let providerRef = CGDataProvider(data: Data(bytes: bytes, count: imageByteCount) as CFData) else { return nil }
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Distance to another point
    func distance(to point: CGPoint) -> CGFloat {
        hypot(x - point.x, y - point.y)
    }
    
    /// Linear interpolation
    func lerp(to point: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (point.x - x) * t,
            y: y + (point.y - y) * t
        )
    }
    
    /// Convert to normalized coordinates (0-1)
    func normalized(in size: CGSize) -> CGPoint {
        CGPoint(x: x / size.width, y: y / size.height)
    }
    
    /// Convert from normalized coordinates
    func denormalized(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}

// MARK: - CGSize Extensions

extension CGSize {
    /// Aspect ratio
    var aspectRatio: CGFloat {
        width / height
    }
    
    /// Check if size is empty
    var isEmpty: Bool {
        width == 0 || height == 0
    }
    
    /// Fit within target size maintaining aspect ratio
    func fitted(within target: CGSize) -> CGSize {
        let scale = min(target.width / width, target.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }
    
    /// Fill target size maintaining aspect ratio
    func filled(within target: CGSize) -> CGSize {
        let scale = max(target.width / width, target.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    /// Center point
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
    
    /// Initialize with center and size
    init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
    
    /// Scale rect
    func scaled(by factor: CGFloat) -> CGRect {
        CGRect(
            x: origin.x * factor,
            y: origin.y * factor,
            width: width * factor,
            height: height * factor
        )
    }
    
    /// Aspect fit within target rect
    func aspectFit(within target: CGRect) -> CGRect {
        let scale = min(target.width / width, target.height / height)
        let newSize = CGSize(width: width * scale, height: height * scale)
        return CGRect(
            x: target.midX - newSize.width / 2,
            y: target.midY - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
    }
}

// MARK: - Float Extensions

extension Float {
    /// Clamp to range
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
    
    /// Convert to zone value (0-10)
    var toZone: Float {
        self * 10
    }
    
    /// Convert from zone value
    var fromZone: Float {
        self / 10
    }
}

// MARK: - Double Extensions

extension Double {
    /// Clamp to range
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
    
    /// Format as percentage
    var percentageString: String {
        String(format: "%.0f%%", self * 100)
    }
    
    /// Format with specified decimal places
    func formatted(decimals: Int) -> String {
        String(format: "%.*f", decimals, self)
    }
}

// MARK: - String Extensions

extension String {
    /// Check if string is a valid hex color
    var isValidHexColor: Bool {
        let hexRegex = "^#?([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$"
        return NSPredicate(format: "SELF MATCHES %@", hexRegex).evaluate(with: self)
    }
    
    /// Truncate to length
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count > length {
            return String(prefix(length)) + trailing
        }
        return self
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript access
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
    
    /// Chunk array into subarrays
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Binding Extensions

extension Binding {
    /// Convert binding to optional
    func optional<T>() -> Binding<T?> where Value == T {
        Binding<T?>(
            get: { self.wrappedValue },
            set: { newValue in
                if let value = newValue {
                    self.wrappedValue = value
                }
            }
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Conditional modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Add rounded border
    func roundedBorder(color: Color, width: CGFloat = 1, cornerRadius: CGFloat = 8) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: width)
        )
    }
    
    /// Add shadow with default parameters
    func standardShadow() -> some View {
        shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format as string
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }
    
    /// Timestamp string
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: self)
    }
}

// MARK: - FileManager Extensions

extension FileManager {
    /// Get documents directory URL
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Get temporary directory URL
    static var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }
    
    /// Create directory if needed
    func createDirectoryIfNeeded(at url: URL) throws {
        if !fileExists(atPath: url.path) {
            try createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let imageProcessed = Notification.Name("imageProcessed")
    static let settingsChanged = Notification.Name("settingsChanged")
    static let layerUpdated = Notification.Name("layerUpdated")
}
