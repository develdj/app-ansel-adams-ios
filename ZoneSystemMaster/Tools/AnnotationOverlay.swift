//
//  AnnotationOverlay.swift
//  Zone System Master - Photo Editor Engine
//  Annotation overlay for zone marking (Ansel Adams style)
//

import Foundation
import Metal
import CoreImage
import SwiftUI

// MARK: - Annotation Element

public enum AnnotationElementType: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case line = "Line"
    case freehand = "Freehand"
    case text = "Text"
    case bezier = "Bezier Curve"
    case cross = "Cross"
    case ellipse = "Ellipse"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .circle: return "circle"
        case .arrow: return "arrow.right"
        case .rectangle: return "rectangle"
        case .line: return "line.diagonal"
        case .freehand: return "scribble"
        case .text: return "textformat"
        case .bezier: return "waveform.path.ecg"
        case .cross: return "plus"
        case .ellipse: return "oval"
        }
    }
}

// MARK: - Annotation Element

public struct AnnotationElement: Identifiable, Equatable {
    public let id = UUID()
    public var type: AnnotationElementType
    public var points: [CGPoint]
    public var color: Color
    public var lineWidth: CGFloat
    public var text: String?
    public var fontSize: CGFloat
    public var opacity: Double
    public var isDashed: Bool
    public var arrowHeadSize: CGFloat
    public var rotation: Double
    
    public init(
        type: AnnotationElementType,
        points: [CGPoint] = [],
        color: Color = .red,
        lineWidth: CGFloat = 2.0,
        text: String? = nil,
        fontSize: CGFloat = 14.0,
        opacity: Double = 0.9,
        isDashed: Bool = false,
        arrowHeadSize: CGFloat = 10.0,
        rotation: Double = 0
    ) {
        self.type = type
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
        self.text = text
        self.fontSize = fontSize
        self.opacity = opacity
        self.isDashed = isDashed
        self.arrowHeadSize = arrowHeadSize
        self.rotation = rotation
    }
    
    public static func == (lhs: AnnotationElement, rhs: AnnotationElement) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Create a zone marker annotation
    public static func zoneMarker(
        zone: Int,
        at point: CGPoint,
        color: Color = .yellow
    ) -> AnnotationElement {
        AnnotationElement(
            type: .circle,
            points: [point],
            color: color,
            lineWidth: 2.0,
            text: "Z\(zone)",
            fontSize: 12.0,
            opacity: 0.8
        )
    }
    
    /// Create an exposure adjustment annotation
    public static func exposureAdjustment(
        stops: String,
        at point: CGPoint,
        color: Color = .red
    ) -> AnnotationElement {
        AnnotationElement(
            type: .arrow,
            points: [point, CGPoint(x: point.x + 50, y: point.y)],
            color: color,
            lineWidth: 2.0,
            text: stops,
            fontSize: 14.0,
            opacity: 0.9
        )
    }
}

// MARK: - Annotation Layer

public struct AnnotationLayer: Identifiable {
    public let id = UUID()
    public var name: String
    public var elements: [AnnotationElement]
    public var isVisible: Bool
    public var opacity: Double
    
    public init(
        name: String,
        elements: [AnnotationElement] = [],
        isVisible: Bool = true,
        opacity: Double = 1.0
    ) {
        self.name = name
        self.elements = elements
        self.isVisible = isVisible
        self.opacity = opacity
    }
}

// MARK: - Annotation Overlay

