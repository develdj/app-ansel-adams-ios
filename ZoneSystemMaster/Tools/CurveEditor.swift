//
//  CurveEditor.swift
//  Zone System Master - Photo Editor Engine
//  Tonal curve editor with H&D curve simulation
//

import Foundation
import Metal
import CoreImage
import SwiftUI

// MARK: - Curve Point

public struct CurvePoint: Identifiable, Equatable {
    public let id = UUID()
    public var x: CGFloat // Input value 0-1
    public var y: CGFloat // Output value 0-1
    public var isFixed: Bool
    public var controlPoint1: CGPoint? // For bezier curves
    public var controlPoint2: CGPoint?
    
    public init(
        x: CGFloat,
        y: CGFloat,
        isFixed: Bool = false,
        controlPoint1: CGPoint? = nil,
        controlPoint2: CGPoint? = nil
    ) {
        self.x = max(0, min(1, x))
        self.y = max(0, min(1, y))
        self.isFixed = isFixed
        self.controlPoint1 = controlPoint1
        self.controlPoint2 = controlPoint2
    }
    
    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
    
    public static let blackPoint = CurvePoint(x: 0, y: 0, isFixed: true)
    public static let whitePoint = CurvePoint(x: 1, y: 1, isFixed: true)
    public static let midpoint = CurvePoint(x: 0.5, y: 0.5, isFixed: false)
}

// MARK: - Curve Channel

public enum CurveChannel: String, CaseIterable, Identifiable {
    case rgb = "RGB"
    case red = "Red"
    case green = "Green"
    case blue = "Blue"
    case luminance = "Luminance"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .rgb: return .white
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .luminance: return .gray
        }
    }
}

// MARK: - Film Curve Type

public enum FilmCurveType: String, CaseIterable, Identifiable {
    case linear = "Linear"
    case highContrast = "High Contrast"
    case lowContrast = "Low Contrast"
    case sCurve = "S-Curve"
    case inverseS = "Inverse S"
    case shoulder = "Shoulder"
    case toe = "Toe"
    case anselAdams = "Ansel Adams Style"
    case zoneOptimized = "Zone Optimized"
    
    public var id: String { rawValue }
    
    public var defaultPoints: [CurvePoint] {
        switch self {
        case .linear:
            return [.blackPoint, .midpoint, .whitePoint]
        case .highContrast:
            return [
                .blackPoint,
                CurvePoint(x: 0.25, y: 0.15, isFixed: false),
                CurvePoint(x: 0.75, y: 0.85, isFixed: false),
                .whitePoint
            ]
        case .lowContrast:
            return [
                .blackPoint,
                CurvePoint(x: 0.25, y: 0.35, isFixed: false),
                CurvePoint(x: 0.75, y: 0.65, isFixed: false),
                .whitePoint
            ]
        case .sCurve:
            return [
                .blackPoint,
                CurvePoint(x: 0.25, y: 0.1, isFixed: false),
                CurvePoint(x: 0.5, y: 0.5, isFixed: false),
                CurvePoint(x: 0.75, y: 0.9, isFixed: false),
                .whitePoint
            ]
        case .inverseS:
            return [
                .blackPoint,
                CurvePoint(x: 0.25, y: 0.4, isFixed: false),
                CurvePoint(x: 0.5, y: 0.5, isFixed: false),
                CurvePoint(x: 0.75, y: 0.6, isFixed: false),
                .whitePoint
            ]
        case .shoulder:
            return [
                .blackPoint,
                CurvePoint(x: 0.5, y: 0.5, isFixed: false),
                CurvePoint(x: 0.8, y: 0.85, isFixed: false),
                .whitePoint
            ]
        case .toe:
            return [
                .blackPoint,
                CurvePoint(x: 0.2, y: 0.15, isFixed: false),
                CurvePoint(x: 0.5, y: 0.5, isFixed: false),
                .whitePoint
            ]
        case .anselAdams:
            // Ansel Adams style: deep blacks, bright whites, detailed midtones
            return [
                .blackPoint,
                CurvePoint(x: 0.1, y: 0.02, isFixed: false),  // Deep shadows
                CurvePoint(x: 0.3, y: 0.25, isFixed: false),  // Zone III detail
                CurvePoint(x: 0.5, y: 0.5, isFixed: false),   // Zone V
                CurvePoint(x: 0.7, y: 0.75, isFixed: false),  // Zone VII detail
                CurvePoint(x: 0.9, y: 0.95, isFixed: false),  // Bright highlights
                .whitePoint
            ]
        case .zoneOptimized:
            // Optimized for zone system printing
            return [
                .blackPoint,
                CurvePoint(x: 0.09, y: 0.035, isFixed: false), // Zone I
                CurvePoint(x: 0.18, y: 0.09, isFixed: false),  // Zone II
                CurvePoint(x: 0.27, y: 0.18, isFixed: false),  // Zone III
                CurvePoint(x: 0.36, y: 0.36, isFixed: false),  // Zone V (18%)
                CurvePoint(x: 0.5, y: 0.5, isFixed: false),    // Zone VI
                CurvePoint(x: 0.68, y: 0.68, isFixed: false),  // Zone VII
                CurvePoint(x: 0.81, y: 0.81, isFixed: false),  // Zone VIII
                CurvePoint(x: 0.91, y: 0.91, isFixed: false),  // Zone IX
                .whitePoint
            ]
        }
    }
}

