//
//  FilmGrainSimulator.swift
//  Zone System Master - Photo Editor Engine
//  Film grain simulation for authentic darkroom feel
//

import Foundation
import Metal
import CoreImage

// MARK: - Film Characteristic

public struct FilmCharacteristic {
    public let name: String
    public let iso: Int
    public let grainSize: Float // Relative grain size
    public let grainIntensity: Float // Base grain intensity
    public let contrastIndex: Float // Characteristic curve contrast
    public let shadowDetail: Float // Shadow detail retention
    public let highlightDetail: Float // Highlight detail retention
    public let pushPullFactor: Float // How grain responds to push/pull
    
    public init(
        name: String,
        iso: Int,
        grainSize: Float,
        grainIntensity: Float,
        contrastIndex: Float,
        shadowDetail: Float,
        highlightDetail: Float,
        pushPullFactor: Float
    ) {
        self.name = name
        self.iso = iso
        self.grainSize = grainSize
        self.grainIntensity = grainIntensity
        self.contrastIndex = contrastIndex
        self.shadowDetail = shadowDetail
        self.highlightDetail = highlightDetail
        self.pushPullFactor = pushPullFactor
    }
}

// MARK: - Film Database

public struct FilmDatabase {
    public static let hp5Plus = FilmCharacteristic(
        name: "Ilford HP5 Plus",
        iso: 400,
        grainSize: 1.0,
        grainIntensity: 0.8,
        contrastIndex: 0.62,
        shadowDetail: 0.75,
        highlightDetail: 0.70,
        pushPullFactor: 1.2
    )
    
    public static let triX = FilmCharacteristic(
        name: "Kodak Tri-X",
        iso: 400,
        grainSize: 1.1,
        grainIntensity: 1.2,
        contrastIndex: 0.65,
        shadowDetail: 0.70,
        highlightDetail: 0.65,
        pushPullFactor: 1.3
    )
    
    public static let delta100 = FilmCharacteristic(
        name: "Ilford Delta 100",
        iso: 100,
        grainSize: 0.6,
        grainIntensity: 0.4,
        contrastIndex: 0.58,
        shadowDetail: 0.85,
        highlightDetail: 0.80,
        pushPullFactor: 0.9
    )
    
    public static let delta400 = FilmCharacteristic(
        name: "Ilford Delta 400",
        iso: 400,
        grainSize: 0.8,
        grainIntensity: 0.7,
        contrastIndex: 0.60,
        shadowDetail: 0.80,
        highlightDetail: 0.75,
        pushPullFactor: 1.1
    )
    
    public static let tmax100 = FilmCharacteristic(
        name: "Kodak T-Max 100",
        iso: 100,
        grainSize: 0.5,
        grainIntensity: 0.3,
        contrastIndex: 0.55,
        shadowDetail: 0.90,
        highlightDetail: 0.85,
        pushPullFactor: 0.8
    )
    
    public static let tmax400 = FilmCharacteristic(
        name: "Kodak T-Max 400",
        iso: 400,
        grainSize: 0.7,
        grainIntensity: 0.5,
        contrastIndex: 0.58,
        shadowDetail: 0.85,
        highlightDetail: 0.80,
        pushPullFactor: 1.0
    )
    
    public static let fp4Plus = FilmCharacteristic(
        name: "Ilford FP4 Plus",
        iso: 125,
        grainSize: 0.7,
        grainIntensity: 0.5,
        contrastIndex: 0.56,
        shadowDetail: 0.82,
        highlightDetail: 0.78,
        pushPullFactor: 0.95
    )
    
    public static let panFPlus = FilmCharacteristic(
        name: "Ilford Pan F Plus",
        iso: 50,
        grainSize: 0.4,
        grainIntensity: 0.2,
        contrastIndex: 0.52,
        shadowDetail: 0.95,
        highlightDetail: 0.90,
        pushPullFactor: 0.7
    )
    
    public static let allFilms: [FilmCharacteristic] = [
        hp5Plus, triX, delta100, delta400,
        tmax100, tmax400, fp4Plus, panFPlus
    ]
    
