//
//  LuminosityMaskEngine.swift
//  Zone System Master - Photo Editor Engine
//  Luminosity mask generation and operations
//

import Foundation
import Metal
import CoreImage

// MARK: - Luminosity Mask

public struct LuminosityMask: Identifiable {
    public let id = UUID()
    public var name: String
    public var type: LuminosityMaskType
    public var texture: MTLTexture?
    public var minZone: Float
    public var maxZone: Float
    public var feather: Float
    public var isInverted: Bool
    
    public init(
        name: String,
        type: LuminosityMaskType,
        texture: MTLTexture? = nil,
        minZone: Float,
        maxZone: Float,
        feather: Float = 0.1,
        isInverted: Bool = false
    ) {
        self.name = name
        self.type = type
        self.texture = texture
        self.minZone = minZone
        self.maxZone = maxZone
        self.feather = feather
        self.isInverted = isInverted
    }
    
    /// Create a copy with new parameters
    public func copy(
        name: String? = nil,
        minZone: Float? = nil,
        maxZone: Float? = nil,
        feather: Float? = nil,
        isInverted: Bool? = nil
    ) -> LuminosityMask {
        LuminosityMask(
            name: name ?? self.name,
            type: type,
            texture: nil, // Texture needs to be regenerated
            minZone: minZone ?? self.minZone,
            maxZone: maxZone ?? self.maxZone,
            feather: feather ?? self.feather,
            isInverted: isInverted ?? self.isInverted
        )
    }
}

// MARK: - Mask Operation

public enum MaskOperation {
    case intersect // AND operation
    case union     // OR operation
    case subtract  // Subtract one mask from another
    case invert    // Invert mask
    case feather(Float) // Apply feathering
    case expand(Float)  // Expand mask by amount
    case contract(Float) // Contract mask by amount
}

// MARK: - Luminosity Mask Engine