// MARK: - Curve Data

public struct CurveData: Identifiable, Equatable {
    public let id = UUID()
    public var channel: CurveChannel
    public var points: [CurvePoint]
    public var isActive: Bool
    
    public init(
        channel: CurveChannel,
        points: [CurvePoint] = [.blackPoint, .midpoint, .whitePoint],
        isActive: Bool = true
    ) {
        self.channel = channel
        self.points = points.sorted { $0.x < $1.x }
        self.isActive = isActive
    }
    
    public mutating func addPoint(_ point: CurvePoint) {
        points.append(point)
        points.sort { $0.x < $1.x }
    }
    
    public mutating func removePoint(at index: Int) {
        guard index >= 0 && index < points.count else { return }
        guard !points[index].isFixed else { return } // Can't remove fixed points
        points.remove(at: index)
    }
    
    public mutating func updatePoint(at index: Int, to newPoint: CurvePoint) {
        guard index >= 0 && index < points.count else { return }
        points[index] = newPoint
        if !newPoint.isFixed {
            points.sort { $0.x < $1.x }
        }
    }
    
    public static func == (lhs: CurveData, rhs: CurveData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Curve Editor

public final class CurveEditor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var curves: [CurveChannel: CurveData] = [:]
    @Published public var selectedChannel: CurveChannel = .luminance
    @Published public var selectedPointID: UUID?
    @Published public var isEditing = false
    @Published public var showHistogram = true
    @Published public var snapToZones = true
    
    // MARK: - Metal Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineState: MTLComputePipelineState?
    
    // MARK: - LUT Cache
    
    private var lutCache: [CurveChannel: [Float]] = [:]
    private var needsLUTUpdate = true
    
    // MARK: - History
    
    private var curveHistory: [[CurveChannel: CurveData]] = []
    private var historyIndex = -1
    private let maxHistorySize = 50
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        
        // Initialize default curves
        for channel in CurveChannel.allCases {
            curves[channel] = CurveData(channel: channel)
        }
        
        setupComputePipeline()
        saveToHistory()
    }
    
    // MARK: - Pipeline Setup
    
    private func setupComputePipeline() {
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.main) else {
            print("Failed to load Metal library")
            return
        }
        
        if let function = library.makeFunction(name: "applyCharacteristicCurve") {
            do {
                computePipelineState = try device.makeComputePipelineState(function: function)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }
    }
    
    // MARK: - Curve Management
    
    public func setCurve(_ curveData: CurveData, for channel: CurveChannel) {
        curves[channel] = curveData
        invalidateLUTCache()
        saveToHistory()
    }
    
    public func getCurve(for channel: CurveChannel) -> CurveData? {
        curves[channel]
    }
    
    public func resetCurve(for channel: CurveChannel) {
        curves[channel] = CurveData(channel: channel)
        invalidateLUTCache()
        saveToHistory()
    }
    
    public func resetAllCurves() {
        for channel in CurveChannel.allCases {
            curves[channel] = CurveData(channel: channel)
        }
        invalidateLUTCache()
        saveToHistory()
    }
    
    public func applyPreset(_ preset: FilmCurveType, to channel: CurveChannel) {
        curves[channel] = CurveData(
            channel: channel,
            points: preset.defaultPoints
        )
        invalidateLUTCache()
        saveToHistory()
    }
    
