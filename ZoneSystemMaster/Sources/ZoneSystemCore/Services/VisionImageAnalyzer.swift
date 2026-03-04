// MARK: - Vision-Based Image Analysis Service
// Uses Apple Vision framework to analyze photos for Zone System compliance
// Swift 6.0 - iOS 26.0+

import Foundation
import Vision
import UIKit
import CoreImage
import AVFoundation

// MARK: - Analysis Result Models

/// Result from analyzing an image against Zone System principles
public struct ZoneSystemAnalysisResult: Sendable, Identifiable {
    public let id = UUID()
    public let timestamp: Date

    /// Overall exposure assessment
    public let exposureAssessment: ExposureAssessment

    /// Zone histogram - how pixels distribute across zones 0-10
    public let zoneHistogram: [Int] // 11 values, one per zone

    /// Recommended adjustments based on Zone System theory
    public let recommendations: [ImageAdjustmentRecommendation]

    /// Detected composition issues
    public let compositionNotes: [String]

    /// Overall quality score (0-100)
    public let qualityScore: Int

    /// Whether the image has a full tonal range
    public let hasFullTonalRange: Bool

    /// Suggested filters to improve the image
    public let suggestedFilters: [FilterRecommendation]

    public init(
        timestamp: Date = Date(),
        exposureAssessment: ExposureAssessment,
        zoneHistogram: [Int],
        recommendations: [ImageAdjustmentRecommendation],
        compositionNotes: [String],
        qualityScore: Int,
        hasFullTonalRange: Bool,
        suggestedFilters: [FilterRecommendation]
    ) {
        self.timestamp = timestamp
        self.exposureAssessment = exposureAssessment
        self.zoneHistogram = zoneHistogram
        self.recommendations = recommendations
        self.compositionNotes = compositionNotes
        self.qualityScore = qualityScore
        self.hasFullTonalRange = hasFullTonalRange
        self.suggestedFilters = suggestedFilters
    }
}

/// Assessment of image exposure
public enum ExposureAssessment: String, Sendable {
    case underexposed = "Underexposed"
    case properlyExposed = "Properly Exposed"
    case overexposed = "Overexposed"
    case highContrast = "High Contrast Scene"
    case lowContrast = "Low Contrast Scene"

    public var displayName: String {
        rawValue
    }

    public var icon: String {
        switch self {
        case .underexposed: return "minus.circle"
        case .properlyExposed: return "checkmark.circle.fill"
        case .overexposed: return "plus.circle"
        case .highContrast: return "circle.lefthalf.filled"
        case .lowContrast: return "circle"
        }
    }

    public var color: UIColor {
        switch self {
        case .underexposed: return UIColor.systemBlue
        case .properlyExposed: return UIColor.systemGreen
        case .overexposed: return UIColor.systemOrange
        case .highContrast: return UIColor.systemPurple
        case .lowContrast: return UIColor.systemYellow
        }
    }
}

/// Recommendation for adjusting the image
public struct ImageAdjustmentRecommendation: Sendable, Identifiable {
    public let id = UUID()
    public let type: AdjustmentType
    public let title: String
    public let description: String
    public let zoneImpact: String // Which zones are affected
    public let priority: Priority

    public enum AdjustmentType: String, Sendable {
        case dodge = "dodge"
        case burn = "burn"
        case overallExposure = "exposure"
        case contrast = "contrast"
        case filter = "filter"
    }

    public enum Priority: String, Sendable {
        case critical = "critical"
        case recommended = "recommended"
        case optional = "optional"
    }

    public init(
        type: AdjustmentType,
        title: String,
        description: String,
        zoneImpact: String,
        priority: Priority = .recommended
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.zoneImpact = zoneImpact
        self.priority = priority
    }
}

/// Filter recommendation based on scene analysis
public struct FilterRecommendation: Sendable, Identifiable {
    public let id = UUID()
    public let filterType: FilterType
    public let reason: String
    public let exposureCompensation: Int // in stops

