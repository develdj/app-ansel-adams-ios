import SwiftUI
import SwiftData

// MARK: - Export Options View
struct ExportOptionsView: View {
    let rolls: [Roll]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedExportType: ExportType = .completeArchive
    @State private var selectedRolls: Set<UUID> = []
    @State private var includePrints = true
    @State private var includeExposures = true
    @State private var isExporting = false
    @State private var exportResult: ExportResult?
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    
    enum ExportType {
        case completeArchive
        case selectedRolls
        case keepersOnly
        case statistics
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo di Esportazione") {
                    Picker("Esporta", selection: $selectedExportType) {
                        Text("Archivio Completo").tag(ExportType.completeArchive)
                        Text("Rullini Selezionati").tag(ExportType.selectedRolls)
                        Text("Solo Keepers").tag(ExportType.keepersOnly)
                        Text("Statistiche").tag(ExportType.statistics)
                    }
                    .pickerStyle(.inline)
                }
                
                if selectedExportType == .selectedRolls {
                    Section("Seleziona Rullini") {
                        ForEach(rolls) { roll in
                            Button {
                                toggleRollSelection(roll)
                            } label: {
                                HStack {
                                    RollRowView(roll: roll)
                                    
                                    Spacer()
                                    
                                    if selectedRolls.contains(roll.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                
                if selectedExportType != .statistics {
                    Section("Opzioni") {
                        Toggle("Includi Stampe", isOn: $includePrints)
                        Toggle("Includi Esposizioni", isOn: $includeExposures)
                    }
                }
                
                Section {
                    Button {
                        performExport()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Esporta")
                        }
                    }
                    .disabled(!canExport)
                    
                    if isExporting {
                        ProgressView()
                    }
                }
                
                if let result = exportResult {
                    Section("Risultato") {
                        ExportResultView(result: result)
                    }
                }
            }
            .navigationTitle("Esporta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private var canExport: Bool {
        switch selectedExportType {
        case .completeArchive, .keepersOnly, .statistics:
            return true
        case .selectedRolls:
            return !selectedRolls.isEmpty
        }
    }
    
    private func toggleRollSelection(_ roll: Roll) {
        if selectedRolls.contains(roll.id) {
            selectedRolls.remove(roll.id)
        } else {
            selectedRolls.insert(roll.id)
        }
    }
    
    private func performExport() {
        isExporting = true
        
        Task {
            do {
                let fileManager = FileManager.default
                let tempDir = fileManager.temporaryDirectory
                
                switch selectedExportType {
                case .completeArchive:
                    let pdfData = try await PDFExporter.shared.exportCompleteArchive(rolls: rolls)
                    let fileName = "Archivio_Analogico_\(formatDate()).pdf"
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    try pdfData.write(to: fileURL)
                    exportedFileURL = fileURL
                    exportResult = ExportResult(
                        success: true,
                        fileName: fileName,
                        fileSize: formatFileSize(pdfData.count),
                        message: "PDF generato con successo"
                    )
                    
                case .selectedRolls:
                    let selectedRollObjects = rolls.filter { selectedRolls.contains($0.id) }
                    let pdfData = try await PDFExporter.shared.exportCompleteArchive(rolls: selectedRollObjects)
                    let fileName = "Rullini_Selezionati_\(formatDate()).pdf"
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    try pdfData.write(to: fileURL)
                    exportedFileURL = fileURL
                    exportResult = ExportResult(
                        success: true,
                        fileName: fileName,
                        fileSize: formatFileSize(pdfData.count),
                        message: "PDF generato con successo"
                    )
                    
                case .keepersOnly:
                    let allExposures = try modelContext.fetch(FetchDescriptor<Exposure>())
                    let keepers = allExposures.filter { $0.keepers || $0.rating.stars >= 3 }
                    let pdfData = try await PDFExporter.shared.exportKeepers(exposures: keepers)
                    let fileName = "Best_Of_\(formatDate()).pdf"
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    try pdfData.write(to: fileURL)
                    exportedFileURL = fileURL
                    exportResult = ExportResult(
                        success: true,
                        fileName: fileName,
                        fileSize: formatFileSize(pdfData.count),
                        message: "PDF generato con successo"
                    )
                    
                case .statistics:
                    let engine = StatisticsEngine.shared
                    try await engine.calculateAllStatistics(context: modelContext)
                    if let stats = engine.currentStats {
                        let pdfData = try await PDFExporter.shared.exportStatistics(stats)
                        let fileName = "Statistiche_\(formatDate()).pdf"
                        let fileURL = tempDir.appendingPathComponent(fileName)
                        try pdfData.write(to: fileURL)
                        exportedFileURL = fileURL
                        exportResult = ExportResult(
                            success: true,
                            fileName: fileName,
                            fileSize: formatFileSize(pdfData.count),
                            message: "PDF generato con successo"
                        )
                    }
                }
                
                showingShareSheet = true
            } catch {
                exportResult = ExportResult(
                    success: false,
                    fileName: "",
                    fileSize: "",
                    message: "Errore: \(error.localizedDescription)"
                )
            }
            
            isExporting = false
        }
    }
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Export Result
struct ExportResult {
    let success: Bool
    let fileName: String
    let fileSize: String
    let message: String
}

// MARK: - Export Result View
struct ExportResultView: View {
    let result: ExportResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                
                Text(result.success ? "Successo" : "Errore")
                    .font(.headline)
            }
            
            if result.success {
                DetailRow(label: "File", value: result.fileName)
                DetailRow(label: "Dimensione", value: result.fileSize)
            }
            
            Text(result.message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Import View
struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFile: URL?
    @State private var mergeStrategy: MergeStrategy = .skipExisting
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @State private var showingFilePicker = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("File da Importare") {
                    Button {
                        showingFilePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "doc")
                            if let file = selectedFile {
                                Text(file.lastPathComponent)
                                    .lineLimit(1)
                            } else {
                                Text("Seleziona file JSON...")
                            }
                        }
                    }
                }
                
                Section("Strategia di Importazione") {
                    Picker("Gestione duplicati", selection: $mergeStrategy) {
                        Text("Salta esistenti").tag(MergeStrategy.skipExisting)
                        Text("Sostituisci esistenti").tag(MergeStrategy.replaceExisting)
                        Text("Unisci dati").tag(MergeStrategy.merge)
                    }
                    .pickerStyle(.inline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Salta esistenti")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Elementi già presenti verranno ignorati")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Sostituisci esistenti")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Elementi già presenti verranno sovrascritti")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Unisci dati")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("I dati verranno uniti agli esistenti")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button {
                        performImport()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Importa")
                        }
                    }
                    .disabled(selectedFile == nil || isImporting)
                    
                    if isImporting {
                        ProgressView()
                    }
                }
                
