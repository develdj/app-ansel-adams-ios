// InstaxPrintView.swift
// Zone System Master - Instax BLE Integration
// Interfaccia utente SwiftUI per stampa Instax

import SwiftUI
import Combine

// MARK: - InstaxPrintView

public struct InstaxPrintView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = InstaxPrintViewModel()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showPrinterSelector = false
    @State private var showSettings = false
    @State private var showPreview = false
    
    private let onPrintComplete: (() -> Void)?
    
    // MARK: - Initialization
    
    public init(onPrintComplete: (() -> Void)? = nil) {
        self.onPrintComplete = onPrintComplete
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stato connessione
                connectionStatusBar
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Preview immagine
                        imagePreviewSection
                        
                        // Info stampante
                        printerInfoSection
                        
                        // Controlli
                        controlsSection
                        
                        // Coda stampe
                        if !viewModel.printQueue.isEmpty {
                            printQueueSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Stampa Instax")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    settingsButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        refreshButton
                        scanButton
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showPrinterSelector) {
                PrinterSelectorView(
                    printers: viewModel.discoveredPrinters,
                    onSelect: { printer in
                        Task {
                            await viewModel.connectToPrinter(printer)
                        }
                    }
                )
            }
            .sheet(isPresented: $showSettings) {
                PrintSettingsView(viewModel: viewModel)
            }
            .alert("Errore", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .onAppear {
                viewModel.onPrintComplete = onPrintComplete
            }
            .onChange(of: selectedImage) { newImage in
                if let image = newImage {
                    viewModel.setImage(image)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var connectionStatusBar: some View {
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 10, height: 10)
            
            Text(viewModel.connectionState.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let printerInfo = viewModel.printerInfo {
                HStack(spacing: 8) {
                    // Batteria
                    HStack(spacing: 4) {
                        Image(systemName: batteryIcon)
                        Text("\(printerInfo.batteryPercentage)%")
                    }
                    
                    // Carta rimanente
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                        Text("\(printerInfo.photosLeft)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.separator),
            alignment: .bottom
        )
    }
    
    private var connectionStatusColor: Color {
        switch viewModel.connectionState {
        case .connected:
            return .green
        case .connecting, .scanning:
            return .orange
        case .error:
            return .red
        default:
            return .gray
        }
    }
    
    private var batteryIcon: String {
        guard let info = viewModel.printerInfo else { return "battery.0" }
        
        if info.isCharging {
            return "bolt.fill"
        }
        
        switch info.batteryPercentage {
        case 0...20:
            return "battery.25"
        case 21...50:
            return "battery.50"
        case 51...75:
            return "battery.75"
        default:
            return "battery.100"
        }
    }
    
    private var imagePreviewSection: some View {
        VStack(spacing: 12) {
            if let previewImage = viewModel.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.separator, lineWidth: 1)
                    )
                    .onTapGesture {
                        showPreview = true
                    }
            } else {
                Button(action: { showImagePicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.accentColor)
                        
                        Text("Seleziona immagine")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        Text("Formato: \(viewModel.selectedModel.filmFormat)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            
            if viewModel.previewImage != nil {
                Button(action: { showImagePicker = true }) {
                    Label("Cambia immagine", systemImage: "photo")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var printerInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Stampante")
                    .font(.headline)
                
                Spacer()
                
                Picker("Modello", selection: $viewModel.selectedModel) {
                    ForEach(InstaxPrinterModel.allCases) { model in
                        Text(model.rawValue).tag(model)
                    }
                }
                .pickerStyle(.menu)
            }
            
            if let info = viewModel.printerInfo {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Nome", value: info.name)
                    InfoRow(label: "Modello", value: info.model?.rawValue ?? "Sconosciuto")
                    InfoRow(label: "Risoluzione", value: "\(Int(info.imageSize.width))×\(Int(info.imageSize.height))")
                    InfoRow(label: "Stato", value: info.isCharging ? "In carica" : "A batteria")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("Nessuna stampante connessa")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Toggle stampa abilitata
            Toggle(isOn: $viewModel.printEnabled) {
                HStack {
                    Image(systemName: viewModel.printEnabled ? "checkmark.shield.fill" : "shield.slash")
                        .foregroundColor(viewModel.printEnabled ? .green : .red)
                    
                    VStack(alignment: .leading) {
                        Text("Stampa abilitata")
                            .font(.subheadline)
                        Text(viewModel.printEnabled ? "La stampa è attiva" : "La stampa è disabilitata")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
            
            Divider()
            
            // Pulsanti azione
            HStack(spacing: 12) {
                if viewModel.connectionState == .connected {
                    Button(action: { viewModel.disconnect() }) {
                        Label("Disconnetti", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button(action: { showPrinterSelector = true }) {
                        Label("Connetti", systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(action: { viewModel.printImage() }) {
                    if viewModel.isPrinting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Stampa", systemImage: "printer.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canPrint)
            }
            
            // Progresso stampa
            if viewModel.isPrinting, let progress = viewModel.printProgress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(viewModel.printStatus)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                    }
                    
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var printQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Coda stampe")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.printQueue.count) job")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { viewModel.clearQueue() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            ForEach(viewModel.printQueue) { job in
                PrintJobRow(job: job)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gear")
        }
    }
    
    private var refreshButton: some View {
        Button(action: { viewModel.refreshPrinterInfo() }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.connectionState != .connected)
    }
    
    private var scanButton: some View {
        Button(action: { showPrinterSelector = true }) {
            Image(systemName: "dot.radiowaves.left.and.right")
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

struct PrintJobRow: View {
    let job: InstaxPrintJob
    
    var body: some View {
        HStack {
            Image(uiImage: job.image)
                .resizable()
                .scaledToFill
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(job.model.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(job.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(state: job.state)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let state: InstaxPrintState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(state.description)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch state {
        case .idle:
            return .gray
        case .preparing, .sending:
            return .orange
        case .printing:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .gray
        case .error:
            return .red
        }
    }
}

// MARK: - ImagePicker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - PrinterSelectorView

struct PrinterSelectorView: View {
    let printers: [DiscoveredPrinter]
    let onSelect: (DiscoveredPrinter) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(printers) { printer in
                Button(action: {
                    onSelect(printer)
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(printer.name)
                                .font(.headline)
                            Text(printer.address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Seleziona Stampante")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PrintSettingsView

struct PrintSettingsView: View {
    @ObservedObject var viewModel: InstaxPrintViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Immagine") {
                    Toggle("Converti in B/N", isOn: $viewModel.convertToBlackAndWhite)
                    
                    if viewModel.convertToBlackAndWhite {
                        VStack(alignment: .leading) {
                            Text("Contrasto")
                                .font(.caption)
                            Slider(value: $viewModel.blackAndWhiteContrast, in: 0.5...2.0, step: 0.1)
                            Text("\(viewModel.blackAndWhiteContrast, specifier: "%.1f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("Applica dithering", isOn: $viewModel.enableDithering)
                    
                    if viewModel.enableDithering {
                        Picker("Tipo dithering", selection: $viewModel.ditheringType) {
                            Text("Floyd-Steinberg").tag(DitheringType.floydSteinberg)
                            Text("Atkinson").tag(DitheringType.atkinson)
                            Text("Jarvis-Judice-Ninke").tag(DitheringType.jarvisJudiceNinke)
                            Text("Stucki").tag(DitheringType.stucki)
                            Text("Burkes").tag(DitheringType.burkes)
                            Text("Sierra").tag(DitheringType.sierra)
                        }
                    }
                }
                
                Section("Qualità") {
                    VStack(alignment: .leading) {
                        Text("Qualità JPEG")
                            .font(.caption)
                        Slider(value: $viewModel.jpegQuality, in: 0.5...1.0, step: 0.05)
                        Text("\(Int(viewModel.jpegQuality * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Avanzate") {
                    Stepper("Max retry: \(viewModel.maxRetries)", value: $viewModel.maxRetries, in: 0...5)
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fatto") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - DiscoveredPrinter

public struct DiscoveredPrinter: Identifiable {
    public let id = UUID()
    public let name: String
    public let address: String
    public let peripheral: Any?
}

// MARK: - DitheringType

public enum DitheringType {
    case floydSteinberg
    case atkinson
    case jarvisJudiceNinke
    case stucki
    case burkes
    case sierra
}
