//
//  LayerManager.swift
//  Zone System Master - Photo Editor Engine
//  Non-destructive layer management system
//

import Foundation
import Metal
import CoreImage

// MARK: - Layer Types

public enum LayerType: String, CaseIterable, Identifiable {
    case adjustment = "Adjustment"
    case mask = "Mask"
    case dodgeBurn = "Dodge & Burn"
    case annotation = "Annotation"
    case grain = "Film Grain"
    case vignette = "Vignette"
    
    public var id: String { rawValue }
}

// MARK: - Layer Protocol

public protocol Layer: Identifiable, Equatable {
    var id: UUID { get }
    var name: String { get set }
    var type: LayerType { get }
    var isVisible: Bool { get set }
    var opacity: Float { get set }
    var blendMode: BlendMode { get set }
    
    func apply(to image: CIImage, using context: CIContext) -> CIImage
}

// MARK: - Blend Modes

public enum BlendMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case multiply = "Multiply"
    case screen = "Screen"
    case overlay = "Overlay"
    case softLight = "Soft Light"
    case hardLight = "Hard Light"
    case colorDodge = "Color Dodge"
    case colorBurn = "Color Burn"
    case darken = "Darken"
    case lighten = "Lighten"
    case difference = "Difference"
    case exclusion = "Exclusion"
    
    public var id: String { rawValue }
    
    public var ciFilterName: String? {
        switch self {
        case .multiply: return "CIMultiplyBlendMode"
        case .screen: return "CIScreenBlendMode"
        case .overlay: return "CIOverlayBlendMode"
        case .softLight: return "CISoftLightBlendMode"
        case .hardLight: return "CIHardLightBlendMode"
        case .colorDodge: return "CIColorDodgeBlendMode"
        case .colorBurn: return "CIColorBurnBlendMode"
        case .darken: return "CIDarkenBlendMode"
        case .lighten: return "CILightenBlendMode"
        case .difference: return "CIDifferenceBlendMode"
        case .exclusion: return "CIExclusionBlendMode"
        default: return nil
        }
    }
}

// MARK: - Adjustment Layer

public struct AdjustmentLayer: Layer {
    public let id = UUID()
    public var name: String
    public let type: LayerType = .adjustment
    public var isVisible: Bool = true
    public var opacity: Float = 1.0
    public var blendMode: BlendMode = .normal
    
    public var adjustmentType: AdjustmentType
    public var parameters: [String: Any]
    
    public init(
        name: String,
        adjustmentType: AdjustmentType,
        parameters: [String: Any] = [:]
    ) {
        self.name = name
        self.adjustmentType = adjustmentType
        self.parameters = parameters
    }
    
    public func apply(to image: CIImage, using context: CIContext) -> CIImage {
        guard isVisible else { return image }
        return adjustmentType.apply(to: image, parameters: parameters, context: context)
    }
    
    public static func == (lhs: AdjustmentLayer, rhs: AdjustmentLayer) -> Bool {
        lhs.id == rhs.id
    }
}

public enum AdjustmentType {
    case brightness(Float)
    case contrast(Float)
    case exposure(Float)
    case highlights(Float)
    case shadows(Float)
    case saturation(Float)
    case vibrance(Float)
    case temperature(Float)
    case tint(Float)
    case levels(black: Float, gamma: Float, white: Float)
    case curves(controlPoints: [CGPoint])
    case colorBalance(shadows: CIColor, midtones: CIColor, highlights: CIColor)
    
    func apply(to image: CIImage, parameters: [String: Any], context: CIContext) -> CIImage {
        switch self {
        case .brightness(let value):
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.brightness = value
            return filter.outputImage ?? image
            
        case .contrast(let value):
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.contrast = value
            return filter.outputImage ?? image
            
        case .exposure(let value):
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = value
            return filter.outputImage ?? image
            
        case .highlights(let value):
            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = image
            filter.highlightAmount = value
            return filter.outputImage ?? image
            
        case .shadows(let value):
            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = image
            filter.shadowAmount = value
            return filter.outputImage ?? image
            
        case .saturation(let value):
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.saturation = value
            return filter.outputImage ?? image
            
        default:
            return image
        }
    }
}

// MARK: - Mask Layer

public struct MaskLayer: Layer {
    public let id = UUID()
    public var name: String
    public let type: LayerType = .mask
    public var isVisible: Bool = true
    public var opacity: Float = 1.0
    public var blendMode: BlendMode = .normal
    
    public var maskImage: CIImage?
    public var inverted: Bool = false
    public var feather: Float = 0.0
    
    public init(
        name: String,
        maskImage: CIImage? = nil,
        inverted: Bool = false,
        feather: Float = 0.0
    ) {
        self.name = name
        self.maskImage = maskImage
        self.inverted = inverted
        self.feather = feather
    }
    