public final class AnnotationOverlay: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var layers: [AnnotationLayer] = []
    @Published public var currentElement: AnnotationElement?
    @Published public var selectedElementID: UUID?
    @Published public var selectedLayerID: UUID?
    @Published public var isDrawing = false
    
    // MARK: - Settings
    
    @Published public var currentColor: Color = .red
    @Published public var currentLineWidth: CGFloat = 2.0
    @Published public var currentFontSize: CGFloat = 14.0
    @Published public var currentOpacity: Double = 0.9
    @Published public var currentType: AnnotationElementType = .circle
    
    // MARK: - Metal Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    // MARK: - Image Properties
    
    private var imageSize: CGSize = .zero
    
    // MARK: - History
    
    private var layerHistory: [[AnnotationLayer]] = []
    private var historyIndex = -1
    private let maxHistorySize = 30
    
    // MARK: - Initialization
    
    public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        
        // Create default layer
        let defaultLayer = AnnotationLayer(name: "Annotations")
        layers.append(defaultLayer)
        selectedLayerID = defaultLayer.id
        
        saveToHistory()
    }
    
    // MARK: - Setup
    
    public func setup(with imageSize: CGSize) {
        self.imageSize = imageSize
    }
    
    // MARK: - Layer Management
    
    public func addLayer(name: String) {
        let layer = AnnotationLayer(name: name)
        layers.append(layer)
        selectedLayerID = layer.id
        saveToHistory()
    }
    
    public func removeLayer(id: UUID) {
        layers.removeAll { $0.id == id }
        if layers.isEmpty {
            let defaultLayer = AnnotationLayer(name: "Annotations")
            layers.append(defaultLayer)
            selectedLayerID = defaultLayer.id
        }
        saveToHistory()
    }
    
    public func getLayer(id: UUID) -> AnnotationLayer? {
        layers.first { $0.id == id }
    }
    
    public func getSelectedLayer() -> AnnotationLayer? {
        guard let selectedLayerID = selectedLayerID else { return nil }
        return getLayer(id: selectedLayerID)
    }
    
    public func updateLayer(_ layer: AnnotationLayer) {
        if let index = layers.firstIndex(where: { $0.id == layer.id }) {
            layers[index] = layer
            saveToHistory()
        }
    }
    
    // MARK: - Element Creation
    
    public func beginElement(at point: CGPoint, type: AnnotationElementType) {
        isDrawing = true
        currentElement = AnnotationElement(
            type: type,
            points: [point],
            color: currentColor,
            lineWidth: currentLineWidth,
            fontSize: currentFontSize,
            opacity: currentOpacity
        )
    }
    
    public func continueElement(to point: CGPoint) {
        guard isDrawing, var element = currentElement else { return }
        
        switch element.type {
        case .circle, .rectangle, .ellipse:
            // For shapes, update the second point to define size
            if element.points.count == 1 {
                element.points.append(point)
            } else {
                element.points[1] = point
            }
        case .arrow, .line:
            // For arrows and lines, update the end point
            if element.points.count == 1 {
                element.points.append(point)
            } else {
                element.points[1] = point
            }
        case .freehand, .bezier:
            // For freehand, add points
            element.points.append(point)
        case .text, .cross:
            // For text and cross, just update position
            if element.points.isEmpty {
                element.points.append(point)
            } else {
                element.points[0] = point
            }
        }
        
        currentElement = element
    }
    
    public func endElement() {
        guard isDrawing, let element = currentElement else { return }
        
        isDrawing = false
        currentElement = nil
        
        // Add to current layer
        guard let selectedLayerID = selectedLayerID,
              let index = layers.firstIndex(where: { $0.id == selectedLayerID }) else { return }
        
        var layer = layers[index]
        layer.elements.append(element)
        layers[index] = layer
        
        saveToHistory()
    }
    
    public func cancelElement() {
        isDrawing = false
        currentElement = nil
    }
    
    // MARK: - Element Editing
    
    public func updateElement(_ element: AnnotationElement) {
        for (layerIndex, layer) in layers.enumerated() {
            if let elementIndex = layer.elements.firstIndex(where: { $0.id == element.id }) {
                layers[layerIndex].elements[elementIndex] = element
                saveToHistory()
                return
            }
        }
    }
    
    public func removeElement(id: UUID) {
        for (layerIndex, layer) in layers.enumerated() {
            if let elementIndex = layer.elements.firstIndex(where: { $0.id == id }) {
                layers[layerIndex].elements.remove(at: elementIndex)
                saveToHistory()
                return
            }
        }
    }
    
    public func moveElement(id: UUID, by offset: CGSize) {
        for (layerIndex, layer) in layers.enumerated() {
            if let elementIndex = layer.elements.firstIndex(where: { $0.id == id }) {
                var element = layer.elements[elementIndex]
                element.points = element.points.map {
                    CGPoint(x: $0.x + offset.width, y: $0.y + offset.height)
                }
                layers[layerIndex].elements[elementIndex] = element
                saveToHistory()
                return
            }
        }
    }
    
    public func rotateElement(id: UUID, by angle: Double) {
        for (layerIndex, layer) in layers.enumerated() {
            if let elementIndex = layer.elements.firstIndex(where: { $0.id == id }) {
                var element = layer.elements[elementIndex]
                element.rotation += angle
                layers[layerIndex].elements[elementIndex] = element
                saveToHistory()
                return
            }
        }
    }
    
    // MARK: - Selection
    
    public func selectElement(at point: CGPoint, tolerance: CGFloat = 10) -> AnnotationElement? {
        for layer in layers where layer.isVisible {
            for element in layer.elements {
                if isPoint(point, near: element, tolerance: tolerance) {
                    selectedElementID = element.id
                    return element
                }
            }
        }
        selectedElementID = nil
        return nil
    }
    
    private func isPoint(_ point: CGPoint, near element: AnnotationElement, tolerance: CGFloat) -> Bool {
        switch element.type {
        case .circle, .ellipse:
            guard element.points.count >= 2 else { return false }
            let center = element.points[0]
            let radius = hypot(element.points[1].x - center.x, element.points[1].y - center.y)
            let distance = hypot(point.x - center.x, point.y - center.y)
            return abs(distance - radius) < tolerance
            
        case .rectangle:
            guard element.points.count >= 2 else { return false }
            let rect = CGRect(
                x: min(element.points[0].x, element.points[1].x),
                y: min(element.points[0].y, element.points[1].y),
                width: abs(element.points[1].x - element.points[0].x),
                height: abs(element.points[1].y - element.points[0].y)
            )
            let expandedRect = rect.insetBy(dx: -tolerance, dy: -tolerance)
            return expandedRect.contains(point) && !rect.insetBy(dx: tolerance, dy: tolerance).contains(point)
            
        case .arrow, .line:
            guard element.points.count >= 2 else { return false }
            return distanceFromPointToLine(point, lineStart: element.points[0], lineEnd: element.points[1]) < tolerance
            
        case .freehand, .bezier:
            for i in 0..<(element.points.count - 1) {
                if distanceFromPointToLine(point, lineStart: element.points[i], lineEnd: element.points[i + 1]) < tolerance {
                    return true
                }
            }
            return false
            
        case .text, .cross:
            guard let firstPoint = element.points.first else { return false }
            return hypot(point.x - firstPoint.x, point.y - firstPoint.y) < tolerance * 2
        }
    }
    
    private func distanceFromPointToLine(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let length = hypot(dx, dy)
        
        guard length > 0 else { return hypot(point.x - lineStart.x, point.y - lineStart.y) }
        
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (length * length)))
        let projection = CGPoint(
            x: lineStart.x + t * dx,
            y: lineStart.y + t * dy
        )
        
        return hypot(point.x - projection.x, point.y - projection.y)
    }
    
    // MARK: - Apply to Image
    
    public func apply(to image: CIImage) async -> CIImage {
        // Create a graphics context to render annotations
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: image.extent.size, format: format)
        
        let annotationImage = renderer.image { context in
            let cgContext = context.cgContext
            
            for layer in layers where layer.isVisible {
                for element in layer.elements {
                    renderElement(element, in: cgContext, with: layer.opacity)
                }
            }
            
            // Render current element if drawing
            if isDrawing, let currentElement = currentElement {
                renderElement(currentElement, in: cgContext, with: 1.0)
            }
        }
        
        // Convert to CIImage and blend
        guard let cgImage = annotationImage.cgImage else { return image }
        let annotationCIImage = CIImage(cgImage: cgImage)
        
        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.inputImage = annotationCIImage
        blendFilter.backgroundImage = image
        
        return blendFilter.outputImage ?? image
    }
    
    private func renderElement(_ element: AnnotationElement, in context: CGContext, with layerOpacity: Double) {
        let color = element.color.opacity(element.opacity * layerOpacity)
        
        guard let cgColor = color.cgColor else { return }
        context.setStrokeColor(cgColor)
        context.setLineWidth(element.lineWidth)
        
        if element.isDashed {
            context.setLineDash(phase: 0, lengths: [5, 5])
        } else {
            context.setLineDash(phase: 0, lengths: [])
        }
        
        switch element.type {
        case .circle:
            guard element.points.count >= 2 else { return }
            let center = element.points[0]
            let radius = hypot(element.points[1].x - center.x, element.points[1].y - center.y)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.strokeEllipse(in: rect)
            
        case .ellipse:
            guard element.points.count >= 2 else { return }
            let rect = CGRect(
                x: min(element.points[0].x, element.points[1].x),
                y: min(element.points[0].y, element.points[1].y),
                width: abs(element.points[1].x - element.points[0].x),
                height: abs(element.points[1].y - element.points[0].y)
            )
            context.strokeEllipse(in: rect)
            
        case .rectangle:
            guard element.points.count >= 2 else { return }
            let rect = CGRect(
                x: min(element.points[0].x, element.points[1].x),
                y: min(element.points[0].y, element.points[1].y),
                width: abs(element.points[1].x - element.points[0].x),
                height: abs(element.points[1].y - element.points[0].y)
            )
            context.stroke(rect)
            
        case .line, .arrow:
            guard element.points.count >= 2 else { return }
            context.move(to: element.points[0])
            context.addLine(to: element.points[1])
            context.strokePath()
            
            // Draw arrow head if arrow type
            if element.type == .arrow {
                drawArrowHead(at: element.points[1], from: element.points[0], size: element.arrowHeadSize, in: context)
            }
            
        case .freehand, .bezier:
            guard element.points.count >= 2 else { return }
            context.move(to: element.points[0])
            for i in 1..<element.points.count {
                context.addLine(to: element.points[i])
            }
            context.strokePath()
            
        case .cross:
            guard let center = element.points.first else { return }
            let size: CGFloat = 10
            context.move(to: CGPoint(x: center.x - size, y: center.y))
            context.addLine(to: CGPoint(x: center.x + size, y: center.y))
            context.move(to: CGPoint(x: center.x, y: center.y - size))
            context.addLine(to: CGPoint(x: center.x, y: center.y + size))
            context.strokePath()
            
        case .text:
            guard let text = element.text, let center = element.points.first else { return }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: element.fontSize),
                .foregroundColor: UIColor(cgColor: cgColor) ?? .red
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: center.x - textSize.width / 2,
                y: center.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func drawArrowHead(at point: CGPoint, from start: CGPoint, size: CGFloat, in context: CGContext) {
        let angle = atan2(point.y - start.y, point.x - start.x)
        let arrowAngle = CGFloat.pi / 6 // 30 degrees
        
        let leftAngle = angle + CGFloat.pi - arrowAngle
        let rightAngle = angle + CGFloat.pi + arrowAngle
        
        let leftPoint = CGPoint(
            x: point.x + size * cos(leftAngle),
            y: point.y + size * sin(leftAngle)
        )
        let rightPoint = CGPoint(
            x: point.x + size * cos(rightAngle),
            y: point.y + size * sin(rightAngle)
        )
        
        context.move(to: point)
        context.addLine(to: leftPoint)
        context.move(to: point)
        context.addLine(to: rightPoint)
        context.strokePath()
    }
    
    // MARK: - History Management
    
    private func saveToHistory() {
        if historyIndex < layerHistory.count - 1 {
            layerHistory.removeSubrange((historyIndex + 1)...)
        }
        
        layerHistory.append(layers)
        
        if layerHistory.count > maxHistorySize {
            layerHistory.removeFirst()
        } else {
            historyIndex += 1
        }
    }
    
    public func undo() {
        guard historyIndex > 0 else { return }
        
        historyIndex -= 1
        layers = layerHistory[historyIndex]
    }
    
    public func redo() {
        guard historyIndex < layerHistory.count - 1 else { return }
        
        historyIndex += 1
        layers = layerHistory[historyIndex]
    }
    
    // MARK: - Clear
    
    public func clearAnnotations() {
        layers.removeAll()
        let defaultLayer = AnnotationLayer(name: "Annotations")
        layers.append(defaultLayer)
        selectedLayerID = defaultLayer.id
        saveToHistory()
    }
    
    public func clearLayer(id: UUID) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].elements.removeAll()
            saveToHistory()
        }
    }
    
    // MARK: - Presets
    
    public func createZoneMarkers(for zones: [Int], in imageSize: CGSize) {
        // Create zone markers at specific positions
        var elements: [AnnotationElement] = []
        
        for (index, zone) in zones.enumerated() {
            let x = CGFloat(index + 1) * imageSize.width / CGFloat(zones.count + 1)
            let y = imageSize.height * 0.1
            
            elements.append(AnnotationElement.zoneMarker(zone: zone, at: CGPoint(x: x, y: y)))
        }
        
        let layer = AnnotationLayer(name: "Zone Markers", elements: elements)
        layers.append(layer)
        saveToHistory()
    }
    
    public func createExposureGuide(stops: [(String, CGPoint)]) {
        var elements: [AnnotationElement] = []
        
        for (stopsText, position) in stops {
            elements.append(AnnotationElement.exposureAdjustment(stops: stopsText, at: position))
        }
        
        let layer = AnnotationLayer(name: "Exposure Guide", elements: elements)
        layers.append(layer)
        saveToHistory()
    }
}