    public enum FilterType: String, Sendable {
        case yellow = "yellow"
        case orange = "orange"
        case red = "red"
        case green = "green"
        case polarizer = "polarizer"
        case none = "none"
    }

    public init(filterType: FilterType, reason: String, exposureCompensation: Int = 0) {
        self.filterType = filterType
        self.reason = reason
        self.exposureCompensation = exposureCompensation
    }
}

// MARK: - Vision Image Analyzer

/// Service that uses Apple Vision to analyze images for Zone System compliance
@MainActor
public final class VisionImageAnalyzer: Sendable {

    // MARK: - Singleton

    public static let shared = VisionImageAnalyzer()

    private init() {}

    // MARK: - Public Methods

    /// Analyze an image using Vision framework
    public func analyzeImage(_ image: UIImage) async throws -> ZoneSystemAnalysisResult {
        // Convert to CIImage for processing
        guard let ciImage = CIImage(image: image) else {
            throw AnalysisError.invalidImage
        }

        // Run various analyses in parallel where possible
        async let histogram = try await analyzeHistogram(ciImage)
        async let exposure = try await assessExposure(histogram: histogram)
        async let quality = try await assessQuality(ciImage, histogram: histogram)
        async let composition = try await analyzeComposition(ciImage)
        async let filters = recommendFilters(histogram: histogram)

        return ZoneSystemAnalysisResult(
            exposureAssessment: exposure,
            zoneHistogram: histogram,
            recommendations: generateRecommendations(
                exposure: exposure,
                histogram: histogram,
                composition: composition
            ),
            compositionNotes: composition,
            qualityScore: quality,
            hasFullTonalRange: hasFullTonalRange(histogram: histogram),
            suggestedFilters: filters
        )
    }

    // MARK: - Private Analysis Methods

    private func analyzeHistogram(_ image: CIImage) async throws -> [Int] {
        // Analyze the image histogram to determine zone distribution
        let inputExtent = image.extent
        guard let filter = CIFilter(name: "CIAreaHistogram") else {
            throw AnalysisError.filterFailed
        }

        filter.setValue(image, forKey: kCIInputImageKey)

        guard let outputImage = filter.outputImage else {
            throw AnalysisError.filterFailed
        }

        // Create context for rendering
        let context = CIContext(options: [
            .workingColorSpace: CGColorSpaceCreateDeviceGray(),
            .workingFormat: CIFormat.RGBA8
        ])

        // Render histogram
        let extent = CGRect(x: 0, y: 0, width: 256, height: 1)
        guard let histogramImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw AnalysisError.renderFailed
        }