    // MARK: - Point Management
    
    public func addPoint(_ point: CurvePoint, to channel: CurveChannel) {
        guard var curve = curves[channel] else { return }
        curve.addPoint(point)
        curves[channel] = curve
        invalidateLUTCache()
        saveToHistory()
    }
    
    public func removePoint(at index: Int, from channel: CurveChannel) {
        guard var curve = curves[channel] else { return }
        curve.removePoint(at: index)
        curves[channel] = curve
        invalidateLUTCache()
        saveToHistory()
    }
    
    public func updatePoint(at index: Int, in channel: CurveChannel, to newPoint: CurvePoint) {
        guard var curve = curves[channel] else { return }
        
        // Snap to zones if enabled
        var adjustedPoint = newPoint
        if snapToZones {
            adjustedPoint = snapPointToZones(newPoint)
        }
        
        curve.updatePoint(at: index, to: adjustedPoint)
        curves[channel] = curve
        invalidateLUTCache()
    }
    
    public func movePoint(at index: Int, in channel: CurveChannel, to position: CGPoint) {
        guard var curve = curves[channel],
              index >= 0 && index < curve.points.count else { return }
        
        let point = curve.points[index]
        guard !point.isFixed else { return }
        
        var newPoint = CurvePoint(
            x: position.x,
            y: position.y,
            isFixed: false,
            controlPoint1: point.controlPoint1,
            controlPoint2: point.controlPoint2
        )
        
        // Snap to zones if enabled
        if snapToZones {
            newPoint = snapPointToZones(newPoint)
        }
        
        curve.points[index] = newPoint
        curves[channel] = curve
        invalidateLUTCache()
    }
    
    private func snapPointToZones(_ point: CurvePoint) -> CurvePoint {
        // Snap to zone boundaries
        let zoneStep: CGFloat = 0.1 // Zone system step
        let snappedX = round(point.x / zoneStep) * zoneStep
        let snappedY = round(point.y / zoneStep) * zoneStep
        
        return CurvePoint(
            x: snappedX,
            y: snappedY,
            isFixed: point.isFixed,
            controlPoint1: point.controlPoint1,
            controlPoint2: point.controlPoint2
        )
    }
    
    // MARK: - Curve Evaluation
    
    public func evaluateCurve(_ x: CGFloat, for channel: CurveChannel) -> CGFloat {
        guard let curve = curves[channel] else { return x }
        
        let points = curve.points.sorted { $0.x < $1.x }
        
        // Handle edge cases
        if x <= points.first?.x ?? 0 {
            return points.first?.y ?? 0
        }
        if x >= points.last?.x ?? 1 {
            return points.last?.y ?? 1
        }
        
        // Find surrounding points
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]
            