    public func apply(to image: CIImage, using context: CIContext) -> CIImage {
        guard isVisible, let mask = maskImage else { return image }
        
        var finalMask = mask
        
        if inverted {
            finalMask = finalMask.applyingFilter("CIColorInvert")
        }
        
        if feather > 0 {
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = finalMask
            blurFilter.radius = feather * 10
            finalMask = blurFilter.outputImage ?? finalMask
        }
        
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = image
        blendFilter.maskImage = finalMask
        blendFilter.backgroundImage = CIImage(color: .clear)
        
        return blendFilter.outputImage ?? image
    }
    
    public static func == (lhs: MaskLayer, rhs: MaskLayer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Layer Manager

public final class LayerManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var layers: [any Layer] = []
    @Published public var selectedLayerID: UUID?
    
    // MARK: - Original Image
    
    public private(set) var originalImage: CIImage?
    
    // MARK: - Metal Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    
    // MARK: - Caching
    
    private var processedCache: [UUID: CIImage] = [:]
    private var needsUpdate = true
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpaceCreateDeviceGray(),
            .outputColorSpace: CGColorSpaceCreateDeviceGray()
        ])
    }
    
    // MARK: - Original Image Management
    
    public func setOriginalImage(_ image: CIImage) {
        originalImage = image
        clearCache()
        needsUpdate = true
    }
    
    // MARK: - Layer Management
    
    public func addLayer(_ layer: any Layer) {
        layers.append(layer)
        needsUpdate = true
        objectWillChange.send()
    }
    
    public func insertLayer(_ layer: any Layer, at index: Int) {
        guard index >= 0 && index <= layers.count else { return }
        layers.insert(layer, at: index)
        needsUpdate = true
        objectWillChange.send()
    }
    
    public func removeLayer(withID id: UUID) {
        layers.removeAll { $0.id == id }
        processedCache.removeValue(forKey: id)
        needsUpdate = true
        objectWillChange.send()
    }
    
    public func moveLayer(from source: IndexSet, to destination: Int) {
        layers.move(fromOffsets: source, toOffset: destination)
        needsUpdate = true
        objectWillChange.send()
    }
    
    public func updateLayer(_ layer: any Layer) {
        if let index = layers.firstIndex(where: { $0.id == layer.id }) {
            // Since we can't directly assign to a protocol type in an array,
            // we need to handle this differently based on layer type
            layers[index] = layer
            processedCache.removeValue(forKey: layer.id)
            needsUpdate = true
            objectWillChange.send()
        }
    }
    
    public func toggleLayerVisibility(id: UUID) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            // Create mutable copy based on type
            switch layers[index].type {
            case .adjustment:
                if var layer = layers[index] as? AdjustmentLayer {
                    layer.isVisible.toggle()
                    layers[index] = layer
                }
            case .mask:
                if var layer = layers[index] as? MaskLayer {
                    layer.isVisible.toggle()
                    layers[index] = layer
                }
            default:
                break
            }
            needsUpdate = true
            objectWillChange.send()
        }
    }
    
    public func duplicateLayer(id: UUID) {
        guard let layer = layers.first(where: { $0.id == id }) else { return }
        
        // Create duplicate based on type
        switch layer.type {
        case .adjustment:
            if let adjLayer = layer as? AdjustmentLayer {
                var newLayer = adjLayer
                newLayer.name = "\(adjLayer.name) Copy"
                // We need a new ID, but since it's a struct with let id, we recreate it
                let duplicate = AdjustmentLayer(
                    name: "\(adjLayer.name) Copy",
                    adjustmentType: adjLayer.adjustmentType,
                    parameters: adjLayer.parameters
                )
                layers.append(duplicate)
            }
        case .mask:
            if let maskLayer = layer as? MaskLayer {
                let duplicate = MaskLayer(
                    name: "\(maskLayer.name) Copy",
                    maskImage: maskLayer.maskImage,
                    inverted: maskLayer.inverted,
                    feather: maskLayer.feather
                )
                layers.append(duplicate)
            }
        default:
            break
        }
        
        needsUpdate = true
        objectWillChange.send()
    }
    
    // MARK: - Layer Processing
    
    public func processLayers() -> CIImage? {
        guard let originalImage = originalImage else { return nil }
        
        var result = originalImage
        
        for layer in layers where layer.isVisible {
            result = layer.apply(to: result, using: ciContext)
        }
        
        return result
    }
    
    public func processLayersAsync() async -> CIImage? {
        guard let originalImage = originalImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result = originalImage
                
                for layer in self.layers where layer.isVisible {
                    result = layer.apply(to: result, using: self.ciContext)
                }
                
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Layer Groups
    
    public func createLayerGroup(name: String, layerIDs: [UUID]) {
        // Implementation for layer groups
        // This would require a GroupLayer type
    }
    
    public func flattenGroup(id: UUID) {
        // Flatten a layer group into individual layers
    }
    
    // MARK: - Mask Operations
    
    public func addMaskToLayer(layerID: UUID, mask: MaskLayer) {
        // Associate a mask with a specific layer
    }
    
    public func removeMaskFromLayer(layerID: UUID) {
        // Remove mask from layer
    }
    
    // MARK: - Adjustment Layers
    
    public func createBrightnessLayer(name: String = "Brightness", value: Float) {
        let layer = AdjustmentLayer(
            name: name,
            adjustmentType: .brightness(value)
        )
        addLayer(layer)
    }
    
    public func createContrastLayer(name: String = "Contrast", value: Float) {
        let layer = AdjustmentLayer(
            name: name,
            adjustmentType: .contrast(value)
        )
        addLayer(layer)
    }
    
    public func createExposureLayer(name: String = "Exposure", value: Float) {
        let layer = AdjustmentLayer(
            name: name,
            adjustmentType: .exposure(value)
        )
        addLayer(layer)
    }
    
    public func createCurvesLayer(name: String = "Curves", controlPoints: [CGPoint]) {
        let layer = AdjustmentLayer(
            name: name,
            adjustmentType: .curves(controlPoints: controlPoints)
        )
        addLayer(layer)
    }
    
    // MARK: - Cache Management
    
    public func clearCache() {
        processedCache.removeAll()
        needsUpdate = true
    }
    
    public func invalidateCache(for layerID: UUID) {
        processedCache.removeValue(forKey: layerID)
        needsUpdate = true
    }
    
    // MARK: - Presets
    
    public func saveAsPreset(name: String) -> LayerPreset {
        return LayerPreset(
            name: name,
            layers: layers.map { LayerSnapshot(from: $0) }
        )
    }
    
    public func applyPreset(_ preset: LayerPreset) {
        layers = preset.layers.map { $0.toLayer() }
        clearCache()
        needsUpdate = true
        objectWillChange.send()
    }
    
    // MARK: - Reset
    
    public func removeAllLayers() {
        layers.removeAll()
        clearCache()
        needsUpdate = true
        objectWillChange.send()
    }
    
    public func resetToOriginal() {
        layers.removeAll()
        clearCache()
        needsUpdate = true
        objectWillChange.send()
    }
}

