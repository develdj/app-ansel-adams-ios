//
//  ZoneSystemEditorView.swift
//  Zone System Master - Photo Editor Engine
//  Main editor view with SwiftUI
//

import SwiftUI
import CoreImage
import PhotosUI

// MARK: - Main Editor View

@MainActor
public struct ZoneSystemEditorView: View {
    
    @StateObject private var engine: EditorEngine
    @State private var selectedTool: EditingTool = .adjustments
    @State private var showExportSheet = false
    @State private var showImagePicker = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var showHistogram = false
    @State private var showZoneAnalysis = false
    
    public init() {
        guard let engine = EditorEngine() else {
            fatalError("Failed to create EditorEngine")
        }
        _engine = StateObject(wrappedValue: engine)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                HStack(spacing: 0) {
                    // Left sidebar - Tools
                    toolSidebar
                        .frame(width: 280)
                    
                    Divider()
                    
                    // Center - Image canvas
                    imageCanvas
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Divider()
                    
                    // Right sidebar - Adjustments
                    adjustmentPanel
                        .frame(width: 320)
                }
                
                // Processing overlay
                if case .processing(let progress) = engine.processingState {
                    processingOverlay(progress: progress)
                }
            }
            .navigationTitle("Zone System Master")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showExportSheet) {
                ExportView(engine: engine)
            }
            .photosPicker(
                isPresented: $showImagePicker,
                selection: $selectedImage,
                matching: .images
            )
            .onChange(of: selectedImage) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await engine.loadImage(uiImage)
                    }
                }
            }
        }
    }
    
    // MARK: - Tool Sidebar
    
    private var toolSidebar: some View {
        VStack(spacing: 0) {
            // Tool selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Tools")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                ForEach(EditingTool.allCases) { tool in
                    ToolButton(
                        tool: tool,
                        isSelected: selectedTool == tool
                    ) {
                        selectedTool = tool
                    }
                }
            }
            
            Divider()
                .padding(.vertical)
            
            // Layer panel
            LayerPanel(engine: engine)
            
            Spacer()
            
            // Undo/Redo
            HStack(spacing: 16) {
                Button(action: { engine.undoManager.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!engine.canUndo)
                
                Button(action: { engine.undoManager.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!engine.canRedo)
                
                Spacer()
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Image Canvas
    
    private var imageCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemBackground)
                
                // Image
                if let previewImage = engine.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(engine.zoomScale)
                        .offset(engine.viewOffset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    engine.zoomScale = value
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    engine.viewOffset = value.translation
                                }
                        )
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Image Loaded")
                            .foregroundColor(.secondary)
                        Button("Load Image") {
                            showImagePicker = true
                        }
                        .padding(.top)
                    }
                }
                
                // Zone overlay
                if showZoneAnalysis {
                    ZoneOverlayView(engine: engine)
                }
                
                // Annotation overlay
                if selectedTool == .annotations {
                    AnnotationCanvas(engine: engine)
                }
            }
        }
    }
    
    // MARK: - Adjustment Panel
    
    private var adjustmentPanel: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text(selectedTool.title)
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            // Tool-specific controls
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTool {
                    case .adjustments:
                        AdjustmentControls(engine: engine)
                    case .curves:
                        CurveEditorPanel(engine: engine)
                    case .masks:
                        MaskPanel(engine: engine)
                    case .dodgeBurn:
                        DodgeBurnPanel(engine: engine)
                    case .grain:
                        GrainPanel(engine: engine)
                    case .annotations:
                        AnnotationPanel(engine: engine)
                    case .export:
                        ExportPanel(engine: engine)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button("Open Image...") {
                    showImagePicker = true
                }
                Button("Open RAW...") {
                    // RAW import
                }
                Divider()
                Button("Recent Files") {
                    // Show recent files
                }
            } label: {
                Image(systemName: "folder")
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                Button(action: { showHistogram.toggle() }) {
                    Image(systemName: "chart.bar")
                }
                
                Button(action: { showZoneAnalysis.toggle() }) {
                    Image(systemName: "circle.grid.2x2")
                }
                
                Button(action: { engine.resetAllSettings() }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                
                Button("Export") {
                    showExportSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Processing Overlay
    
    private func processingOverlay(progress: Float) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .frame(width: 200)
                Text("Processing... \(Int(progress * 100))%")
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Editing Tool

public enum EditingTool: String, CaseIterable, Identifiable {
    case adjustments = "Adjustments"
    case curves = "Curves"
    case masks = "Masks"
    case dodgeBurn = "Dodge & Burn"
    case grain = "Film Grain"
    case annotations = "Annotations"
    case export = "Export"
    
    public var id: String { rawValue }
    
    public var title: String { rawValue }
    
    public var icon: String {
        switch self {
        case .adjustments: return "slider.horizontal.3"
        case .curves: return "waveform.path"
        case .masks: return "circle.dashed"
        case .dodgeBurn: return "circle.circle"
        case .grain: return "film"
        case .annotations: return "pencil.tip"
        case .export: return "square.and.arrow.up"
        }
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: EditingTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .frame(width: 24)
                Text(tool.title)
                    .font(.system(size: 14))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Adjustment Controls

struct AdjustmentControls: View {
    @ObservedObject var engine: EditorEngine
    
    var body: some View {
        VStack(spacing: 20) {
            // B&W Conversion
            Section(header: Text("Black & White").font(.subheadline).foregroundColor(.secondary)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filter Simulation")
                        .font(.caption)
                    
                    Picker("Filter", selection: .constant(0)) {
                        Text("None").tag(0)
                        Text("Red").tag(1)
                        Text("Orange").tag(2)
                        Text("Yellow").tag(3)
                        Text("Green").tag(4)
                        Text("Blue").tag(5)
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("R")
                        Slider(value: $engine.bwSettings.redFilter, in: 0...1)
                    }
                    HStack {
                        Text("G")
                        Slider(value: $engine.bwSettings.greenFilter, in: 0...1)
                    }
                    HStack {
                        Text("B")
                        Slider(value: $engine.bwSettings.blueFilter, in: 0...1)
                    }
                }
                
                HStack {
                    Text("Contrast")
                    Slider(value: $engine.bwSettings.contrast, in: 0.5...2.0)
                }
                
                HStack {
                    Text("Brightness")
                    Slider(value: $engine.bwSettings.brightness, in: -0.5...0.5)
                }
            }
            
            Divider()
            
            // Vignette
            Section(header: Text("Vignette").font(.subheadline).foregroundColor(.secondary)) {
                Toggle("Enable", isOn: $engine.vignetteSettings.enabled)
                
                if engine.vignetteSettings.enabled {
                    HStack {
                        Text("Intensity")
                        Slider(value: $engine.vignetteSettings.intensity, in: 0...1)
                    }
                    HStack {
                        Text("Radius")
                        Slider(value: $engine.vignetteSettings.radius, in: 0.3...1.0)
                    }
                    HStack {
                        Text("Feather")
                        Slider(value: $engine.vignetteSettings.feather, in: 0...0.5)
                    }
                }
            }
            
            Divider()
            
            // Sharpening
            Section(header: Text("Sharpening").font(.subheadline).foregroundColor(.secondary)) {
                Toggle("Enable", isOn: $engine.sharpeningSettings.enabled)
                
                if engine.sharpeningSettings.enabled {
                    HStack {
                        Text("Amount")
                        Slider(value: $engine.sharpeningSettings.amount, in: 0...2)
                    }
                    HStack {
                        Text("Radius")
                        Slider(value: $engine.sharpeningSettings.radius, in: 0.5...5)
                    }
                }
            }
        }
    }
}

// MARK: - Layer Panel

struct LayerPanel: View {
    @ObservedObject var engine: EditorEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Layers")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            List {
                ForEach(engine.layerManager.layers, id: \.id) { layer in
                    LayerRow(layer: layer)
                }
                .onMove { indices, newOffset in
                    engine.layerManager.moveLayer(from: indices, to: newOffset)
                }
            }
            .listStyle(.plain)
            .frame(height: 150)
        }
    }
}

struct LayerRow: View {
    let layer: any Layer
    
    var body: some View {
        HStack {
            Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                .foregroundColor(.secondary)
            Text(layer.name)
                .font(.system(size: 12))
            Spacer()
            Text("\(Int(layer.opacity * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ZoneSystemEditorView()
}