// MARK: - Annotation Overlay Extensions

extension AnnotationOverlay {
    
    /// Check if can undo
    public var canUndo: Bool {
        historyIndex > 0
    }
    
    /// Check if can redo
    public var canRedo: Bool {
        historyIndex < layerHistory.count - 1
    }
    
    /// Get total element count
    public var totalElementCount: Int {
        layers.reduce(0) { $0 + $1.elements.count }
    }
    
    /// Get visible element count
    public var visibleElementCount: Int {
        layers.filter { $0.isVisible }.reduce(0) { $0 + $1.elements.count }
    }
    
    /// Toggle layer visibility
    public func toggleLayerVisibility(id: UUID) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].isVisible.toggle()
        }
    }
    
    /// Rename layer
    public func renameLayer(id: UUID, to newName: String) {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers[index].name = newName
        }
    }
    
    /// Move layer up
    public func moveLayerUp(id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }), index < layers.count - 1 else { return }
        layers.swapAt(index, index + 1)
    }
    
    /// Move layer down
    public func moveLayerDown(id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }), index > 0 else { return }
        layers.swapAt(index, index - 1)
    }
    
    /// Export annotations as JSON
    public func exportAnnotations() -> Data? {
        // Implementation for exporting annotations
        return nil
    }
    
    /// Import annotations from JSON
    public func importAnnotations(from data: Data) {
        // Implementation for importing annotations
    }
}