// MARK: - Layer Preset

public struct LayerPreset: Codable, Identifiable {
    public let id = UUID()
    public var name: String
    public var layers: [LayerSnapshot]
    public var createdAt: Date
    
    public init(name: String, layers: [LayerSnapshot]) {
        self.name = name
        self.layers = layers
        self.createdAt = Date()
    }
}

// MARK: - Layer Snapshot

public struct LayerSnapshot: Codable {
    public let type: LayerType
    public let name: String
    public let isVisible: Bool
    public let opacity: Float
    public let blendMode: BlendMode
    public let parameters: [String: String]
    
    public init(from layer: any Layer) {
        self.type = layer.type
        self.name = layer.name
        self.isVisible = layer.isVisible
        self.opacity = layer.opacity
        self.blendMode = layer.blendMode
        self.parameters = [:] // Simplified for now
    }
    
    public func toLayer() -> any Layer {
        // Convert snapshot back to layer
        switch type {
        case .adjustment:
            return AdjustmentLayer(name: name, adjustmentType: .brightness(0), parameters: [:])
        case .mask:
            return MaskLayer(name: name)
        default:
            return AdjustmentLayer(name: name, adjustmentType: .brightness(0), parameters: [:])
        }
    }
}

// MARK: - Layer Manager Extensions

extension LayerManager {
    
    /// Get the flattened image with all visible layers applied
    public var flattenedImage: CIImage? {
        processLayers()
    }
    
    /// Check if any layers need processing
    public var hasPendingChanges: Bool {
        needsUpdate
    }
    
    /// Get visible layer count
    public var visibleLayerCount: Int {
        layers.filter { $0.isVisible }.count
    }
    
    /// Get layer by ID
    public func layer(withID id: UUID) -> (any Layer)? {
        layers.first { $0.id == id }
    }
    
    /// Get layer index
    public func index(of layerID: UUID) -> Int? {
        layers.firstIndex { $0.id == layerID }
    }
    
    /// Move layer up in stack
    public func moveLayerUp(id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }), index < layers.count - 1 else { return }
        layers.swapAt(index, index + 1)
        needsUpdate = true
        objectWillChange.send()
    }
    
    /// Move layer down in stack
    public func moveLayerDown(id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }), index > 0 else { return }
        layers.swapAt(index, index - 1)
        needsUpdate = true
        objectWillChange.send()
    }
    
    /// Bring layer to front
    public func bringToFront(id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }), index < layers.count - 1 else { return }
        let layer = layers.remove(at: index)
        layers.append(layer)
        needsUpdate = true
        objectWillChange.send()
    }
    
    /// Send layer to back
    public func sendToBack(id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }), index > 0 else { return }
        let layer = layers.remove(at: index)
        layers.insert(layer, at: 0)
        needsUpdate = true
        objectWillChange.send()
    }
}
