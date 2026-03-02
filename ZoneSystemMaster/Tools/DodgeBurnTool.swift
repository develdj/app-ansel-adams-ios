//
//  DodgeBurnTool.swift
//  Zone System Master - Photo Editor Engine
//  Dodge & Burn tool simulating darkroom techniques
//

import Foundation
import Metal
import CoreImage
import SwiftUI

// MARK: - Dodge Burn Stroke

public struct DodgeBurnStroke: Identifiable, Equatable {
    public let id = UUID()
    public var points: [CGPoint]
    public var settings: DodgeBurnSettings
    public var timestamp: Date
    public var brushTexture: MTLTexture?
    
    public init(
        points: [CGPoint] = [],
        settings: DodgeBurnSettings = .default,
        timestamp: Date = Date()
    ) {
        self.points = points
        self.settings = settings
        self.timestamp = timestamp
    }
    
    public static func == (lhs: DodgeBurnStroke, rhs: DodgeBurnStroke) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Brush Preview

public struct BrushPreview {
    public var size: CGFloat
    public var hardness: CGFloat
    public var shape: BrushShape
    public var opacity: CGFloat
    
    public init(
        size: CGFloat = 50,
        hardness: CGFloat = 0.5,
        shape: BrushShape = .circle,
        opacity: CGFloat = 0.5
    ) {
        self.size = size
        self.hardness = hardness
        self.shape = shape
        self.opacity = opacity
    }
}

// MARK: - Dodge Burn Tool

public final class DodgeBurnTool: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var settings = DodgeBurnSettings()
    @Published public var strokes: [DodgeBurnStroke] = []
    @Published public var currentStroke: DodgeBurnStroke?
    @Published public var isDrawing = false
    @Published public var brushPreview = BrushPreview()
    
    // MARK: - Metal Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    
    // MARK: - Accumulation Texture
    
    private var accumulationTexture: MTLTexture?
    private var brushTexture: MTLTexture?
    
    // MARK: - Image Properties
    
    private var imageSize: CGSize = .zero
    
    // MARK: - Undo Support
    