public final class LuminosityMaskEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var masks: [LuminosityMask] = []
    @Published public var selectedMaskID: UUID?
    @Published public var isGenerating = false
    
    // MARK: - Metal Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineStates: [String: MTLComputePipelineState] = [:]
    
    // MARK: - Source Image
    
    private var sourceImage: CIImage?
    private var sourceTexture: MTLTexture?
    
    // MARK: - Cache
    
    private var maskCache: [String: MTLTexture] = [:]
    private let cacheQueue = DispatchQueue(label: "com.zonesystem.maskcache", qos: .userInitiated)
    
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
            "generateLuminosityMask",
            "generateZoneMasks",
            "gaussianBlurHorizontal",
            "gaussianBlurVertical"
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
    
    // MARK: - Source Image Management
    
    public func setSourceImage(_ image: CIImage) {
        sourceImage = image
        sourceTexture = nil // Will be created on demand
        clearMasks()
    }
    
    private func getSourceTexture() -> MTLTexture? {
        if let texture = sourceTexture {
            return texture
        }
        
        guard let image = sourceImage else { return nil }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: Int(image.extent.width),
            height: Int(image.extent.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        // Render CIImage to texture
        let ciContext = CIContext(mtlDevice: device)
        ciContext.render(image, to: texture, commandBuffer: nil, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceGray())
        
        sourceTexture = texture
        return texture
    }
    
    // MARK: - Mask Generation
    
    /// Generate all standard zone masks
    public func generateAllZoneMasks() async {
        guard let sourceTexture = getSourceTexture() else { return }
        
        isGenerating = true
        defer { isGenerating = false }
        
        await withTaskGroup(of: Void.self) { group in
            for maskType in LuminosityMaskType.allCases {
                group.addTask {
                    await self.generateMask(type: maskType, from: sourceTexture)
                }
            }
        }
    }
    
    /// Generate a specific mask type
    public func generateMask(type: LuminosityMaskType, customName: String? = nil) async {
        guard let sourceTexture = getSourceTexture() else { return }
        await generateMask(type: type, from: sourceTexture, customName: customName)
    }
    
    private func generateMask(type: LuminosityMaskType, from sourceTexture: MTLTexture, customName: String? = nil) async {
        guard let pipelineState = computePipelineStates["generateLuminosityMask"] else { return }
        
        let zoneRange = type.zoneRange
        
        // Create output texture
        let outputTexture = createMaskTexture(size: CGSize(
            width: CGFloat(sourceTexture.width),
            height: CGFloat(sourceTexture.height)
        ))
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    continuation.resume()
                    return
                }
                
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder.setTexture(sourceTexture, index: 0)
                computeEncoder.setTexture(outputTexture, index: 1)
                
                var minZone = zoneRange.lowerBound
                var maxZone = zoneRange.upperBound
                var feather: Float = 0.1
                
                computeEncoder.setBytes(&minZone, length: MemoryLayout<Float>.size, index: 0)
                computeEncoder.setBytes(&maxZone, length: MemoryLayout<Float>.size, index: 1)
                computeEncoder.setBytes(&feather, length: MemoryLayout<Float>.size, index: 2)
                
                let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                let threadGroups = MTLSize(
                    width: (sourceTexture.width + 15) / 16,
                    height: (sourceTexture.height + 15) / 16,
                    depth: 1
                )
                
                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                computeEncoder.endEncoding()
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                continuation.resume()
            }
        }
        
        // Create mask object
        let mask = LuminosityMask(
            name: customName ?? type.rawValue,
            type: type,
            texture: outputTexture,
            minZone: zoneRange.lowerBound,
            maxZone: zoneRange.upperBound,
            feather: 0.1
        )
        
        await MainActor.run {
            // Remove existing mask of same type
            masks.removeAll { $0.type == type }
            masks.append(mask)
        }
    }
    
    /// Generate custom mask with specific zone range
    public func generateCustomMask(
        name: String,
        minZone: Float,
        maxZone: Float,
        feather: Float = 0.1
    ) async -> LuminosityMask? {
        guard let sourceTexture = getSourceTexture() else { return nil }
        guard let pipelineState = computePipelineStates["generateLuminosityMask"] else { return nil }
        
        let outputTexture = createMaskTexture(size: CGSize(
            width: CGFloat(sourceTexture.width),
            height: CGFloat(sourceTexture.height)
        ))
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
                      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                    continuation.resume()
                    return
                }
                
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder.setTexture(sourceTexture, index: 0)
                computeEncoder.setTexture(outputTexture, index: 1)
                
                var minZ = minZone
                var maxZ = maxZone
                var feat = feather
                
                computeEncoder.setBytes(&minZ, length: MemoryLayout<Float>.size, index: 0)
                computeEncoder.setBytes(&maxZ, length: MemoryLayout<Float>.size, index: 1)
                computeEncoder.setBytes(&feat, length: MemoryLayout<Float>.size, index: 2)
                
                let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                let threadGroups = MTLSize(
                    width: (sourceTexture.width + 15) / 16,
                    height: (sourceTexture.height + 15) / 16,
                    depth: 1
                )
                
                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                computeEncoder.endEncoding()
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                continuation.resume()
            }
        }
        
        let mask = LuminosityMask(
            name: name,
            type: .midtones, // Generic type for custom
            texture: outputTexture,
            minZone: minZone,
            maxZone: maxZone,
            feather: feather
        )
        
        await MainActor.run {
            masks.append(mask)
        }
        
        return mask
    }
    
    // MARK: - Mask Operations
    
    /// Apply operation between two masks
    public func combineMasks(
        _ mask1: LuminosityMask,
        _ mask2: LuminosityMask,
        operation: MaskOperation
    ) async -> LuminosityMask? {
        guard let texture1 = mask1.texture,
              let texture2 = mask2.texture else { return nil }
        
        let outputTexture = createMaskTexture(size: CGSize(
            width: CGFloat(texture1.width),
            height: CGFloat(texture1.height)
        ))
        
        // Perform operation using Metal
        // This would require a custom shader for mask operations
        
        let resultMask = LuminosityMask(
            name: "\(mask1.name) + \(mask2.name)",
            type: .midtones,
            texture: outputTexture,
            minZone: min(mask1.minZone, mask2.minZone),
            maxZone: max(mask1.maxZone, mask2.maxZone),
            feather: max(mask1.feather, mask2.feather)
        )
        
        await MainActor.run {
            masks.append(resultMask)
        }
        
        return resultMask
    }
    
    /// Invert a mask
    public func invertMask(_ mask: LuminosityMask) -> LuminosityMask {
        return mask.copy(
            name: "\(mask.name) Inverted",
            isInverted: !mask.isInverted
        )
    }
    
    /// Apply feathering to mask
    public func featherMask(_ mask: LuminosityMask, amount: Float) async -> LuminosityMask? {
        guard let sourceTexture = mask.texture else { return nil }
        
        let outputTexture = createMaskTexture(size: CGSize(
            width: CGFloat(sourceTexture.width),
            height: CGFloat(sourceTexture.height)
        ))
        
        // Apply Gaussian blur for feathering
        await applyGaussianBlur(
            input: sourceTexture,
            output: outputTexture,
            sigma: amount * 10
        )
        
        return mask.copy(
            name: "\(mask.name) Feathered",
            feather: amount
        )
    }
    
    // MARK: - Gaussian Blur
    
    private func applyGaussianBlur(input: MTLTexture, output: MTLTexture, sigma: Float) async {
        guard let horizontalPipeline = computePipelineStates["gaussianBlurHorizontal"],
              let verticalPipeline = computePipelineStates["gaussianBlurVertical"] else { return }
        
        // Intermediate texture
        let intermediateTexture = createMaskTexture(size: CGSize(
            width: CGFloat(input.width),
            height: CGFloat(input.height)
        ))
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
                    continuation.resume()
                    return
                }
                
                // Horizontal pass
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    computeEncoder.setComputePipelineState(horizontalPipeline)
                    computeEncoder.setTexture(input, index: 0)
                    computeEncoder.setTexture(intermediateTexture, index: 1)
                    
                    var sigmaH = sigma
                    computeEncoder.setBytes(&sigmaH, length: MemoryLayout<Float>.size, index: 0)
                    
                    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                    let threadGroups = MTLSize(
                        width: (input.width + 15) / 16,
                        height: (input.height + 15) / 16,
                        depth: 1
                    )
                    
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    computeEncoder.endEncoding()
                }
                
                // Vertical pass
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    computeEncoder.setComputePipelineState(verticalPipeline)
                    computeEncoder.setTexture(intermediateTexture, index: 0)
                    computeEncoder.setTexture(output, index: 1)
                    
                    var sigmaV = sigma
                    computeEncoder.setBytes(&sigmaV, length: MemoryLayout<Float>.size, index: 0)
                    
                    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
                    let threadGroups = MTLSize(
                        width: (input.width + 15) / 16,
                        height: (input.height + 15) / 16,
                        depth: 1
                    )
                    
                    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                    computeEncoder.endEncoding()
                }
                
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Mask Access
    
    public func getMask(for type: LuminosityMaskType) -> MTLTexture? {
        masks.first { $0.type == type }?.texture
    }
    
    public func getMask(byID id: UUID) -> LuminosityMask? {
        masks.first { $0.id == id }
    }
    
    public func getMask(named name: String) -> LuminosityMask? {
        masks.first { $0.name == name }
    }
    
    // MARK: - Mask Visualization
    
    public func getMaskPreview(for mask: LuminosityMask, size: CGSize) -> UIImage? {
        guard let texture = mask.texture else { return nil }
        
        let ciImage = CIImage(mtlTexture: texture, options: nil)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(
            ciImage!,
            from: CGRect(origin: .zero, size: size)
        ) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Texture Helpers
    
    private func createMaskTexture(size: CGSize) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Failed to create mask texture")
        }
        
        return texture
    }
    
    // MARK: - Mask Management
    
    public func removeMask(id: UUID) {
        masks.removeAll { $0.id == id }
    }
    
    public func removeAllMasks() {
        masks.removeAll()
        maskCache.removeAll()
    }
    
    public func clearMasks() {
        masks.removeAll()
        sourceTexture = nil
        maskCache.removeAll()
    }
    
    public func renameMask(id: UUID, to newName: String) {
        if let index = masks.firstIndex(where: { $0.id == id }) {
            masks[index].name = newName
        }
    }
    
    // MARK: - Zone Analysis
    
    public func analyzeZones() async -> [Float] {
        guard let sourceTexture = getSourceTexture() else { return [] }
        
        // This would use the analyzeZones kernel
        // For now, return placeholder data
        return Array(repeating: 0, count: 11)
    }
    
    // MARK: - Presets
    
    public func saveMaskPreset(name: String) -> MaskPreset {
        return MaskPreset(
            name: name,
            masks: masks.map { MaskSnapshot(from: $0) }
        )
    }
    
    public func applyMaskPreset(_ preset: MaskPreset) {
        // Regenerate masks based on preset parameters
        Task {
            for snapshot in preset.masks {
                await generateCustomMask(
                    name: snapshot.name,
                    minZone: snapshot.minZone,
                    maxZone: snapshot.maxZone,
                    feather: snapshot.feather
                )
            }
        }
    }
}

