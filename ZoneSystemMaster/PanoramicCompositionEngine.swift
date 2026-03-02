// MARK: - Panoramic Composition Engine
// Strumenti composizione per formato panoramico X-Pan 1:3

import Foundation
import SwiftUI

/// Motore di composizione panoramica
public final class PanoramicCompositionEngine {
    
    public static let shared = PanoramicCompositionEngine()
    
    // Costanti X-Pan
    private let xPanWidth: Double = 65.0  // mm
    private let xPanHeight: Double = 24.0 // mm
    private let xPanFocalLength: Double = 45.0 // mm (equivalente ~25mm su 35mm)
    
    // Costanti prospettica
    private let compressionFactor: Double = 0.65 // Fattore compressione prospettica X-Pan
    
    private init() {}
    
    // MARK: - Field of View Calculations
    
    /// Calcola HFOV (Horizontal Field of View)
    /// Formula: HFOV = 2 * arctan(sensor_width / (2 * focal_length))
    public func calculateHFOV(sensorWidth: Double, focalLength: Double) -> Double {
        return 2 * atan(sensorWidth / (2 * focalLength)) * (180 / .pi)
    }
    
    /// Calcola VFOV (Vertical Field of View)
    public func calculateVFOV(sensorHeight: Double, focalLength: Double) -> Double {
        return 2 * atan(sensorHeight / (2 * focalLength)) * (180 / .pi)
    }
    
    /// Calcola diagonale FOV
    public func calculateDiagonalFOV(sensorDiagonal: Double, focalLength: Double) -> Double {
        return 2 * atan(sensorDiagonal / (2 * focalLength)) * (180 / .pi)
    }
    
    /// Calcola equivalente 35mm per formato X-Pan
    public func calculateXPanEquivalent(focalLength: Double) -> Double {
        // Crop factor X-Pan rispetto a 35mm
        let xPanDiagonal = sqrt(xPanWidth * xPanWidth + xPanHeight * xPanHeight)
        let mm35Diagonal = sqrt(36 * 36 + 24 * 24)
        let cropFactor = mm35Diagonal / xPanDiagonal
        
        return focalLength * cropFactor
    }
    
    /// Calcola HFOV per X-Pan
    public func calculateXPanHFOV(focalLength: Double = 45.0) -> Double {
        return calculateHFOV(sensorWidth: xPanWidth, focalLength: focalLength)
    }
    
    /// Calcola VFOV per X-Pan
    public func calculateXPanVFOV(focalLength: Double = 45.0) -> Double {
        return calculateVFOV(sensorHeight: xPanHeight, focalLength: focalLength)
    }
    
    // MARK: - Perspective Compression
    
    /// Calcola fattore di compressione prospettica
    public func calculatePerspectiveCompression(
        subjectDistance: Double,
        focalLength: Double,
        referenceFocalLength: Double = 50.0
    ) -> Double {
        // Compressione prospettica = rapporto tra ingrandimenti
        let magnification = focalLength / subjectDistance
        let referenceMagnification = referenceFocalLength / subjectDistance
        
        return magnification / referenceMagnification
    }
    
    /// Calcola ingrandimento soggetto
    public func calculateMagnification(focalLength: Double, subjectDistance: Double) -> Double {
        return focalLength / subjectDistance
    }
    
    /// Stima distanza iperfocale
    public func calculateHyperfocalDistance(
        focalLength: Double,
        aperture: Double,
        circleOfConfusion: Double = 0.03 // mm
    ) -> Double {
        // H = f² / (N × c) + f
        let focalMm = focalLength
        return (focalMm * focalMm) / (aperture * circleOfConfusion) + focalMm
    }
    