    private var strokeHistory: [[DodgeBurnStroke]] = []
    private var historyIndex = -1
    private let maxHistorySize = 20
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        setupComputePipelines()
    }
    
    // MARK: - Pipeline Setup
    
    private func setupComputePipelines() {
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.main) else {
            print("Failed to load Metal library")
            return
        }
        
        let kernelNames = [
            "applyDodgeBurn",
            "generateBrushPattern"
        ]
        
        for kernelName in kernelNames {
            if let function = library.makeFunction(name: kernelName) {
                do {
                    let pipelineState = try device.makeComputePipelineState(function: function)
                    computePipelineStates[kernelName] = pipelineState
                } catch {
                    print("Failed to create pipeline state for \(kernelName): \(error)")
                }
            }
        }
    }
    
    // MARK: - Image Setup
    
    public func setup(with imageSize: CGSize) {
        self.imageSize = imageSize
        createAccumulationTexture(size: imageSize)
        clearAccumulation()
    }
    
    private func createAccumulationTexture(size: CGSize) {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        accumulationTexture = device.makeTexture(descriptor: textureDescriptor)
        brushTexture = device.makeTexture(descriptor: textureDescriptor)
    }
    
    // MARK: - Drawing
    
    public func beginStroke(at point: CGPoint) {
        isDrawing = true
        currentStroke = DodgeBurnStroke(
            points: [point],
            settings: settings
        )
    }
    
    public func continueStroke(to point: CGPoint) {
        guard isDrawing, var stroke = currentStroke else { return }
        
        // Add point with interpolation for smooth strokes
        if let lastPoint = stroke.points.last {
            let interpolatedPoints = interpolatePoints(from: lastPoint, to: point)
            stroke.points.append(contentsOf: interpolatedPoints)
        }
        
        stroke.points.append(point)
        currentStroke = stroke
    }
    
    public func endStroke() {
        guard isDrawing, let stroke = currentStroke else { return }
        
        isDrawing = false
        strokes.append(stroke)
        currentStroke = nil
        
        // Save to history
        saveToHistory()
        
        // Process stroke
        Task {
            await processStroke(stroke)
        }
    }
    
    private func interpolatePoints(from: CGPoint, to: CGPoint) -> [CGPoint] {
        let distance = hypot(to.x - from.x, to.y - from.y)
        let stepSize: CGFloat = settings.brushSize * 0.3
        
        guard distance > stepSize else { return [] }
        
        let steps = Int(distance / stepSize)
        var points: [CGPoint] = []
        
        for i in 1..<steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = from.x + (to.x - from.x) * t
            let y = from.y + (to.y - from.y) * t
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
    
    // MARK: - Stroke Processing
    
    private func processStroke(_ stroke: DodgeBurnStroke) async {
        guard let accumulationTexture = accumulationTexture,
              let brushPipeline = computePipelineStates["generateBrushPattern"],
              let applyPipeline = computePipelineStates["applyDodgeBurn"] else { return }
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                    continuation.resume()
                    return
                }
                
                // Generate brush pattern for each point in stroke
                for point in stroke.points {
                    // Generate brush at point
                    if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                        computeEncoder.setComputePipelineState(brushPipeline)
                        computeEncoder.setTexture(self.brushTexture, index: 0)
                        
                        var center = SIMD2<Float>(
                            Float(point.x / self.imageSize.width),
                            Float(point.y / self.imageSize.height)
                        )
                        var radius = Float(stroke.settings.brushSize / min(self.imageSize.width, self.imageSize.height))
                        var hardness = stroke.settings.brushHardness
                        var shape = stroke.settings.brushShape == .circle ? 0 : 1
                        var ellipseRatio = SIMD2<Float>(1.0, 1.0)
                        
                        computeEncoder.setBytes(&center, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
                        computeEncoder.setBytes(&radius, length: MemoryLayout<Float>.size, index: 1)
                        computeEncoder.setBytes(&hardness, length: MemoryLayout<Float>.size, index: 2)
                        computeEncoder.setBytes(&shape, length: MemoryLayout<Int>.size, index: 3)
                        computeEncoder.setBytes(&ellipseRatio, length: MemoryLayout<SIMD2<Float>>.size, index: 4)
                        
                        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                        let threadGroups = MTLSize(
                            width: (Int(self.imageSize.width) + 15) / 16,
                            height: (Int(self.imageSize.height) + 15) / 16,
                            depth: 1
                        )
                        
                        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                        computeEncoder.endEncoding()
                    }
                    
                    // Apply dodge/burn with brush
                    if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                        computeEncoder.setComputePipelineState(applyPipeline)
                        computeEncoder.setTexture(accumulationTexture, index: 0)
                        computeEncoder.setTexture(self.brushTexture, index: 1)
                        computeEncoder.setTexture(accumulationTexture, index: 2)
                        
                        var intensity = stroke.settings.intensity
                        var exposureTime = stroke.settings.exposureTime
                        var mode = stroke.settings.mode == .dodge ? 0 : 1
                        var gamma = stroke.settings.gamma
                        
                        computeEncoder.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)
                        computeEncoder.setBytes(&exposureTime, length: MemoryLayout<Float>.size, index: 1)
                        computeEncoder.setBytes(&mode, length: MemoryLayout<Int>.size, index: 2)
                        computeEncoder.setBytes(&gamma, length: MemoryLayout<Float>.size, index: 3)
                        
                        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                        let threadGroups = MTLSize(
                            width: (Int(self.imageSize.width) + 15) / 16,
                            height: (Int(self.imageSize.height) + 15) / 16,
                            depth: 1
                        )
                        
                        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                        computeEncoder.endEncoding()
                    }
                }
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Apply to Image
    
    public func apply(to image: CIImage) async -> CIImage {
        guard let accumulationTexture = accumulationTexture else { return image }
        
        // Convert accumulation texture to CIImage and blend with original
        guard let accumulationCIImage = CIImage(mtlTexture: accumulationTexture, options: nil) else {
            return image
        }
        
        // Blend accumulation with original image
        let blendFilter = CIFilter.blendWithAlphaMask()
        blendFilter.inputImage = image
        blendFilter.backgroundImage = CIImage(color: .clear)
        blendFilter.maskImage = accumulationCIImage
        
        return blendFilter.outputImage ?? image
    }
    
    // MARK: - Brush Generation
    
    public func generateBrushTexture(at point: CGPoint, settings: DodgeBurnSettings) -> MTLTexture? {
        guard let pipelineState = computePipelineStates["generateBrushPattern"] else { return nil }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: Int(settings.brushSize * 2),
            height: Int(settings.brushSize * 2),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(texture, index: 0)
        
        var center = SIMD2<Float>(0.5, 0.5)
        var radius: Float = 0.5
        var hardness = settings.brushHardness
        var shape = settings.brushShape == .circle ? 0 : 1
        var ellipseRatio = SIMD2<Float>(1.0, 1.0)
        
        computeEncoder.setBytes(&center, length: MemoryLayout<SIMD2<Float>>.size, index: 0)
        computeEncoder.setBytes(&radius, length: MemoryLayout<Float>.size, index: 1)
        computeEncoder.setBytes(&hardness, length: MemoryLayout<Float>.size, index: 2)
        computeEncoder.setBytes(&shape, length: MemoryLayout<Int>.size, index: 3)
        computeEncoder.setBytes(&ellipseRatio, length: MemoryLayout<SIMD2<Float>>.size, index: 4)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(settings.brushSize * 2) + 15) / 16,
            height: (Int(settings.brushSize * 2) + 15) / 16,
            depth: 1
        )
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return texture
    }
    
    // MARK: - History Management
    
    private func saveToHistory() {
        // Remove future history if we're not at the end
        if historyIndex < strokeHistory.count - 1 {
            strokeHistory.removeSubrange((historyIndex + 1)...)
        }
        
        strokeHistory.append(strokes)
        
        // Limit history size
        if strokeHistory.count > maxHistorySize {
            strokeHistory.removeFirst()
        } else {
            historyIndex += 1
        }
    }
    
    public func undo() {
        guard historyIndex > 0 else { return }
        
        historyIndex -= 1
        strokes = strokeHistory[historyIndex]
        
        // Reprocess all strokes
        Task {
            await reprocessAllStrokes()
        }
    }
    
    public func redo() {
        guard historyIndex < strokeHistory.count - 1 else { return }
        
        historyIndex += 1
        strokes = strokeHistory[historyIndex]
        
        Task {
            await reprocessAllStrokes()
        }
    }
    
    private func reprocessAllStrokes() async {
        clearAccumulation()
        
        for stroke in strokes {
            await processStroke(stroke)
        }
    }
    
    // MARK: - Clear
    
    public func clearStrokes() {
        strokes.removeAll()
        clearAccumulation()
        saveToHistory()
    }
    
    private func clearAccumulation() {
        guard let accumulationTexture = accumulationTexture,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        
        blitEncoder.fill(buffer: MTLBuffer(), range: 0..<0, value: 0)
        blitEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    // MARK: - Brush Presets
    
    public func applyBrushPreset(_ preset: BrushPreset) {
        settings.brushSize = preset.size
        settings.brushHardness = preset.hardness
        settings.brushShape = preset.shape
        settings.intensity = preset.intensity
    }
}