                if let result = importResult {
                    Section("Risultato Importazione") {
                        ImportResultDetailView(result: result)
                    }
                }
                
                if let error = errorMessage {
                    Section("Errore") {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Importa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    selectedFile = urls.first
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func performImport() {
        guard let fileURL = selectedFile else { return }
        
        isImporting = true
        errorMessage = nil
        
        Task {
            do {
                let manager = JSONImportExportManager.shared
                let result = try await manager.importFromFile(fileURL, context: modelContext, mergeStrategy: mergeStrategy)
                importResult = result
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isImporting = false
        }
    }
}

// MARK: - Import Result Detail View
struct ImportResultDetailView: View {
    let result: ImportResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Importazione completata")
                    .font(.headline)
            }
            
            Divider()
            
            Group {
                ImportStatRow(label: "Rullini importati", value: result.importedRolls)
                ImportStatRow(label: "Esposizioni importate", value: result.importedExposures)
                ImportStatRow(label: "Stampe importate", value: result.importedPrints)
            }
            
            if result.skippedRolls > 0 || result.skippedExposures > 0 || result.skippedPrints > 0 {
                Divider()
                
                Group {
                    ImportStatRow(label: "Rullini saltati", value: result.skippedRolls, color: .orange)
                    ImportStatRow(label: "Esposizioni saltate", value: result.skippedExposures, color: .orange)
                    ImportStatRow(label: "Stampe saltate", value: result.skippedPrints, color: .orange)
                }
            }
            
            if result.replacedRolls > 0 || result.replacedExposures > 0 || result.replacedPrints > 0 {
                Divider()
                
                Group {
                    ImportStatRow(label: "Rullini sostituiti", value: result.replacedRolls, color: .blue)
                    ImportStatRow(label: "Esposizioni sostituite", value: result.replacedExposures, color: .blue)
                    ImportStatRow(label: "Stampe sostituite", value: result.replacedPrints, color: .blue)
                }
            }
            
            Divider()
            
            HStack {
                Text("Totale processati:")
                    .font(.subheadline)
                Spacer()
                Text("\(result.totalProcessed)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Import Stat Row
struct ImportStatRow: View {
    let label: String
    let value: Int
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Settings View
struct ArchiveSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingImportSheet = false
    @State private var showingExportSheet = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Dati") {
                    Button {
                        showingExportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Esporta Dati")
                        }
                    }
                    
                    Button {
                        showingImportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Importa Dati")
                        }
                    }
                }
                
                Section("Archivio") {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Cancella Tutti i Dati")
                        }
                    }
                }
                