// MARK: - Mask Preset

public struct MaskPreset: Codable, Identifiable {
    public let id = UUID()
    public var name: String
    public var masks: [MaskSnapshot]
    public var createdAt: Date
    
    public init(name: String, masks: [MaskSnapshot]) {
        self.name = name
        self.masks = masks
        self.createdAt = Date()
    }
}

// MARK: - Mask Snapshot

public struct MaskSnapshot: Codable {
    public let name: String
    public let minZone: Float
    public let maxZone: Float
    public let feather: Float
    public let isInverted: Bool
    
    public init(from mask: LuminosityMask) {
        self.name = mask.name
        self.minZone = mask.minZone
        self.maxZone = mask.maxZone
        self.feather = mask.feather
        self.isInverted = mask.isInverted
    }
}

// MARK: - Luminosity Mask Engine Extensions

extension LuminosityMaskEngine {
    
    /// Quick access to lights mask
    public var lightsMask: MTLTexture? {
        getMask(for: .lights)
    }
    
    /// Quick access to darks mask
    public var darksMask: MTLTexture? {
        getMask(for: .darks)
    }
    
    /// Quick access to midtones mask
    public var midtonesMask: MTLTexture? {
        getMask(for: .midtones)
    }
    
    /// Check if masks are available
    public var hasMasks: Bool {
        !masks.isEmpty
    }
    