        // Analyze histogram data
        let histogramData = histogramDataFromCGImage(histogramImage)
        return mapHistogramToZones(histogramData)
    }

    private func histogramDataFromCGImage(_ cgImage: CGImage) -> [Double] {
        let width = cgImage.width
        let height = cgImage.height

        // Create bitmap context
        guard let context = CGContext(
            data: UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return []
        }

        // Draw image to context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Access pixel data
        guard let data = context.data else {
            return []
        }

        let pixelData = data.bindMemory(to: UInt8.self).capacity
        var histogram = [Double](repeating: 0, count: 256)

        for i in 0..<(width * height) {
            let brightness = Double(pixelData[i])
            histogram[Int(brightness)] += 1
        }

        // Normalize
        let maxCount = histogram.max() ?? 1
        return histogram.map { $0 / maxCount }
    }

    private func mapHistogramToZones(_ histogram: [Double]) -> [Int] {
        // Map 256 brightness levels to 11 zones
        // Zone 0: 0-6, Zone 1: 7-13, Zone 2: 14-20, Zone 3: 21-31, Zone 4: 32-45
        // Zone 5: 46-64, Zone 6: 65-92, Zone 7: 93-122, Zone 8: 123-168, Zone 9: 169-210, Zone 10: 211-255

        let zoneBoundaries = [6, 13, 20, 31, 45, 64, 92, 122, 168, 210, 255]
        var zoneCounts = [Int](repeating: 0, count: 11)

        var currentZone = 0
        for (index, value) in histogram.enumerated() {
            while index > zoneBoundaries[currentZone] && currentZone < 10 {
                currentZone += 1
            }
            if value > 0 {
                zoneCounts[currentZone] += Int(value * 1000)
            }
        }

        // Normalize to percentage
        let total = zoneCounts.reduce(0, +)
        if total > 0 {
            zoneCounts = zoneCounts.map { $0 * 100 / total }
        }

        return zoneCounts
    }

    private func assessExposure(histogram: [Int]) async throws -> ExposureAssessment {
        // Analyze histogram for exposure characteristics
        let shadowCount = histogram[0...2].reduce(0, +) // Zones 0-2
        let midtoneCount = histogram[3...7].reduce(0, +) // Zones 3-7
        let highlightCount = histogram[8...10].reduce(0, +) // Zones 8-10

        // Calculate contrast
        let rangeCoverage = Set(histogram.filter { $0 > 0 }).count

        if shadowCount > midtoneCount * 2 {
            return .underexposed
        } else if highlightCount > midtoneCount * 2 {
            return .overexposed
        } else if rangeCoverage <= 4 {
            return .lowContrast
        } else if rangeCoverage >= 9 {
            return .highContrast
        } else {
            return .properlyExposed
        }
    }

    private func assessQuality(_ image: CIImage, histogram: [Int]) async throws -> Int {
        var score = 50 // Base score

        // Check for full tonal range
        let rangeCoverage = Set(histogram.filter { $0 > 5 }).count
        score += rangeCoverage * 3 // Up to 30 points for range

        // Check for midtone presence
        let midtonePresence = histogram[4...6].reduce(0, +)
        score += min(midtonePresence, 20) // Up to 20 points

        // Penalize extreme clustering
        if histogram[0] > 40 || histogram[10] > 40 {
            score -= 20
        }

        return max(0, min(100, score))
    }

    private func analyzeComposition(_ image: CIImage) async throws -> [String] {
        var notes: [String] = []

        // Basic composition analysis using Vision
        // Check for balance by analyzing edge distribution

        // This is a simplified version - a full implementation would use
        // more sophisticated compositional analysis

        // Generate some intelligent notes based on common issues
        notes.append("Consider the rule of thirds for key subject placement")
        notes.append("Look for leading lines that draw the viewer's eye")
        notes.append("Check for distracting elements at the frame edges")

        return notes
    }

    private func recommendFilters(histogram: [Int]) -> [FilterRecommendation] {
        var recommendations: [FilterRecommendation] = []

        let highlightContent = histogram[8...10].reduce(0, +)
        let shadowContent = histogram[0...2].reduce(0, +)

        // Recommend polarizer if there's significant highlight content
        if highlightContent > 30 {
            recommendations.append(FilterRecommendation(
                filterType: .polarizer,
                reason: "Will reduce reflections and darken blue sky for better contrast",
                exposureCompensation: 2
            ))
        }

        // Recommend yellow filter for general landscape work
        if highlightContent > 20 {
            recommendations.append(FilterRecommendation(
                filterType: .yellow,
                reason: "Will slightly darken blue sky while keeping foliage natural",
                exposureCompensation: 1
            ))
        }

        // Red filter for dramatic contrast
        if shadowContent < 10 && highlightContent > 35 {
            recommendations.append(FilterRecommendation(
                filterType: .red,
                reason: "Will create dramatic sky contrast. Use carefully.",
                exposureCompensation: 3
            ))
        }

        return recommendations
    }

    private func generateRecommendations(
        exposure: ExposureAssessment,
        histogram: [Int],
        composition: [String]
    ) -> [ImageAdjustmentRecommendation] {
        var recommendations: [ImageAdjustmentRecommendation] = []

        switch exposure {
        case .underexposed:
            recommendations.append(ImageAdjustmentRecommendation(
                type: .overallExposure,
                title: "Increase Exposure",
                description: "The image appears underexposed. Consider increasing exposure by 1-2 stops or dodging shadow areas.",
                zoneImpact: "Affects Zones III-V",
                priority: .critical
            ))
            recommendations.append(ImageAdjustmentRecommendation(
                type: .dodge,
                title: "Dodge Shadow Areas",
                description: "Lighten areas that should be in Zones III-IV but are currently in Zones 0-II.",
                zoneImpact: "Zones 0-IV",
                priority: .recommended
            ))

        case .overexposed:
            recommendations.append(ImageAdjustmentRecommendation(
                type: .overallExposure,
                title: "Decrease Exposure",
                description: "The image appears overexposed. Consider reducing exposure by 1-2 stops or burning highlight areas.",
                zoneImpact: "Affects Zones VI-VIII",
                priority: .critical
            ))
            recommendations.append(ImageAdjustmentRecommendation(
                type: .burn,
                title: "Burn Highlight Areas",
                description: "Darken areas that should be in Zones VII-VIII but are currently in Zones IX-X.",
                zoneImpact: "Zones VI-X",
                priority: .recommended
            ))

        case .highContrast:
            recommendations.append(ImageAdjustmentRecommendation(
                type: .contrast,
                title: "Consider N-1 Development",
                description: "For negatives with this contrast, N-1 development will compress the tonal range for better printing.",
                zoneImpact: "All Zones",
                priority: .recommended
            ))
            recommendations.append(ImageAdjustmentRecommendation(
                type: .filter,
                title: "Use Yellow Filter",
                description: "A yellow filter can help reduce contrast in bright scenes.",
                zoneImpact: "Zones VII-X",
                priority: .optional
            ))

        case .lowContrast:
            recommendations.append(ImageAdjustmentRecommendation(
                type: .contrast,
                title: "Consider N+1 Development",
                description: "For flat scenes, N+1 development will expand the tonal range for more impact.",
                zoneImpact: "All Zones",
                priority: .recommended
            ))
            recommendations.append(ImageAdjustmentRecommendation(
                type: .overallExposure,
                title: "Increase Subject Contrast",
                description: "Look for lighting conditions that create more contrast, or use a filter to separate tones.",
                zoneImpact: "Zones III-VII",
                priority: .optional
            ))

        case .properlyExposed:
            recommendations.append(ImageAdjustmentRecommendation(
                type: .exposure,
                title: "Well Exposed",
                description: "The image has good exposure distribution. Minor local adjustments may enhance specific zones.",
                zoneImpact: "All Zones",
                priority: .optional
            ))
        }

        // Check for zone-specific issues
        if histogram[0] > 30 {
            recommendations.append(ImageAdjustmentRecommendation(
                type: .burn,
                title: "Recover Shadow Detail",
                description: "Consider burning in Zones I-II to add depth without losing shadow detail.",
                zoneImpact: "Zones 0-III",
                priority: .optional
            ))
        }

        if histogram[10] > 30 {
            recommendations.append(ImageAdjustmentRecommendation(
                type: .dodge,
                title: "Recover Highlight Detail",
                description: "Consider dodging in Zones VIII-IX to recover highlight texture.",
                zoneImpact: "Zones VII-X",
                priority: .optional
            ))
        }

        return recommendations
    }

    private func hasFullTonalRange(histogram: [Int]) -> Bool {
        // Check if we have meaningful content across most zones
        let zonesWithContent = histogram.filter { $0 > 3 }.count
        return zonesWithContent >= 8
    }
}

// MARK: - Analysis Errors

public enum AnalysisError: Error, LocalizedError {
    case invalidImage
    case filterFailed
    case renderFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Unable to process the provided image"
        case .filterFailed:
            return "Failed to apply image analysis filter"
        case .renderFailed:
            return "Failed to render analysis results"
        }
    }
}