                Section("Informazioni") {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Database")
                        Spacer()
                        Text("SwiftData")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportView()
            }
            .sheet(isPresented: $showingExportSheet) {
                JSONExportView()
            }
            .alert("Conferma Cancellazione", isPresented: $showingClearConfirmation) {
                Button("Annulla", role: .cancel) {}
                Button("Cancella", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("Questa azione cancellerà tutti i dati dell'archivio. Questa operazione non può essere annullata.")
            }
        }
    }
    
    private func clearAllData() {
        do {
            let rolls = try modelContext.fetch(FetchDescriptor<Roll>())
            let exposures = try modelContext.fetch(FetchDescriptor<Exposure>())
            let prints = try modelContext.fetch(FetchDescriptor<Print>())
            
            for print in prints {
                modelContext.delete(print)
            }
            
            for exposure in exposures {
                modelContext.delete(exposure)
            }
            
            for roll in rolls {
                modelContext.delete(roll)
            }
            
            try modelContext.save()
        } catch {
            print("Errore durante la cancellazione: \(error)")
        }
    }
}

// MARK: - JSON Export View
struct JSONExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportType: JSONExportType = .complete
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    
    enum JSONExportType {
        case complete
        case keepersOnly
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo di Esportazione") {
                    Picker("Esporta", selection: $exportType) {
                        Text("Archivio Completo").tag(JSONExportType.complete)
                        Text("Solo Keepers").tag(JSONExportType.keepersOnly)
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Button {
                        performExport()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Esporta JSON")
                        }
                    }
                    .disabled(isExporting)
                    
                    if isExporting {
                        ProgressView()
                    }
                }
                
                if let error = errorMessage {
                    Section("Errore") {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Esporta JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func performExport() {
        isExporting = true
        errorMessage = nil
        
        Task {
            do {
                let manager = JSONImportExportManager.shared
                let data: Data
                
                switch exportType {
                case .complete:
                    data = try await manager.exportCompleteArchive(context: modelContext)
                case .keepersOnly:
                    data = try await manager.exportKeepers(context: modelContext)
                }
                
                let fileManager = FileManager.default
                let tempDir = fileManager.temporaryDirectory
                let fileName = "AnalogArchive_\(formatDate()).json"
                let fileURL = tempDir.appendingPathComponent(fileName)
                
                try data.write(to: fileURL)
                
                exportedFileURL = fileURL
                showingShareSheet = true
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isExporting = false
        }
    }
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
    }
}