    /// Calcola profondità di campo
    public func calculateDepthOfField(
        focalLength: Double,
        aperture: Double,
        focusDistance: Double,
        circleOfConfusion: Double = 0.03
    ) -> DepthOfField {
        let hyperfocal = calculateHyperfocalDistance(
            focalLength: focalLength,
            aperture: aperture,
            circleOfConfusion: circleOfConfusion
        )
        
        // DoF near = (H × s) / (H + s)
        let nearLimit = (hyperfocal * focusDistance) / (hyperfocal + focusDistance)
        
        // DoF far = (H × s) / (H - s) se s < H, altrimenti infinito
        let farLimit: Double
        if focusDistance < hyperfocal {
            farLimit = (hyperfocal * focusDistance) / (hyperfocal - focusDistance)
        } else {
            farLimit = .infinity
        }
        
        let totalDepth = farLimit == .infinity ? .infinity : farLimit - nearLimit
        
        return DepthOfField(
            nearLimit: nearLimit / 1000, // Converti in metri
            farLimit: farLimit == .infinity ? .infinity : farLimit / 1000,
            totalDepth: totalDepth == .infinity ? .infinity : totalDepth / 1000,
            hyperfocalDistance: hyperfocal / 1000
        )
    }
    
    // MARK: - Composition Guidelines
    
    /// Genera linee guida composizione panoramica
    public func generatePanoramicGuidelines(
        imageSize: CGSize,
        style: GuidelineStyle = .standard
    ) -> PanoramicGuidelines {
        let width = Double(imageSize.width)
        let height = Double(imageSize.height)
        
        // Terzi orizzontali (più importanti in panoramico)
        let horizontalThirds = [
            height / 3,
            2 * height / 3
        ]
        
        // Terzi verticali
        let verticalThirds = [
            width / 3,
            2 * width / 3
        ]
        
        // Sezione aurea
        let phi = 1.618
        let goldenRatioH = [
            height / phi,
            height - height / phi
        ]
        
        let goldenRatioV = [
            width / phi,
            width - width / phi
        ]
        
        // Linea orizzonte suggerita (1/3 dal basso o dall'alto)
        let horizonLine = height * 0.33
        
        return PanoramicGuidelines(
            horizontalThirds: horizontalThirds,
            verticalThirds: verticalThirds,
            goldenRatioH: goldenRatioH,
            goldenRatioV: goldenRatioV,
            horizonLine: horizonLine
        )
    }
    
    /// Genera overlay linee guida per visualizzazione
    public func generateGuidelineOverlay(
        for imageSize: CGSize,
        style: GuidelineStyle = .standard
    ) -> GuidelineOverlay {
        let guidelines = generatePanoramicGuidelines(imageSize: imageSize, style: style)
        
        var lines: [GuidelineLine] = []
        
        // Linee orizzontali
        for y in guidelines.horizontalThirds {
            lines.append(GuidelineLine(
                start: CGPoint(x: 0, y: y),
                end: CGPoint(x: Double(imageSize.width), y: y),
                type: .third
            ))
        }
        
        // Linee verticali
        for x in guidelines.verticalThirds {
            lines.append(GuidelineLine(
                start: CGPoint(x: x, y: 0),
                end: CGPoint(x: x, y: Double(imageSize.height)),
                type: .third
            ))
        }
        
        // Linee sezione aurea
        if style == .goldenRatio || style == .all {
            for y in guidelines.goldenRatioH {
                lines.append(GuidelineLine(
                    start: CGPoint(x: 0, y: y),
                    end: CGPoint(x: Double(imageSize.width), y: y),
                    type: .goldenRatio
                ))
            }
            
            for x in guidelines.goldenRatioV {
                lines.append(GuidelineLine(
                    start: CGPoint(x: x, y: 0),
                    end: CGPoint(x: x, y: Double(imageSize.height)),
                    type: .goldenRatio
                ))
            }
        }
        
        // Linea orizzonte
        if let horizon = guidelines.horizonLine {
            lines.append(GuidelineLine(
                start: CGPoint(x: 0, y: horizon),
                end: CGPoint(x: Double(imageSize.width), y: horizon),
                type: .horizon
            ))
        }
        
        // Linee diagonali (forza dinamica)
        if style == .dynamic || style == .all {
            lines.append(GuidelineLine(
                start: CGPoint(x: 0, y: Double(imageSize.height)),
                end: CGPoint(x: Double(imageSize.width), y: 0),
                type: .diagonal
            ))
            lines.append(GuidelineLine(
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: Double(imageSize.width), y: Double(imageSize.height)),
                type: .diagonal
            ))
        }
        