    public static func film(named name: String) -> FilmCharacteristic? {
        allFilms.first { $0.name == name }
    }
}

// MARK: - Grain Settings

public struct GrainSettings {
    public var filmType: FilmType
    public var intensity: Float // 0.0 to 2.0
    public var grainSize: Float // 0.5 to 2.0
    public var pushPull: Float // -2 to +2 stops
    public var monochrome: Bool // Color or monochrome grain
    public var highlightProtection: Float // Reduce grain in highlights
    public var shadowBoost: Float // Increase grain in shadows
    
    public init(
        filmType: FilmType = .hp5,
        intensity: Float = 0.5,
        grainSize: Float = 1.0,
        pushPull: Float = 0.0,
        monochrome: Bool = true,
        highlightProtection: Float = 0.5,
        shadowBoost: Float = 0.3
    ) {
        self.filmType = filmType
        self.intensity = intensity
        self.grainSize = grainSize
        self.pushPull = pushPull
        self.monochrome = monochrome
        self.highlightProtection = highlightProtection
        self.shadowBoost = shadowBoost
    }
    
    public var effectiveIntensity: Float {
        let film = filmType.characteristic
        let pushPullEffect = 1.0 + abs(pushPull) * film.pushPullFactor * 0.3
        return intensity * film.grainIntensity * pushPullEffect
    }
}

// MARK: - Film Grain Simulator

