//
//  EditorEngine.swift
//  Zone System Master - Photo Editor Engine
//  Main processing engine with Metal pipeline
//

import Foundation
import Metal
import MetalKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine
import SwiftUI

// MARK: - Editor Engine

@MainActor
public final class EditorEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentImage: CIImage?
    @Published public private(set) var previewImage: UIImage?
    @Published public private(set) var processingState: ProcessingState = .idle
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var viewOffset: CGSize = .zero
    
    // MARK: - Settings
    
    @Published public var bwSettings = BWConversionSettings()
    @Published public var curveSettings = TonalCurveSettings()
    @Published public var filmGrainSettings = FilmGrainSettings()
    @Published public var vignetteSettings = VignetteSettings()
    @Published public var sharpeningSettings = SharpeningSettings()
    @Published public var splitGradeSettings = SplitGradeSettings()
    
    // MARK: - Metal Properties
    
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let textureLoader: MTKTextureLoader
    
    private var computePipelineState: MTLComputePipelineState?
    private var renderPipelineState: MTLRenderPipelineState?
    
    // MARK: - Core Image
    
    public let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceGray()
    
    // MARK: - Layer Management
    
    public let layerManager: LayerManager
    public let luminosityMaskEngine: LuminosityMaskEngine
    public let dodgeBurnTool: DodgeBurnTool
    public let curveEditor: CurveEditor
    public let annotationOverlay: AnnotationOverlay
    public let filmGrainSimulator: FilmGrainSimulator
    
    // MARK: - Undo/Redo
    
    public let undoManager = UndoManager()
    private var historyStack: [EditState] = []
    private var historyIndex = -1
    private let maxHistorySize = 50
    
    // MARK: - Caching
    
    private var textureCache: [String: MTLTexture] = [:]
    private var maskCache: [String: MTLTexture] = [:]
    private let cacheQueue = DispatchQueue(label: "com.zonesystem.cache", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            print("Failed to create Metal device")
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        // Create CIContext with Metal
        self.ciContext = CIContext(mtlDevice: device, options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .workingFormat: NSNumber(value: CIFormat.RGBAf.rawValue)
        ])
        
        // Initialize subsystems
        self.layerManager = LayerManager(device: device, commandQueue: commandQueue)
        self.luminosityMaskEngine = LuminosityMaskEngine(device: device, commandQueue: commandQueue)
        self.dodgeBurnTool = DodgeBurnTool(device: device, commandQueue: commandQueue)
        self.curveEditor = CurveEditor(device: device, commandQueue: commandQueue)
        self.annotationOverlay = AnnotationOverlay(device: device, commandQueue: commandQueue)
        self.filmGrainSimulator = FilmGrainSimulator(device: device, commandQueue: commandQueue)
        
        // Setup compute pipelines
        setupComputePipelines()
    }
    
    // MARK: - Pipeline Setup
    
    private func setupComputePipelines() {
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.main) else {
            print("Failed to load Metal library")
            return
        }
        
        // Create compute pipeline states for each kernel
        let kernelNames = [
            "generateLuminosityMask",
            "generateZoneMasks",
            "applyDodgeBurn",
            "generateBrushPattern",
            "applyCharacteristicCurve",
            "applyPaperGradeCurve",
            "applyFilmGrain",
            "applySplitGrade",
            "applyVignetting",
            "convertToBlackAndWhite",
            "applyUnsharpMask",
            "blendLayers",
            "gaussianBlurHorizontal",
            "gaussianBlurVertical",
            "analyzeZones"
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
    
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    
    // MARK: - Image Loading
    
    public func loadImage(from url: URL) async throws {
        processingState = .processing(progress: 0.1)
        
        defer { processingState = .completed }
        
        // Load image data
        let imageData = try Data(contentsOf: url)
        
        // Try to load as RAW first
        if let rawFilter = CIFilter(imageData: imageData, options: nil) {
            if var image = rawFilter.outputImage {
                // Apply RAW processing
                processingState = .processing(progress: 0.3)
                
                // Convert to working color space
                image = image.transformed(by: .identity)
                
                // Store original
                layerManager.setOriginalImage(image)
                currentImage = image
                
                // Generate preview
                await generatePreview()
                
                // Clear history
                historyStack.removeAll()
                historyIndex = -1
                
                // Save initial state
                saveState()
                
                return
            }
        }
        
        // Fall back to regular image loading
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw EditorError.failedToLoadImage
        }
        
        let image = CIImage(cgImage: cgImage)
        layerManager.setOriginalImage(image)
        currentImage = image
        
        await generatePreview()
        
        saveState()
    }
    
    public func loadImage(_ image: UIImage) async {
        processingState = .processing(progress: 0.1)
        
        defer { processingState = .completed }
        
        guard let cgImage = image.cgImage else {
            processingState = .failed(error: "Failed to get CGImage")
            return
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        layerManager.setOriginalImage(ciImage)
        currentImage = ciImage
        
        await generatePreview()
        saveState()
    }
    
    // MARK: - Processing Pipeline
    
    public func processImage() async {
        guard let originalImage = layerManager.originalImage else { return }
        
        processingState = .processing(progress: 0.0)
        
        var processedImage = originalImage
        
        // Step 1: B&W Conversion
        processingState = .processing(progress: 0.1)
        processedImage = await applyBWConversion(to: processedImage)
        
        // Step 2: Tonal Curves
        processingState = .processing(progress: 0.25)
        processedImage = await applyTonalCurves(to: processedImage)
        
        // Step 3: Split Grade
        processingState = .processing(progress: 0.35)
        if splitGradeSettings.useMask {
            processedImage = await applySplitGrade(to: processedImage)
        }
        
        // Step 4: Dodge & Burn
        processingState = .processing(progress: 0.5)
        processedImage = await applyDodgeBurn(to: processedImage)
        
        // Step 5: Luminosity Mask Adjustments
        processingState = .processing(progress: 0.6)
        processedImage = await applyLuminosityMaskAdjustments(to: processedImage)
        
        // Step 6: Sharpening
        processingState = .processing(progress: 0.7)
        if sharpeningSettings.enabled {
            processedImage = await applySharpening(to: processedImage)
        }
        
        // Step 7: Vignetting
        processingState = .processing(progress: 0.8)
        if vignetteSettings.enabled {
            processedImage = await applyVignetting(to: processedImage)
        }
        
        // Step 8: Film Grain
        processingState = .processing(progress: 0.9)
        if filmGrainSettings.enabled {
            processedImage = await applyFilmGrain(to: processedImage)
        }
        
        // Step 9: Annotations
        processingState = .processing(progress: 0.95)
        processedImage = await applyAnnotations(to: processedImage)
        
        currentImage = processedImage
        await generatePreview()
        
        processingState = .completed
    }
    
    // MARK: - Individual Processing Steps
    
    private func applyBWConversion(to image: CIImage) async -> CIImage {
        guard let pipelineState = computePipelineStates["convertToBlackAndWhite"] else {
            return image
        }
        
        let filterWeights = bwSettings.filterWeights
        
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
                
                var filterColor = filterWeights
                var contrast = self.bwSettings.contrast
                var brightness = self.bwSettings.brightness
                
                computeEncoder.setBytes(&filterColor, length: MemoryLayout<SIMD3<Float>>.size, index: 0)
                computeEncoder.setBytes(&contrast, length: MemoryLayout<Float>.size, index: 1)
                computeEncoder.setBytes(&brightness, length: MemoryLayout<Float>.size, index: 2)
                
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
    
    private func applyTonalCurves(to image: CIImage) async -> CIImage {
        guard let pipelineState = computePipelineStates["applyCharacteristicCurve"] else {
            return image
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    continuation.resume(returning: image)
                    return
                }
                
                let inputTexture = self.ciImageToTexture(image)
                let outputTexture = self.createTexture(size: image.extent.size)
                
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder.setTexture(inputTexture, index: 0)
                computeEncoder.setTexture(outputTexture, index: 1)
                
                var blackPoint = self.curveSettings.blackPoint
                var whitePoint = self.curveSettings.whitePoint
                var gamma = self.curveSettings.gamma
                var toe = self.curveSettings.toe
                var shoulder = self.curveSettings.shoulder
                var contrast = self.curveSettings.contrast
                
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
    
    private func applySplitGrade(to image: CIImage) async -> CIImage {
        return await filmGrainSimulator.applySplitGrade(
            to: image,
            settings: splitGradeSettings,
            mask: luminosityMaskEngine.getMask(for: .lights)
        )
    }
    
    private func applyDodgeBurn(to image: CIImage) async -> CIImage {
        return await dodgeBurnTool.apply(to: image)
    }
    
    private func applyLuminosityMaskAdjustments(to image: CIImage) async -> CIImage {
        // Apply adjustments based on luminosity masks
        var result = image
        
        // Example: Slightly brighten darks
        if let darksMask = luminosityMaskEngine.getMask(for: .darks) {
            result = await applyMaskAdjustment(
                to: result,
                mask: darksMask,
                adjustment: 0.1
            )
        }
        
        return result
    }
    
    private func applyMaskAdjustment(to image: CIImage, mask: MTLTexture, adjustment: Float) async -> CIImage {
        // Implementation for mask-based adjustment
        return image
    }
    
    private func applySharpening(to image: CIImage) async -> CIImage {
        guard let pipelineState = computePipelineStates["applyUnsharpMask"] else {
            return image
        }
        
        // First create blurred version for unsharp mask
        let blurredImage = await applyGaussianBlur(to: image, sigma: sharpeningSettings.radius)
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    continuation.resume(returning: image)
                    return
                }
                
                let inputTexture = self.ciImageToTexture(image)
                let blurredTexture = self.ciImageToTexture(blurredImage)
                let outputTexture = self.createTexture(size: image.extent.size)
                
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder.setTexture(inputTexture, index: 0)
                computeEncoder.setTexture(blurredTexture, index: 1)
                computeEncoder.setTexture(outputTexture, index: 2)
                
                var amount = self.sharpeningSettings.amount
                var threshold = self.sharpeningSettings.threshold
                
                computeEncoder.setBytes(&amount, length: MemoryLayout<Float>.size, index: 0)
                computeEncoder.setBytes(&threshold, length: MemoryLayout<Float>.size, index: 1)
                
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
    
    private func applyGaussianBlur(to image: CIImage, sigma: Float) async -> CIImage {
        // Use Core Image for Gaussian blur
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = image
        blurFilter.radius = sigma * 10
        return blurFilter.outputImage ?? image
    }
    
    private func applyVignetting(to image: CIImage) async -> CIImage {
        guard let pipelineState = computePipelineStates["applyVignetting"] else {
            return image
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    continuation.resume(returning: image)
                    return
                }
                
                let inputTexture = self.ciImageToTexture(image)
                let outputTexture = self.createTexture(size: image.extent.size)
                
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder.setTexture(inputTexture, index: 0)
                computeEncoder.setTexture(outputTexture, index: 1)
                
                var intensity = self.vignetteSettings.intensity
                var radius = self.vignetteSettings.radius
                var feather = self.vignetteSettings.feather
                var center = SIMD2<Float>(
                    Float(self.vignetteSettings.center.x),
                    Float(self.vignetteSettings.center.y)
                )
                
                computeEncoder.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)
                computeEncoder.setBytes(&radius, length: MemoryLayout<Float>.size, index: 1)
                computeEncoder.setBytes(&feather, length: MemoryLayout<Float>.size, index: 2)
                computeEncoder.setBytes(&center, length: MemoryLayout<SIMD2<Float>>.size, index: 3)
                
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
    
    private func applyFilmGrain(to image: CIImage) async -> CIImage {
        return await filmGrainSimulator.apply(to: image, settings: filmGrainSettings)
    }
    
    private func applyAnnotations(to image: CIImage) async -> CIImage {
        return await annotationOverlay.apply(to: image)
    }
    
    // MARK: - Preview Generation
    
    private func generatePreview() async {
        guard let currentImage = currentImage else { return }
        
        // Generate smaller preview for UI
        let previewSize: CGFloat = 2048
        let scale = min(previewSize / currentImage.extent.width,
                       previewSize / currentImage.extent.height)
        
        if scale < 1.0 {
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let scaledImage = currentImage.transformed(by: transform)
            
            if let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) {
                previewImage = UIImage(cgImage: cgImage)
            }
        } else {
            if let cgImage = ciContext.createCGImage(currentImage, from: currentImage.extent) {
                previewImage = UIImage(cgImage: cgImage)
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
        
        // Render CIImage to texture
        ciContext.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: colorSpace)
        
        return texture
    }
    
    private func createTexture(size: CGSize, pixelFormat: MTLPixelFormat = .rgba32Float) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
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
            .colorSpace: colorSpace
        ])
    }
    
    // MARK: - Undo/Redo
    
    public func saveState() {
        let state = EditState(
            bwSettings: bwSettings,
            curveSettings: curveSettings,
            filmGrainSettings: filmGrainSettings,
            vignetteSettings: vignetteSettings,
            sharpeningSettings: sharpeningSettings,
            splitGradeSettings: splitGradeSettings
        )
        
        // Remove future history if we're not at the end
        if historyIndex < historyStack.count - 1 {
            historyStack.removeSubrange((historyIndex + 1)...)
        }
        
        historyStack.append(state)
        
        // Limit history size
        if historyStack.count > maxHistorySize {
            historyStack.removeFirst()
        } else {
            historyIndex += 1
        }
        
        // Register with undo manager
        undoManager.registerUndo(withTarget: self) { engine in
            engine.undo()
        }
    }
    
    public func undo() {
        guard historyIndex > 0 else { return }
        
        historyIndex -= 1
        let state = historyStack[historyIndex]
        restoreState(state)
        
        undoManager.registerUndo(withTarget: self) { engine in
            engine.redo()
        }
    }
    
    public func redo() {
        guard historyIndex < historyStack.count - 1 else { return }
        
        historyIndex += 1
        let state = historyStack[historyIndex]
        restoreState(state)
        
        undoManager.registerUndo(withTarget: self) { engine in
            engine.undo()
        }
    }
    
    private func restoreState(_ state: EditState) {
        bwSettings = state.bwSettings
        curveSettings = state.curveSettings
        filmGrainSettings = state.filmGrainSettings
        vignetteSettings = state.vignetteSettings
        sharpeningSettings = state.sharpeningSettings
        splitGradeSettings = state.splitGradeSettings
        
        Task {
            await processImage()
        }
    }
    
    public var canUndo: Bool {
        historyIndex > 0
    }
    
    public var canRedo: Bool {
        historyIndex < historyStack.count - 1
    }
    
    // MARK: - Export
    
    public func export(with settings: ExportSettings) async throws -> Data {
        guard let currentImage = currentImage else {
            throw EditorError.noImageLoaded
        }
        
        processingState = .processing(progress: 0.0)
        
        defer { processingState = .completed }
        
        // Apply resolution scaling if needed
        var exportImage = currentImage
        
        switch settings.resolution {
        case .half:
            exportImage = exportImage.transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
        case .quarter:
            exportImage = exportImage.transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))
        default:
            break
        }
        
        // Create CGImage
        guard let cgImage = ciContext.createCGImage(exportImage, from: exportImage.extent) else {
            throw EditorError.exportFailed
        }
        
        // Export based on format
        let data: Data
        
        switch settings.format {
        case .tiff:
            let mutableData = NSMutableData()
            guard let imageDestination = CGImageDestinationCreateWithData(
                mutableData,
                UTType.tiff.identifier as CFString,
                1,
                nil
            ) else {
                throw EditorError.exportFailed
            }
            
            let properties: [String: Any] = [
                kCGImageDestinationLossyCompressionQuality as String: settings.quality
            ]
            CGImageDestinationAddImage(imageDestination, cgImage, properties as CFDictionary)
            CGImageDestinationFinalize(imageDestination)
            data = mutableData as Data
            
        case .jpeg:
            guard let jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: settings.quality) else {
                throw EditorError.exportFailed
            }
            data = jpegData
            
        case .png:
            guard let pngData = UIImage(cgImage: cgImage).pngData() else {
                throw EditorError.exportFailed
            }
            data = pngData
            
        case .heic:
            let mutableData = NSMutableData()
            guard let imageDestination = CGImageDestinationCreateWithData(
                mutableData,
                UTType.heic.identifier as CFString,
                1,
                nil
            ) else {
                throw EditorError.exportFailed
            }
            
            let properties: [String: Any] = [
                kCGImageDestinationLossyCompressionQuality as String: settings.quality
            ]
            CGImageDestinationAddImage(imageDestination, cgImage, properties as CFDictionary)
            CGImageDestinationFinalize(imageDestination)
            data = mutableData as Data
        }
        
        return data
    }
    
    // MARK: - Reset
    
    public func resetAllSettings() {
        bwSettings = BWConversionSettings()
        curveSettings = TonalCurveSettings()
        filmGrainSettings = FilmGrainSettings()
        vignetteSettings = VignetteSettings()
        sharpeningSettings = SharpeningSettings()
        splitGradeSettings = SplitGradeSettings()
        
        dodgeBurnTool.clearStrokes()
        annotationOverlay.clearAnnotations()
        luminosityMaskEngine.clearMasks()
        
        Task {
            await processImage()
            saveState()
        }
    }
}

// MARK: - Edit State

private struct EditState {
    let bwSettings: BWConversionSettings
    let curveSettings: TonalCurveSettings
    let filmGrainSettings: FilmGrainSettings
    let vignetteSettings: VignetteSettings
    let sharpeningSettings: SharpeningSettings
    let splitGradeSettings: SplitGradeSettings
}

// MARK: - Errors

public enum EditorError: Error {
    case failedToLoadImage
    case noImageLoaded
    case exportFailed
    case processingFailed
    case metalNotAvailable
}