        return GuidelineOverlay(lines: lines, imageSize: imageSize)
    }
    
    // MARK: - Panoramic Composition Rules
    
    /// Valuta composizione secondo regole panoramiche
    public func evaluateComposition(
        subjects: [SubjectPlacement],
        in frame: CGSize
    ) -> CompositionEvaluation {
        var score: Double = 0
        var feedback: [String] = []
        
        // Regola 1: Posizionamento soggetto principale
        if let mainSubject = subjects.first {
            let position = mainSubject.position
            let normalizedX = position.x / frame.width
            let normalizedY = position.y / frame.height
            
            // Controllo terzi
            let nearThirdX = abs(normalizedX - 0.33) < 0.1 || abs(normalizedX - 0.67) < 0.1
            let nearThirdY = abs(normalizedY - 0.33) < 0.1 || abs(normalizedY - 0.67) < 0.1
            
            if nearThirdX && nearThirdY {
                score += 30
                feedback.append("Soggetto principale posizionato su incrocio terzi")
            } else if nearThirdX || nearThirdY {
                score += 20
                feedback.append("Soggetto principale vicino a linea terzi")
            } else if normalizedX > 0.4 && normalizedX < 0.6 {
                score -= 10
                feedback.append("Soggetto principale al centro - considera spostamento")
            }
            
            // Controllo orizzonte
            if normalizedY > 0.3 && normalizedY < 0.4 {
                score += 15
                feedback.append("Orizzonte basso - enfatizza cielo")
            } else if normalizedY > 0.6 && normalizedY < 0.7 {
                score += 15
                feedback.append("Orizzonte alto - enfatizza primo piano")
            }
        }
        
        // Regola 2: Bilanciamento elementi
        let leftElements = subjects.filter { $0.position.x < frame.width / 2 }.count
        let rightElements = subjects.filter { $0.position.x > frame.width / 2 }.count
        
        if abs(leftElements - rightElements) <= 1 {
            score += 20
            feedback.append("Buon bilanciamento sinistra-destra")
        } else {
            score += 10
            feedback.append("Considera bilanciamento elementi")
        }
        
        // Regola 3: Linee guida orizzontali
        let horizontalElements = subjects.filter { $0.type == .horizontalLine }
        if horizontalElements.count >= 2 {
            score += 15
            feedback.append("Multiple linee orizzontali - buon senso di profondità")
        }
        
        // Regola 4: Punto focale
        let focalPoints = subjects.filter { $0.type == .focalPoint }
        if focalPoints.count == 1 {
            score += 15
            feedback.append("Singolo punto focale chiaro")
        } else if focalPoints.count > 2 {
            score -= 5
            feedback.append("Troppi punti focali - considera semplificazione")
        }
        
        return CompositionEvaluation(
            score: min(100, max(0, score)),
            feedback: feedback,
            subjects: subjects
        )
    }
    
    // MARK: - X-Pan Specific Calculations
    
    /// Informazioni complete formato X-Pan
    public func getXPanInfo(focalLength: Double = 45.0) -> XPanInfo {
        let hfov = calculateXPanHFOV(focalLength: focalLength)
        let vfov = calculateXPanVFOV(focalLength: focalLength)
        let equivalent = calculateXPanEquivalent(focalLength: focalLength)
        
        return XPanInfo(
            format: "24x65mm (1:2.7)",
            focalLength: focalLength,
            equivalent35mm: equivalent,
            horizontalFOV: hfov,
            verticalFOV: vfov,
            aspectRatio: xPanWidth / xPanHeight,
            diagonal: sqrt(xPanWidth * xPanWidth + xPanHeight * xPanHeight)
        )
    }
    
    /// Suggerimenti composizione per X-Pan
    public func getXPanCompositionTips(sceneType: PanoramicSceneType) -> [String] {
        var tips = [
            "Sfrutta il formato orizzontale per linee guida dinamiche",
            "Posiziona l'orizzonte su uno dei terzi",
            "Usa elementi in primo piano per profondità",
            "Cerca pattern ripetitivi che si estendono orizzontalmente"
        ]
        
        switch sceneType {
        case .landscape:
            tips += [
                "Enfatizza la vastità con orizzonte basso",
                "Usa nuvole o cielo drammatico come elemento principale",
                "Cerca linee S o diagonali per guida visiva"
            ]
        case .cityscape:
            tips += [
                "Allinea edifici con linee verticali dei terzi",
                "Cerca simmetria architettonica",
                "Usa prospettiva convergente per dinamismo"
            ]
        case .seascape:
            tips += [
                "Lunga esposizione per acqua setosa",
                "Orizzonte basso per enfatizzare cielo",
                "Elementi in primo piano (rocce, alghe)"
            ]
        case .portraitEnvironmental:
            tips += [
                "Posiziona soggetto su terzo sinistro o destro",
                "Lascia spazio 'guarda verso' davanti al soggetto",
                "Usa ambiente per raccontare storia"
            ]
        }
        
        return tips
    }
}