            if x >= p1.x && x <= p2.x {
                // Linear interpolation
                let t = (x - p1.x) / (p2.x - p1.x)
                return p1.y + (p2.y - p1.y) * t
            }
        }
        
        return x
    }
    
    // MARK: - LUT Generation
    
    public func generateLUT(for channel: CurveChannel, size: Int = 256) -> [Float] {
        if let cached = lutCache[channel] {
            return cached
        }
        
        var lut: [Float] = []
        for i in 0..<size {
            let x = CGFloat(i) / CGFloat(size - 1)
            let y = evaluateCurve(x, for: channel)
            lut.append(Float(y))
        }
        
        lutCache[channel] = lut
        return lut
    }
    
    private func invalidateLUTCache() {
        lutCache.removeAll()
        needsLUTUpdate = true
    }
    
    // MARK: - Apply to Image
    
    public func apply(to image: CIImage) async -> CIImage {
        guard let curve = curves[.luminance], curve.isActive else { return image }
        
        // Use Core Image for curve application
        let lut = generateLUT(for: .luminance)
        
        // Create color cube from LUT
        let colorCubeFilter = CIFilter.colorCube()
        colorCubeFilter.inputImage = image
        
        // Convert LUT to data
        var cubeData = Data()
        for value in lut {
            var floatValue = value
            cubeData.append(UnsafeBufferPointer(start: &floatValue, count: 1))
        }
        
        colorCubeFilter.cubeData = cubeData
        colorCubeFilter.cubeDimension = 256
        
        return colorCubeFilter.outputImage ?? image
    }
    
    // MARK: - Metal Processing
    
    public func applyWithMetal(to image: CIImage, settings: TonalCurveSettings) async -> CIImage {
        guard let pipelineState = computePipelineState else { return image }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    continuation.resume(returning: image)
                    return
                }
                
                // Create textures
                let inputTexture = self.ciImageToTexture(image)
                let outputTexture = self.createTexture(size: image.extent.size)
                
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder.setTexture(inputTexture, index: 0)
                computeEncoder.setTexture(outputTexture, index: 1)
                
                var blackPoint = settings.blackPoint
                var whitePoint = settings.whitePoint
                var gamma = settings.gamma
                var toe = settings.toe
                var shoulder = settings.shoulder
                var contrast = settings.contrast
                
                computeEncoder.setBytes(&blackPoint, length: MemoryLayout<Float>.size, index: 0)
                computeEncoder.setBytes(&whitePoint, length: MemoryLayout<Float>.size, index: 1)
                computeEncoder.setBytes(&gamma, length: MemoryLayout<Float>.size, index: 2)
                computeEncoder.setBytes(&toe, length: MemoryLayout<Float>.size, index: 3)
                computeEncoder.setBytes(&shoulder, length: MemoryLayout<Float>.size, index: 4)
                computeEncoder.setBytes(&contrast, length: MemoryLayout<Float>.size, index: 5)
                
                let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                let threadGroups = MTLSize(
                    width: (Int(image.extent.width) + 15) / 16,
                    height: (Int(image.extent.height) + 15) / 16,
                    depth: 1
                )
                
                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                computeEncoder.endEncoding()
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                if let outputImage = self.textureToCIImage(outputTexture) {
                    continuation.resume(returning: outputImage)
                } else {
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    // MARK: - Texture Helpers
    
    private func ciImageToTexture(_ image: CIImage) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: Int(image.extent.width),
            height: Int(image.extent.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Failed to create texture")
        }
        
        let ciContext = CIContext(mtlDevice: device)
        ciContext.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceGray())
        
        return texture
    }
    
    private func createTexture(size: CGSize) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Failed to create texture")
        }
        
        return texture
    }
    
    private func textureToCIImage(_ texture: MTLTexture) -> CIImage? {
        return CIImage(mtlTexture: texture, options: [
            .colorSpace: CGColorSpaceCreateDeviceGray()
        ])
    }
    
    // MARK: - History Management
    
    private func saveToHistory() {
        if historyIndex < curveHistory.count - 1 {
            curveHistory.removeSubrange((historyIndex + 1)...)
        }
        
        curveHistory.append(curves)
        
        if curveHistory.count > maxHistorySize {
            curveHistory.removeFirst()
        } else {
            historyIndex += 1
        }
    }
    
    public func undo() {
        guard historyIndex > 0 else { return }
        
        historyIndex -= 1
        curves = curveHistory[historyIndex]
        invalidateLUTCache()
    }
    
    public func redo() {
        guard historyIndex < curveHistory.count - 1 else { return }
        
        historyIndex += 1
        curves = curveHistory[historyIndex]
        invalidateLUTCache()
    }
    
    // MARK: - Zone System Integration
    
    public func optimizeForZoneSystem() {
        // Adjust curves for optimal zone system rendering
        guard var curve = curves[.luminance] else { return }
        
        // Ensure good separation between zones
        let zonePoints: [CurvePoint] = [
            .blackPoint,
            CurvePoint(x: 0.09, y: 0.035, isFixed: false), // Zone I
            CurvePoint(x: 0.18, y: 0.09, isFixed: false),  // Zone II
            CurvePoint(x: 0.27, y: 0.18, isFixed: false),  // Zone III
            CurvePoint(x: 0.36, y: 0.36, isFixed: false),  // Zone V (18% gray)
            CurvePoint(x: 0.5, y: 0.5, isFixed: false),    // Zone VI
            CurvePoint(x: 0.68, y: 0.68, isFixed: false),  // Zone VII
            CurvePoint(x: 0.81, y: 0.81, isFixed: false),  // Zone VIII
            CurvePoint(x: 0.91, y: 0.91, isFixed: false),  // Zone IX
            .whitePoint
        ]
        
        curve.points = zonePoints
        curves[.luminance] = curve
        invalidateLUTCache()
        saveToHistory()
    }
    
    // MARK: - Export/Import
    
    public func exportCurves() -> CurvePreset {
        return CurvePreset(
            name: "Custom Curves",
            curves: curves.mapValues { curve in
                CurveSnapshot(
                    channel: curve.channel,
                    points: curve.points.map { PointSnapshot(from: $0) },
                    isActive: curve.isActive
                )
            }
        )
    }
    
    public func importCurves(from preset: CurvePreset) {
        for (channel, snapshot) in preset.curves {
            curves[channel] = CurveData(
                channel: channel,
                points: snapshot.points.map { $0.toCurvePoint() },
                isActive: snapshot.isActive
            )
        }
        invalidateLUTCache()
        saveToHistory()
    }
}