public final class FilmGrainSimulator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var settings = GrainSettings()
    @Published public var isProcessing = false
    @Published public var previewEnabled = true
    
    // MARK: - Metal Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var computePipelineState: MTLComputePipelineState?
    
    // MARK: - Grain Texture Cache
    
    private var grainTextureCache: [String: MTLTexture] = [:]
    private let cacheQueue = DispatchQueue(label: "com.zonesystem.graincache", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        setupComputePipeline()
    }
    
    // MARK: - Pipeline Setup
    
    private func setupComputePipeline() {
        guard let library = try? device.makeDefaultLibrary(bundle: Bundle.main) else {
            print("Failed to load Metal library")
            return
        }
        
        if let function = library.makeFunction(name: "applyFilmGrain") {
            do {
                computePipelineState = try device.makeComputePipelineState(function: function)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }
    }
    
    // MARK: - Apply Grain
    
    public func apply(to image: CIImage, settings: FilmGrainSettings) async -> CIImage {
        guard settings.enabled,
              let pipelineState = computePipelineState else {
            return image
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
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
                
                // Set parameters
                var intensity = settings.intensity
                var grainSize = settings.grainSize
                var filmType = self.filmTypeToIndex(settings.filmType)
                var pushPull = settings.pushPull
                
                computeEncoder.setBytes(&intensity, length: MemoryLayout<Float>.size, index: 0)
                computeEncoder.setBytes(&grainSize, length: MemoryLayout<Float>.size, index: 1)
                computeEncoder.setBytes(&filmType, length: MemoryLayout<Int>.size, index: 2)
                computeEncoder.setBytes(&pushPull, length: MemoryLayout<Float>.size, index: 3)
                
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
    
    // MARK: - Apply with Custom Settings
    
    public func applyWithSettings(to image: CIImage) async -> CIImage {
        let filmSettings = FilmGrainSettings(
            filmType: settings.filmType,
            intensity: settings.effectiveIntensity,
            grainSize: settings.grainSize,
            pushPull: settings.pushPull,
            enabled: true
        )
        
        return await apply(to: image, settings: filmSettings)
    }
    
    // MARK: - Split Grade Application
    
    public func applySplitGrade(
        to image: CIImage,
        settings: SplitGradeSettings,
        mask: MTLTexture?
    ) async -> CIImage {
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
                if let mask = mask {
                    computeEncoder.setTexture(mask, index: 1)
                }
                computeEncoder.setTexture(outputTexture, index: 2)
                
                // Set split grade parameters
                var lowGrade = settings.lowGrade.rawValue
                var highGrade = settings.highGrade.rawValue
                var lowExposure = settings.lowExposure
                var highExposure = settings.highExposure
                
                computeEncoder.setBytes(&lowGrade, length: MemoryLayout<Int>.size, index: 0)
                computeEncoder.setBytes(&highGrade, length: MemoryLayout<Int>.size, index: 1)
                computeEncoder.setBytes(&lowExposure, length: MemoryLayout<Float>.size, index: 2)
                computeEncoder.setBytes(&highExposure, length: MemoryLayout<Float>.size, index: 3)
                
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
    
    // MARK: - Grain Texture Generation
    
    public func generateGrainTexture(
        size: CGSize,
        film: FilmCharacteristic,
        intensity: Float
    ) -> MTLTexture? {
        let cacheKey = "\(film.name)_\(size.width)_\(size.height)_\(intensity)"
        
        if let cached = grainTextureCache[cacheKey] {
            return cached
        }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        // Generate grain using noise function
        // This would be done with a compute shader in production
        
        cacheQueue.async {
            self.grainTextureCache[cacheKey] = texture
        }
        
        return texture
    }
    
    // MARK: - Film Simulation Presets
    
    public func applyFilmSimulation(
        to image: CIImage,
        film: FilmCharacteristic,
        developer: DeveloperType = .d76,
        dilution: DeveloperDilution = .stock
    ) async -> CIImage {
        // Apply film characteristic curve
        var result = image
        
        // Apply contrast based on film characteristic
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.contrast = film.contrastIndex
        contrastFilter.inputImage = result
        result = contrastFilter.outputImage ?? result
        
        // Apply grain
        let grainSettings = FilmGrainSettings(
            filmType: filmTypeFromCharacteristic(film),
            intensity: film.grainIntensity,
            grainSize: film.grainSize,
            pushPull: 0,
            enabled: true
        )
        
        result = await apply(to: result, settings: grainSettings)
        
        return result
    }
    
    // MARK: - Helpers
    
    private func filmTypeToIndex(_ type: FilmType) -> Int {
        switch type {
        case .hp5: return 0
        case .triX: return 1
        case .delta100: return 2
        case .delta400: return 3
        case .tmax100: return 4
        case .tmax400: return 5
        case .fp4: return 6
        case .panF: return 7
        }
    }
    
    private func filmTypeFromCharacteristic(_ film: FilmCharacteristic) -> FilmType {
        switch film.name {
        case "Kodak Tri-X": return .triX
        case "Ilford Delta 100": return .delta100
        case "Ilford Delta 400": return .delta400
        case "Kodak T-Max 100": return .tmax100
        case "Kodak T-Max 400": return .tmax400
        case "Ilford FP4 Plus": return .fp4
        case "Ilford Pan F Plus": return .panF
        default: return .hp5
        }
    }
    
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
    
    // MARK: - Cache Management
    
    public func clearCache() {
        cacheQueue.async {
            self.grainTextureCache.removeAll()
        }
    }
    
    // MARK: - Presets
    
    public func applyPreset(_ preset: GrainPreset) {
        settings.filmType = preset.filmType
        settings.intensity = preset.intensity
        settings.grainSize = preset.grainSize
        settings.pushPull = preset.pushPull
    }
}

// MARK: - Developer Types

public enum DeveloperType: String, CaseIterable, Identifiable {
    case d76 = "D-76"
    case id11 = "ID-11"
    case microphen = "Microphen"
    case perceptol = "Perceptol"
    case tmax = "T-Max"
    case xtol = "XTOL"
    case rodinal = "Rodinal"
    case hc110 = "HC-110"
    
    public var id: String { rawValue }
}

public enum DeveloperDilution: String, CaseIterable, Identifiable {
    case stock = "Stock"
    case onePlusOne = "1+1"
    case onePlusThree = "1+3"
    case onePlusSeven = "1+7"
    case onePlusFifteen = "1+15"
    case onePlusThirtyOne = "1+31"
    
    public var id: String { rawValue }
    
    public var factor: Float {
        switch self {
        case .stock: return 1.0
        case .onePlusOne: return 1.5
        case .onePlusThree: return 2.0
        case .onePlusSeven: return 2.5
        case .onePlusFifteen: return 3.0
        case .onePlusThirtyOne: return 3.5
        }
    }
}

// MARK: - Grain Preset

public struct GrainPreset: Codable, Identifiable {
    public let id = UUID()
    public var name: String
    public var filmType: FilmType
    public var intensity: Float
    public var grainSize: Float
    public var pushPull: Float
    
    public init(
        name: String,
        filmType: FilmType,
        intensity: Float,
        grainSize: Float,
        pushPull: Float
    ) {
        self.name = name
        self.filmType = filmType
        self.intensity = intensity
        self.grainSize = grainSize
        self.pushPull = pushPull
    }
    
    // Built-in presets
    public static let subtle = GrainPreset(
        name: "Subtle Grain",
        filmType: .delta100,
        intensity: 0.3,
        grainSize: 0.8,
        pushPull: 0
    )
    
    public static let medium = GrainPreset(
        name: "Medium Grain",
        filmType: .hp5,
        intensity: 0.6,
        grainSize: 1.0,
        pushPull: 0
    )
    
    public static let heavy = GrainPreset(
        name: "Heavy Grain",
        filmType: .triX,
        intensity: 1.0,
        grainSize: 1.2,
        pushPull: 1
    )
    
    public static let pushed = GrainPreset(
        name: "Pushed Film",
        filmType: .hp5,
        intensity: 1.2,
        grainSize: 1.3,
        pushPull: 2
    )
}

// MARK: - Film Grain Simulator Extensions

extension FilmGrainSimulator {
    
    /// Get film characteristic for current settings
    public var currentFilmCharacteristic: FilmCharacteristic {
        switch settings.filmType {
        case .hp5: return FilmDatabase.hp5Plus
        case .triX: return FilmDatabase.triX
        case .delta100: return FilmDatabase.delta100
        case .delta400: return FilmDatabase.delta400
        case .tmax100: return FilmDatabase.tmax100
        case .tmax400: return FilmDatabase.tmax400
        case .fp4: return FilmDatabase.fp4Plus
        case .panF: return FilmDatabase.panFPlus
        }
    }
    
    /// Get recommended developer for current film
    public var recommendedDeveloper: DeveloperType {
        switch settings.filmType {
        case .hp5, .fp4, .panF:
            return .id11
        case .triX:
            return .d76
        case .delta100, .delta400:
            return .id11
        case .tmax100, .tmax400:
            return .tmax
        }
    }
    
    /// Calculate development time based on push/pull
    public func developmentTime(baseTime: Float) -> Float {
        let pushPull = settings.pushPull
        let factor = 1.0 + pushPull * 0.4 // Each stop = 40% time change
        return baseTime * factor
    }
    
    /// Preview grain at different sizes
    public func generateGrainPreview(size: CGSize) -> UIImage? {
        // Generate a small preview of the grain pattern
        let previewSize = CGSize(width: 256, height: 256)
        
        UIGraphicsBeginImageContextWithOptions(previewSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Fill with mid-gray
        context.setFillColor(CGColor(gray: 0.5, alpha: 1.0)!)
        context.fill(CGRect(origin: .zero, size: previewSize))
        
        // Draw grain pattern
        let film = currentFilmCharacteristic
        let grainCount = Int(previewSize.width * previewSize.height * CGFloat(film.grainIntensity) * 0.1)
        
        context.setFillColor(CGColor(gray: 0.0, alpha: CGFloat(film.grainIntensity))!)
        
        for _ in 0..<grainCount {
            let x = CGFloat.random(in: 0..<previewSize.width)
            let y = CGFloat.random(in: 0..<previewSize.height)
            let size = CGFloat(film.grainSize) * CGFloat.random(in: 0.5...1.5)
            
            context.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
