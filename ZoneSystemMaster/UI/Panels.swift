//
//  Panels.swift
//  Zone System Master - Photo Editor Engine
//  UI Panels for various editing tools
//

import SwiftUI

// MARK: - Curve Editor Panel

struct CurveEditorPanel: View {
    @ObservedObject var engine: EditorEngine
    @State private var selectedChannel: CurveChannel = .luminance
    @State private var selectedCurveType: FilmCurveType = .linear
    
    var body: some View {
        VStack(spacing: 16) {
            // Channel selector
            Picker("Channel", selection: $selectedChannel) {
                ForEach(CurveChannel.allCases) { channel in
                    Text(channel.rawValue).tag(channel)
                }
            }
            .pickerStyle(.segmented)
            
            // Curve presets
            Menu("Presets") {
                ForEach(FilmCurveType.allCases) { type in
                    Button(type.rawValue) {
                        engine.curveEditor.applyPreset(type, to: selectedChannel)
                        Task { await engine.processImage() }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Curve view
            CurveGraphView(
                curveEditor: engine.curveEditor,
                channel: selectedChannel
            )
            .frame(height: 200)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Zone markers toggle
            Toggle("Show Zone Markers", isOn: $engine.curveEditor.snapToZones)
            
            Divider()
            
            // Curve parameters
            VStack(spacing: 12) {
                HStack {
                    Text("Black Point")
                    Spacer()
                    Slider(value: $engine.curveSettings.blackPoint, in: 0...0.5)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("White Point")
                    Spacer()
                    Slider(value: $engine.curveSettings.whitePoint, in: 0.5...1)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Gamma")
                    Spacer()
                    Slider(value: $engine.curveSettings.gamma, in: 0.5...2.5)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Contrast")
                    Spacer()
                    Slider(value: $engine.curveSettings.contrast, in: 0.5...2.0)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Toe")
                    Spacer()
                    Slider(value: $engine.curveSettings.toe, in: 0...0.5)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Shoulder")
                    Spacer()
                    Slider(value: $engine.curveSettings.shoulder, in: 0...0.5)
                        .frame(width: 150)
                }
            }
            
            // Action buttons
            HStack {
                Button("Reset") {
                    engine.curveEditor.resetCurve(for: selectedChannel)
                    Task { await engine.processImage() }
                }
                
                Button("Optimize for Zones") {
                    engine.curveEditor.optimizeForZoneSystem()
                    Task { await engine.processImage() }
                }
                
                Spacer()
                
                Button("Apply") {
                    Task { await engine.processImage() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Curve Graph View

struct CurveGraphView: View {
    @ObservedObject var curveEditor: CurveEditor
    let channel: CurveChannel
    
    @State private var selectedPointID: UUID?
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid
                CurveGridView()
                
                // Zone markers
                if curveEditor.snapToZones {
                    ZoneMarkersView(in: geometry.size)
                }
                
                // Curve
                CurvePathView(
                    curveEditor: curveEditor,
                    channel: channel,
                    size: geometry.size
                )
                
                // Control points
                if let curve = curveEditor.getCurve(for: channel) {
                    ForEach(curve.points, id: \.id) { point in
                        ControlPointView(
                            point: point,
                            isSelected: selectedPointID == point.id,
                            size: geometry.size
                        )
                        .position(
                            x: point.x * geometry.size.width,
                            y: geometry.size.height - point.y * geometry.size.height
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    selectedPointID = point.id
                                    
                                    let newX = max(0, min(1, value.location.x / geometry.size.width))
                                    let newY = max(0, min(1, 1 - value.location.y / geometry.size.height))
                                    
                                    if let index = curve.points.firstIndex(where: { $0.id == point.id }) {
                                        curveEditor.movePoint(
                                            at: index,
                                            in: channel,
                                            to: CGPoint(x: newX, y: newY)
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                    }
                }
                
                // Diagonal reference line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

struct CurveGridView: View {
    var body: some View {
        GeometryReader { geometry in
            // Horizontal lines
            ForEach(0..<5) { i in
                let y = CGFloat(i) * geometry.size.height / 4
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
            
            // Vertical lines
            ForEach(0..<5) { i in
                let x = CGFloat(i) * geometry.size.width / 4
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
}

struct ZoneMarkersView: View {
    let size: CGSize
    
    var body: some View {
        ForEach(0..<11) { zone in
            let x = CGFloat(zone) * size.width / 10
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            .stroke(Color.yellow.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
        }
    }
}

struct CurvePathView: View {
    @ObservedObject var curveEditor: CurveEditor
    let channel: CurveChannel
    let size: CGSize
    
    var body: some View {
        if let curve = curveEditor.getCurve(for: channel) {
            let points = curve.points.sorted { $0.x < $1.x }
            
            Path { path in
                guard !points.isEmpty else { return }
                
                let firstPoint = CGPoint(
                    x: points[0].x * size.width,
                    y: size.height - points[0].y * size.height
                )
                path.move(to: firstPoint)
                
                for i in 1..<points.count {
                    let point = CGPoint(
                        x: points[i].x * size.width,
                        y: size.height - points[i].y * size.height
                    )
                    path.addLine(to: point)
                }
            }
            .stroke(channel.color, lineWidth: 2)
        }
    }
}

struct ControlPointView: View {
    let point: CurvePoint
    let isSelected: Bool
    let size: CGSize
    
    var body: some View {
        Circle()
            .fill(point.isFixed ? Color.gray : (isSelected ? Color.accentColor : Color.white))
            .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}

// MARK: - Mask Panel

struct MaskPanel: View {
    @ObservedObject var engine: EditorEngine
    @State private var selectedMaskType: LuminosityMaskType = .lights
    @State private var featherAmount: Float = 0.1
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Mask type selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Mask Type")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Mask Type", selection: $selectedMaskType) {
                    ForEach(LuminosityMaskType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Zone range info
            VStack(alignment: .leading, spacing: 4) {
                Text("Zone Range: \(String(format: "%.1f", selectedMaskType.zoneRange.lowerBound)) - \(String(format: "%.1f", selectedMaskType.zoneRange.upperBound))")
                    .font(.caption)
                Text(selectedMaskType.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Feather control
            HStack {
                Text("Feather")
                Slider(value: $featherAmount, in: 0...0.5)
            }
            
            // Generate button
            Button(action: {
                Task {
                    isGenerating = true
                    await engine.luminosityMaskEngine.generateMask(type: selectedMaskType)
                    isGenerating = false
                }
            }) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Generate Mask")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating)
            
            Divider()
            
            // Generated masks list
            Text("Generated Masks")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            List(engine.luminosityMaskEngine.masks) { mask in
                HStack {
                    // Mask preview thumbnail
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 30)
                    
                    VStack(alignment: .leading) {
                        Text(mask.name)
                            .font(.system(size: 13))
                        Text("Zone \(String(format: "%.1f", mask.minZone)) - \(String(format: "%.1f", mask.maxZone))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        engine.luminosityMaskEngine.removeMask(id: mask.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .frame(height: 150)
            
            // Actions
            HStack {
                Button("Generate All") {
                    Task {
                        await engine.luminosityMaskEngine.generateAllZoneMasks()
                    }
                }
                
                Spacer()
                
                Button("Clear All") {
                    engine.luminosityMaskEngine.removeAllMasks()
                }
                .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Dodge & Burn Panel

struct DodgeBurnPanel: View {
    @ObservedObject var engine: EditorEngine
    
    var body: some View {
        VStack(spacing: 16) {
            // Mode selector
            Picker("Mode", selection: $engine.dodgeBurnTool.settings.mode) {
                ForEach(DodgeBurnMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // Brush settings
            VStack(spacing: 12) {
                HStack {
                    Text("Brush Size")
                    Spacer()
                    Slider(value: $engine.dodgeBurnTool.settings.brushSize, in: 10...200)
                        .frame(width: 150)
                    Text("\(Int(engine.dodgeBurnTool.settings.brushSize))")
                        .font(.caption)
                        .frame(width: 30, alignment: .trailing)
                }
                
                HStack {
                    Text("Hardness")
                    Spacer()
                    Slider(value: $engine.dodgeBurnTool.settings.brushHardness, in: 0...1)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Intensity")
                    Spacer()
                    Slider(value: $engine.dodgeBurnTool.settings.intensity, in: 0...2)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Exposure Time")
                    Spacer()
                    Slider(value: $engine.dodgeBurnTool.settings.exposureTime, in: 0.1...5)
                        .frame(width: 150)
                }
            }
            
            // Brush shape
            VStack(alignment: .leading, spacing: 8) {
                Text("Brush Shape")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Shape", selection: $engine.dodgeBurnTool.settings.brushShape) {
                    ForEach(BrushShape.allCases) { shape in
                        Text(shape.rawValue).tag(shape)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Brush preview
            BrushPreviewView(settings: engine.dodgeBurnTool.settings)
                .frame(height: 100)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Divider()
            
            // Strokes info
            HStack {
                Text("Strokes: \(engine.dodgeBurnTool.strokeCount)")
                    .font(.caption)
                Spacer()
                Text("Points: \(engine.dodgeBurnTool.totalPointCount)")
                    .font(.caption)
            }
            
            // Actions
            HStack {
                Button("Undo") {
                    engine.dodgeBurnTool.undo()
                }
                .disabled(!engine.dodgeBurnTool.canUndo)
                
                Button("Redo") {
                    engine.dodgeBurnTool.redo()
                }
                .disabled(!engine.dodgeBurnTool.canRedo)
                
                Spacer()
                
                Button("Clear All") {
                    engine.dodgeBurnTool.clearStrokes()
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct BrushPreviewView: View {
    let settings: DodgeBurnSettings
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient to show effect
                LinearGradient(
                    colors: [.black, .gray, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                // Brush preview
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: settings.mode == .dodge ? Color.white.opacity(0.5) : Color.black.opacity(0.5), location: 0),
                                .init(color: Color.clear, location: CGFloat(settings.brushHardness))
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: settings.brushSize / 2
                        )
                    )
                    .frame(width: settings.brushSize, height: settings.brushSize)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
}

// MARK: - Grain Panel

struct GrainPanel: View {
    @ObservedObject var engine: EditorEngine
    
    var body: some View {
        VStack(spacing: 16) {
            // Enable toggle
            Toggle("Enable Film Grain", isOn: $engine.filmGrainSettings.enabled)
            
            if engine.filmGrainSettings.enabled {
                // Film type selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Film Type")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Film", selection: $engine.filmGrainSettings.filmType) {
                        ForEach(FilmType.allCases) { film in
                            Text(film.rawValue).tag(film)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Film info
                let film = engine.filmGrainSettings.filmType
                VStack(alignment: .leading, spacing: 4) {
                    Text("ISO \(film.iso)")
                        .font(.caption)
                    Text("Grain: \(String(format: "%.1f", film.grainCharacteristic.intensity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Grain controls
                VStack(spacing: 12) {
                    HStack {
                        Text("Intensity")
                        Spacer()
                        Slider(value: $engine.filmGrainSettings.intensity, in: 0...2)
                            .frame(width: 150)
                    }
                    
                    HStack {
                        Text("Grain Size")
                        Spacer()
                        Slider(value: $engine.filmGrainSettings.grainSize, in: 0.5...2)
                            .frame(width: 150)
                    }
                    
                    HStack {
                        Text("Push/Pull")
                        Spacer()
                        Slider(value: $engine.filmGrainSettings.pushPull, in: -2...2, step: 0.5)
                            .frame(width: 150)
                        Text("\(String(format: "%.1f", engine.filmGrainSettings.pushPull))")
                            .font(.caption)
                            .frame(width: 30)
                    }
                }
                
                Divider()
                
                // Presets
                Text("Presets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    GrainPresetButton(name: "Subtle") {
                        engine.filmGrainSimulator.applyPreset(.subtle)
                    }
                    GrainPresetButton(name: "Medium") {
                        engine.filmGrainSimulator.applyPreset(.medium)
                    }
                    GrainPresetButton(name: "Heavy") {
                        engine.filmGrainSimulator.applyPreset(.heavy)
                    }
                }
            }
            
            Spacer()
            
            Button("Apply") {
                Task { await engine.processImage() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct GrainPresetButton: View {
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Annotation Panel

struct AnnotationPanel: View {
    @ObservedObject var engine: EditorEngine
    @State private var selectedType: AnnotationElementType = .circle
    
    var body: some View {
        VStack(spacing: 16) {
            // Tool selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Annotation Tool")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                    ForEach(AnnotationElementType.allCases) { type in
                        AnnotationToolButton(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                        }
                    }
                }
            }
            
            Divider()
            
            // Style controls
            VStack(spacing: 12) {
                HStack {
                    Text("Color")
                    Spacer()
                    ColorPicker("", selection: $engine.annotationOverlay.currentColor)
                }
                
                HStack {
                    Text("Line Width")
                    Spacer()
                    Slider(value: $engine.annotationOverlay.currentLineWidth, in: 1...10)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Opacity")
                    Spacer()
                    Slider(value: $engine.annotationOverlay.currentOpacity, in: 0.1...1)
                        .frame(width: 150)
                }
                
                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(value: $engine.annotationOverlay.currentFontSize, in: 8...32)
                        .frame(width: 150)
                }
            }
            
            Divider()
            
            // Layers
            Text("Annotation Layers")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            List(engine.annotationOverlay.layers) { layer in
                HStack {
                    Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    Text(layer.name)
                        .font(.system(size: 13))
                    Spacer()
                    Text("\(layer.elements.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(.plain)
            .frame(height: 120)
            
            // Actions
            HStack {
                Button("New Layer") {
                    engine.annotationOverlay.addLayer(name: "Layer \(engine.annotationOverlay.layers.count + 1)")
                }
                
                Spacer()
                
                Button("Clear All") {
                    engine.annotationOverlay.clearAnnotations()
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct AnnotationToolButton: View {
    let type: AnnotationElementType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                Text(type.rawValue)
                    .font(.caption2)
            }
            .frame(width: 60, height: 60)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export Panel

struct ExportPanel: View {
    @ObservedObject var engine: EditorEngine
    @State private var exportSettings = ExportSettings()
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportedData: Data?
    
    var body: some View {
        VStack(spacing: 16) {
            // Format selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Format", selection: $exportSettings.format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Quality
            if exportSettings.format != .png {
                HStack {
                    Text("Quality")
                    Spacer()
                    Slider(value: $exportSettings.quality, in: 0.5...1)
                        .frame(width: 150)
                    Text("\(Int(exportSettings.quality * 100))%")
                        .font(.caption)
                        .frame(width: 35)
                }
            }
            
            // Resolution
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Resolution", selection: $exportSettings.resolution) {
                    ForEach(ExportResolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Color space
            VStack(alignment: .leading, spacing: 8) {
                Text("Color Space")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Color Space", selection: $exportSettings.colorSpace) {
                    ForEach(ExportColorSpace.allCases) { space in
                        Text(space.rawValue).tag(space)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Metadata
            Toggle("Include Metadata", isOn: $exportSettings.includeMetadata)
            
            Spacer()
            
            // Export button
            Button(action: {
                Task {
                    isExporting = true
                    do {
                        exportedData = try await engine.export(with: exportSettings)
                        showShareSheet = true
                    } catch {
                        print("Export failed: \(error)")
                    }
                    isExporting = false
                }
            }) {
                if isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Export Image")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(engine.currentImage == nil || isExporting)
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = exportedData {
                ShareSheet(items: [data])
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Zone Overlay View

struct ZoneOverlayView: View {
    @ObservedObject var engine: EditorEngine
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Zone grid overlay
                ForEach(0..<11) { zone in
                    let luminance = CGFloat(zone) / 10.0
                    Rectangle()
                        .fill(Color(white: luminance).opacity(0.1))
                        .frame(height: geometry.size.height / 11)
                        .position(
                            x: geometry.size.width / 2,
                            y: CGFloat(zone) * geometry.size.height / 11 + geometry.size.height / 22
                        )
                }
                
                // Zone labels
                VStack(alignment: .leading, spacing: 0) {
                    ForEach((0...10).reversed(), id: \.self) { zone in
                        Text("Z\(zone)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(zone > 5 ? .black : .white)
                            .frame(height: geometry.size.height / 11)
                    }
                }
                .position(x: 15, y: geometry.size.height / 2)
            }
        }
    }
}

// MARK: - Annotation Canvas

struct AnnotationCanvas: View {
    @ObservedObject var engine: EditorEngine
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw existing annotations
                for layer in engine.annotationOverlay.layers where layer.isVisible {
                    for element in layer.elements {
                        drawElement(element, in: &context, with: layer.opacity)
                    }
                }
                
                // Draw current element
                if let currentElement = engine.annotationOverlay.currentElement {
                    drawElement(currentElement, in: &context, with: 1.0)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !engine.annotationOverlay.isDrawing {
                            engine.annotationOverlay.beginElement(
                                at: value.location,
                                type: engine.annotationOverlay.currentType
                            )
                        } else {
                            engine.annotationOverlay.continueElement(to: value.location)
                        }
                    }
                    .onEnded { _ in
                        engine.annotationOverlay.endElement()
                    }
            )
        }
    }
    
    private func drawElement(_ element: AnnotationElement, in context: inout GraphicsContext, with layerOpacity: Double) {
        let color = element.color.opacity(element.opacity * layerOpacity)
        let lineWidth = element.lineWidth
        
        var path = Path()
        
        switch element.type {
        case .circle:
            guard element.points.count >= 2 else { return }
            let center = element.points[0]
            let radius = hypot(element.points[1].x - center.x, element.points[1].y - center.y)
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            
        case .rectangle:
            guard element.points.count >= 2 else { return }
            path.addRect(CGRect(
                x: min(element.points[0].x, element.points[1].x),
                y: min(element.points[0].y, element.points[1].y),
                width: abs(element.points[1].x - element.points[0].x),
                height: abs(element.points[1].y - element.points[0].y)
            ))
            
        case .line, .arrow, .freehand:
            guard element.points.count >= 2 else { return }
            path.move(to: element.points[0])
            for point in element.points.dropFirst() {
                path.addLine(to: point)
            }
            
        default:
            break
        }
        
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }
}

// MARK: - Export View

struct ExportView: View {
    @ObservedObject var engine: EditorEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ExportPanel(engine: engine)
                .navigationTitle("Export")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .padding()
        }
    }
}