    /// Get mask count
    public var maskCount: Int {
        masks.count
    }
    
    /// Get visible mask count (masks with valid textures)
    public var validMaskCount: Int {
        masks.filter { $0.texture != nil }.count
    }
    
    /// Create zone-specific mask (Zone III for shadows with detail, etc.)
    public func createZoneMask(zone: Int, feather: Float = 0.1) async -> LuminosityMask? {
        let zoneFloat = Float(zone)
        return await generateCustomMask(
            name: "Zone \(zone)",
            minZone: zoneFloat - 0.5,
            maxZone: zoneFloat + 0.5,
            feather: feather
        )
    }
    
    /// Create expanded lights mask (Zone VI-X)
    public func createExpandedLightsMask() async -> LuminosityMask? {
        return await generateCustomMask(
            name: "Expanded Lights",
            minZone: 5.5,
            maxZone: 10.0,
            feather: 0.2
        )
    }
    
    /// Create expanded darks mask (Zone 0-IV)
    public func createExpandedDarksMask() async -> LuminosityMask? {
        return await generateCustomMask(
            name: "Expanded Darks",
            minZone: 0.0,
            maxZone: 4.5,
            feather: 0.2
        )
    }
    
    /// Create narrow midtones mask (Zone IV-VI)
    public func createNarrowMidtonesMask() async -> LuminosityMask? {
        return await generateCustomMask(
            name: "Narrow Midtones",
            minZone: 3.5,
            maxZone: 6.5,
            feather: 0.15
        )
    }
}