// MARK: - Brush Preset

public struct BrushPreset: Codable, Identifiable {
    public let id = UUID()
    public var name: String
    public var size: Float
    public var hardness: Float
    public var shape: BrushShape
    public var intensity: Float
    public var mode: DodgeBurnMode
    
    public init(
        name: String,
        size: Float,
        hardness: Float,
        shape: BrushShape,
        intensity: Float,
        mode: DodgeBurnMode
    ) {
        self.name = name
        self.size = size
        self.hardness = hardness
        self.shape = shape
        self.intensity = intensity
        self.mode = mode
    }
    
    // Preset brushes
    public static let softDodge = BrushPreset(
        name: "Soft Dodge",
        size: 100,
        hardness: 0.2,
        shape: .circle,
        intensity: 0.3,
        mode: .dodge
    )
    
    public static let hardBurn = BrushPreset(
        name: "Hard Burn",
        size: 50,
        hardness: 0.8,
        shape: .circle,
        intensity: 0.7,
        mode: .burn
    )
    
    public static let detailDodge = BrushPreset(
        name: "Detail Dodge",
        size: 25,
        hardness: 0.9,
        shape: .circle,
        intensity: 0.5,
        mode: .dodge
    )
}

// MARK: - Dodge Burn Tool Extensions

extension DodgeBurnTool {
    
    /// Check if there are strokes to undo
    public var canUndo: Bool {
        historyIndex > 0
    }
    
    /// Check if there are strokes to redo
    public var canRedo: Bool {
        historyIndex < strokeHistory.count - 1
    }
    
    /// Get stroke count
    public var strokeCount: Int {
        strokes.count
    }
    
    /// Get total point count across all strokes
    public var totalPointCount: Int {
        strokes.reduce(0) { $0 + $1.points.count }
    }
    
    /// Remove last stroke
    public func removeLastStroke() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        saveToHistory()
        
        Task {
            await reprocessAllStrokes()
        }
    }
    
    /// Remove stroke at index
    public func removeStroke(at index: Int) {
        guard index >= 0 && index < strokes.count else { return }
        strokes.remove(at: index)
        saveToHistory()
        
        Task {
            await reprocessAllStrokes()
        }
    }
    
    /// Get stroke at point (for selection)
    public func stroke(at point: CGPoint, tolerance: CGFloat = 10) -> DodgeBurnStroke? {
        strokes.first { stroke in
            stroke.points.contains { strokePoint in
                hypot(strokePoint.x - point.x, strokePoint.y - point.y) < tolerance
            }
        }
    }
    
    /// Update settings and preview
    public func updateSettings(_ newSettings: DodgeBurnSettings) {
        settings = newSettings
        updateBrushPreview()
    }
    
    private func updateBrushPreview() {
        brushPreview.size = CGFloat(settings.brushSize)
        brushPreview.hardness = CGFloat(settings.brushHardness)
        brushPreview.shape = settings.brushShape
        brushPreview.opacity = CGFloat(settings.intensity)
    }
    
    /// Create elliptical brush for specific shapes
    public func createEllipticalBrush(
        width: CGFloat,
        height: CGFloat,
        angle: CGFloat = 0
    ) -> MTLTexture? {
        var ellipseSettings = settings
        ellipseSettings.brushShape = .ellipse
        
        // Store ellipse ratio for shader
        let ratio = SIMD2<Float>(Float(width / height), 1.0)
        
        return generateBrushTexture(at: .zero, settings: ellipseSettings)
    }
}