// MARK: - Curve Preset

public struct CurvePreset: Codable {
    public var name: String
    public var curves: [CurveChannel: CurveSnapshot]
    public var createdAt: Date
    
    public init(name: String, curves: [CurveChannel: CurveSnapshot]) {
        self.name = name
        self.curves = curves
        self.createdAt = Date()
    }
}

// MARK: - Curve Snapshot

public struct CurveSnapshot: Codable {
    public let channel: CurveChannel
    public let points: [PointSnapshot]
    public let isActive: Bool
}

// MARK: - Point Snapshot

public struct PointSnapshot: Codable {
    public let x: CGFloat
    public let y: CGFloat
    public let isFixed: Bool
    
    public init(from point: CurvePoint) {
        self.x = point.x
        self.y = point.y
        self.isFixed = point.isFixed
    }
    
    public func toCurvePoint() -> CurvePoint {
        CurvePoint(x: x, y: y, isFixed: isFixed)
    }
}

// MARK: - Curve Editor Extensions

extension CurveEditor {
    
    /// Check if can undo
    public var canUndo: Bool {
        historyIndex > 0
    }
    
    /// Check if can redo
    public var canRedo: Bool {
        historyIndex < curveHistory.count - 1
    }
    
    /// Get active curve count
    public var activeCurveCount: Int {
        curves.values.filter { $0.isActive }.count
    }
    
    /// Get total point count
    public var totalPointCount: Int {
        curves.values.reduce(0) { $0 + $1.points.count }
    }
    
    /// Get curve as path for drawing
    public func getCurvePath(for channel: CurveChannel, in rect: CGRect) -> Path {
        guard let curve = curves[channel] else { return Path() }
        
        var path = Path()
        let points = curve.points.sorted { $0.x < $1.x }
        
        guard !points.isEmpty else { return path }
        
        let firstPoint = CGPoint(
            x: rect.minX + points[0].x * rect.width,
            y: rect.maxY - points[0].y * rect.height
        )
        path.move(to: firstPoint)
        
        for i in 1..<points.count {
            let point = CGPoint(
                x: rect.minX + points[i].x * rect.width,
                y: rect.maxY - points[i].y * rect.height
            )
            path.addLine(to: point)
        }
        
        return path
    }
    
    /// Get zone markers for visualization
    public func getZoneMarkers(in rect: CGRect) -> [CGPoint] {
        var markers: [CGPoint] = []
        for zone in 0...10 {
            let x = CGFloat(zone) / 10.0
            markers.append(CGPoint(
                x: rect.minX + x * rect.width,
                y: rect.midY
            ))
        }
        return markers
    }
    
    /// Find nearest point to position
    public func nearestPoint(to position: CGPoint, in rect: CGRect, for channel: CurveChannel, tolerance: CGFloat = 20) -> (index: Int, point: CurvePoint)? {
        guard let curve = curves[channel] else { return nil }
        
        for (index, point) in curve.points.enumerated() {
            let pointPosition = CGPoint(
                x: rect.minX + point.x * rect.width,
                y: rect.maxY - point.y * rect.height
            )
            
            let distance = hypot(pointPosition.x - position.x, pointPosition.y - position.y)
            if distance < tolerance {
                return (index, point)
            }
        }
        
        return nil
    }
    
    /// Create smooth curve using bezier interpolation
    public func createSmoothCurve(for channel: CurveChannel) {
        guard var curve = curves[channel] else { return }
        
        // This would implement Catmull-Rom or cubic bezier interpolation
        // For now, we'll keep the linear interpolation
        
        curves[channel] = curve
        invalidateLUTCache()
        saveToHistory()
    }
}