// MARK: - Supporting Types

/// Stili linee guida
public enum GuidelineStyle {
    case standard    // Solo terzi
    case goldenRatio // Terzi + sezione aurea
    case dynamic     // + diagonali
    case all         // Tutte le linee
}

/// Tipo di linea guida
public enum GuidelineType {
    case third
    case goldenRatio
    case horizon
    case diagonal
    
    public var color: Color {
        switch self {
        case .third: return .white
        case .goldenRatio: return .yellow
        case .horizon: return .cyan
        case .diagonal: return .red
        }
    }
    
    public var lineWidth: CGFloat {
        switch self {
        case .third: return 0.5
        case .goldenRatio: return 0.5
        case .horizon: return 1.0
        case .diagonal: return 0.5
        }
    }
}

/// Linea guida
public struct GuidelineLine {
    public let start: CGPoint
    public let end: CGPoint
    public let type: GuidelineType
}

/// Overlay linee guida
public struct GuidelineOverlay {
    public let lines: [GuidelineLine]
    public let imageSize: CGSize
}

/// Posizionamento soggetto
public struct SubjectPlacement {
    public let position: CGPoint
    public let size: CGSize
    public let type: SubjectType
    public let importance: Double // 0-1
    
    public init(
        position: CGPoint,
        size: CGSize,
        type: SubjectType,
        importance: Double
    ) {
        self.position = position
        self.size = size
        self.type = type
        self.importance = importance
    }
}

/// Tipo di soggetto
public enum SubjectType {
    case focalPoint
    case horizontalLine
    case verticalLine
    case diagonalLine
    case pattern
    case texture
    case negativeSpace
}

/// Valutazione composizione
public struct CompositionEvaluation {
    public let score: Double // 0-100
    public let feedback: [String]
    public let subjects: [SubjectPlacement]
    
    public var rating: String {
        switch score {
        case 80...100: return "Eccellente"
        case 60..<80: return "Buona"
        case 40..<60: return "Discreta"
        case 20..<40: return "Migliorabile"
        default: return "Da rivedere"
        }
    }
}

/// Profondità di campo
public struct DepthOfField {
    public let nearLimit: Double // metri
    public let farLimit: Double  // metri o infinito
    public let totalDepth: Double // metri o infinito
    public let hyperfocalDistance: Double // metri
    
    public var description: String {
        let farStr = farLimit == .infinity ? "∞" : String(format: "%.2f", farLimit)
        let depthStr = totalDepth == .infinity ? "∞" : String(format: "%.2f", totalDepth)
        
        return """
        Depth of Field:
        - Near: \(String(format: "%.2f", nearLimit))m
        - Far: \(farStr)m
        - Total: \(depthStr)m
        - Hyperfocal: \(String(format: "%.2f", hyperfocalDistance))m
        """
    }
}

/// Informazioni X-Pan
public struct XPanInfo {
    public let format: String
    public let focalLength: Double
    public let equivalent35mm: Double
    public let horizontalFOV: Double
    public let verticalFOV: Double
    public let aspectRatio: Double
    public let diagonal: Double
    
    public var description: String {
        return """
        X-Pan Format Info:
        - Format: \(format)
        - Focal Length: \(String(format: "%.1f", focalLength))mm
        - 35mm Equivalent: \(String(format: "%.1f", equivalent35mm))mm
        - Horizontal FOV: \(String(format: "%.1f", horizontalFOV))°
        - Vertical FOV: \(String(format: "%.1f", verticalFOV))°
        - Aspect Ratio: \(String(format: "%.2f", aspectRatio)):1
        """
    }
}

/// Tipi di scena panoramica
public enum PanoramicSceneType {
    case landscape
    case cityscape
    case seascape
    case portraitEnvironmental
}
