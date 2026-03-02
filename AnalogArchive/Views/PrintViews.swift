import SwiftUI
import SwiftData

// MARK: - Print Form View
struct PrintFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let exposure: Exposure
    var print: Print?
    
    // MARK: - Form State
    @State private var printNumber = ""
    @State private var title = ""
    @State private var datePrinted = Date()
    
    // Enlarger
    @State private var enlargerBrand = ""
    @State private var enlargerModel = ""
    @State private var enlargerLens = ""
    @State private var magnification: Double = 2.0
    
    // Paper
    @State private var paperBrand = "Ilford"
    @State private var paperModel = "Multigrade IV"
    @State private var paperType: PaperType = .rc
    @State private var paperGrade: PaperGrade = .grade2
    @State private var paperSize: PaperSize = .a4
    
    // Filters
    @State private var filterValues = ""
    @State private var splitGrade = false
    @State private var splitGradeLow = ""
    @State private var splitGradeHigh = ""
    
    // Exposure
    @State private var baseExposureTime: TimeInterval = 10
    @State private var aperture: Double = 5.6
    
    // Development
    @State private var developerName = "Ilford Multigrade"
    @State private var developerDilution = "1+9"
    @State private var developmentTime: TimeInterval = 60
    @State private var developmentTemperature: Double = 20.0
    
    // Processing
    @State private var stopBathTime: TimeInterval = 10
    @State private var fixerName = "Ilford Rapid Fixer"
    @State private var fixerTime: TimeInterval = 60
    @State private var washTime: TimeInterval = 1800
    @State private var hypoClearTime: TimeInterval = 120
    @State private var wettingAgent = "Ilford Ilfotol"
    
    // Rating
    @State private var printRating: PrintRating = .workPrint
    @State private var isFinalPrint = false
    @State private var isToned = false
    @State private var tonerName = ""
    
    // Storage
    @State private var printLocation = ""
    @State private var isMounted = false
    @State private var mountSize = ""
    @State private var isSigned = false
    @State private var editionNumber = ""
    
    // Notes
    @State private var notes = ""
    
    // UI State
    @State private var showingPaperPicker = false
    @State private var showingDodgeBurnSheet = false
    
    private var isEditing: Bool { print != nil }
    
    init(exposure: Exposure, print: Print? = nil) {
        self.exposure = exposure
        self.print = print
        
        if let print = print {
            _printNumber = State(initialValue: print.printNumber)
            _title = State(initialValue: print.title)
            _datePrinted = State(initialValue: print.datePrinted)
            _enlargerBrand = State(initialValue: print.enlargerBrand)
            _enlargerModel = State(initialValue: print.enlargerModel)
            _enlargerLens = State(initialValue: print.enlargerLens)
            _magnification = State(initialValue: print.magnification)
            _paperBrand = State(initialValue: print.paperBrand)
            _paperModel = State(initialValue: print.paperModel)
            _paperType = State(initialValue: print.paperType)
            _paperGrade = State(initialValue: print.paperGrade)
            _paperSize = State(initialValue: print.paperSize)
            _filterValues = State(initialValue: print.filterValues ?? "")
            _splitGrade = State(initialValue: print.splitGrade)
            _splitGradeLow = State(initialValue: print.splitGradeLow ?? "")
            _splitGradeHigh = State(initialValue: print.splitGradeHigh ?? "")
            _baseExposureTime = State(initialValue: print.baseExposureTime)
            _aperture = State(initialValue: print.aperture)
            _developerName = State(initialValue: print.developerName)
            _developerDilution = State(initialValue: print.developerDilution)
            _developmentTime = State(initialValue: print.developmentTime)
            _developmentTemperature = State(initialValue: print.developmentTemperature ?? 20.0)
            _fixerName = State(initialValue: print.fixerName)
            _fixerTime = State(initialValue: print.fixerTime)
            _washTime = State(initialValue: print.washTime)
            _printRating = State(initialValue: print.printRating)
            _isFinalPrint = State(initialValue: print.isFinalPrint)
            _isToned = State(initialValue: print.isToned)
            _tonerName = State(initialValue: print.tonerName ?? "")
            _printLocation = State(initialValue: print.printLocation ?? "")
            _isMounted = State(initialValue: print.isMounted)
            _mountSize = State(initialValue: print.mountSize ?? "")
            _isSigned = State(initialValue: print.isSigned)
            _editionNumber = State(initialValue: print.editionNumber ?? "")
            _notes = State(initialValue: print.notes)
        }
    }
    
    var body: some View {
        Form {
            Section("Informazioni") {
                TextField("Numero stampa", text: $printNumber)
                    .autocorrectionDisabled()
                
                TextField("Titolo (opzionale)", text: $title)
                
                DatePicker("Data stampa", selection: $datePrinted, displayedComponents: [.date])
            }
            
            Section("Ingranditore") {
                TextField("Marca", text: $enlargerBrand)
                TextField("Modello", text: $enlargerModel)
                TextField("Obiettivo", text: $enlargerLens)
                
                HStack {
                    Text("Ingrandimento")
                    Spacer()
                    Text("\(String(format: "%.1f", magnification))x")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $magnification, in: 0.5...10, step: 0.1)
            }
            
            Section("Carta") {
                Button {
                    showingPaperPicker = true
                } label: {
                    HStack {
                        Text("Carta")
                        Spacer()
                        Text("\(paperBrand) \(paperModel)")
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Picker("Tipo", selection: $paperType) {
                    ForEach(PaperType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                Picker("Grado", selection: $paperGrade) {
                    ForEach(PaperGrade.allCases, id: \.self) { grade in
                        Text(grade.displayName).tag(grade)
                    }
                }
                
                Picker("Formato", selection: $paperSize) {
                    ForEach(PaperSize.allCases, id: \.self) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
            }
            
            Section("Filtri") {
                Toggle("Split Grade", isOn: $splitGrade)
                
                if splitGrade {
                    TextField("Grado basso", text: $splitGradeLow)
                    TextField("Grado alto", text: $splitGradeHigh)
                } else {
                    TextField("Valore filtri (es. M 35 Y 15)", text: $filterValues)
                }
            }
            
            Section("Esposizione") {
                HStack {
                    Text("Tempo base")
                    Spacer()
                    Text(formatTime(baseExposureTime))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $baseExposureTime, in: 1...120, step: 1)
                
                HStack {
                    Text("Diaframma ingranditore")
                    Spacer()
                    Text("f/\(String(format: "%.1f", aperture))")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $aperture, in: 2.8...16, step: 0.5)
            }
            
            Section("Sviluppo Carta") {
                TextField("Sviluppatore", text: $developerName)
                TextField("Diluizione", text: $developerDilution)
                
                HStack {
                    Text("Tempo sviluppo")
                    Spacer()
                    Text(formatTime(developmentTime))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $developmentTime, in: 30...300, step: 5)
                
                Stepper("Temperatura: \(String(format: "%.1f", developmentTemperature))°C", value: $developmentTemperature, in: 15...25, step: 0.5)
            }
            
            Section("Stop, Fissaggio, Lavaggio") {
                HStack {
                    Text("Tempo stop")
                    Spacer()
                    Text(formatTime(stopBathTime))
                        .foregroundColor(.secondary)
                }
                Slider(value: $stopBathTime, in: 5...30, step: 1)
                
                TextField("Fissativo", text: $fixerName)
                
                HStack {
                    Text("Tempo fissaggio")
                    Spacer()
                    Text(formatTime(fixerTime))
                        .foregroundColor(.secondary)
                }
                Slider(value: $fixerTime, in: 30...300, step: 5)
                
                HStack {
                    Text("Tempo lavaggio")
                    Spacer()
                    Text(formatTime(washTime))
                        .foregroundColor(.secondary)
                }
                Slider(value: $washTime, in: 300...3600, step: 60)
                
                HStack {
                    Text("Tempo hypo-clear")
                    Spacer()
                    Text(formatTime(hypoClearTime))
                        .foregroundColor(.secondary)
                }
                Slider(value: $hypoClearTime, in: 60...300, step: 10)
                
                TextField("Agente bagnante", text: $wettingAgent)
            }
            
            Section("Tonalizzazione") {
                Toggle("Tonalizzata", isOn: $isToned)
                
                if isToned {
                    TextField("Toner", text: $tonerName)
                }
            }
            
            Section("Valutazione") {
                Picker("Rating", selection: $printRating) {
                    ForEach(PrintRating.allCases, id: \.self) { rating in
                        Text(rating.rawValue).tag(rating)
                    }
                }
                
                Toggle("Stampa finale", isOn: $isFinalPrint)
            }
            
            Section("Archiviazione") {
                TextField("Posizione", text: $printLocation)
                
                Toggle("Montata", isOn: $isMounted)
                
                if isMounted {
                    TextField("Dimensione montaggio", text: $mountSize)
                }
                
                Toggle("Firmata", isOn: $isSigned)
                TextField("Numero edizione (es. 1/10)", text: $editionNumber)
            }
            
            Section("Note") {
                TextField("Note", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(isEditing ? "Modifica Stampa" : "Nuova Stampa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") {
                    savePrint()
                }
            }
        }
        .sheet(isPresented: $showingPaperPicker) {
            PaperPickerView(
                selectedBrand: $paperBrand,
                selectedModel: $paperModel,
                selectedType: $paperType
            )
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func savePrint() {
        let finalPrintNumber = printNumber.isEmpty ? generatePrintNumber() : printNumber
        
        if let existingPrint = print {
            // Aggiorna stampa esistente
            existingPrint.printNumber = finalPrintNumber
            existingPrint.title = title
            existingPrint.datePrinted = datePrinted
            existingPrint.enlargerBrand = enlargerBrand
            existingPrint.enlargerModel = enlargerModel
            existingPrint.enlargerLens = enlargerLens
            existingPrint.magnification = magnification
            existingPrint.paperBrand = paperBrand
            existingPrint.paperModel = paperModel
            existingPrint.paperType = paperType
            existingPrint.paperGrade = paperGrade
            existingPrint.paperSize = paperSize
            existingPrint.filterValues = filterValues.isEmpty ? nil : filterValues
            existingPrint.splitGrade = splitGrade
            existingPrint.splitGradeLow = splitGradeLow.isEmpty ? nil : splitGradeLow
            existingPrint.splitGradeHigh = splitGradeHigh.isEmpty ? nil : splitGradeHigh
            existingPrint.baseExposureTime = baseExposureTime
            existingPrint.aperture = aperture
            existingPrint.developerName = developerName
            existingPrint.developerDilution = developerDilution
            existingPrint.developmentTime = developmentTime
            existingPrint.developmentTemperature = developmentTemperature
            existingPrint.stopBathTime = stopBathTime
            existingPrint.fixerName = fixerName
            existingPrint.fixerTime = fixerTime
            existingPrint.washTime = washTime
            existingPrint.hypoClearTime = hypoClearTime
            existingPrint.wettingAgent = wettingAgent.isEmpty ? nil : wettingAgent
            existingPrint.printRating = printRating
            existingPrint.isFinalPrint = isFinalPrint
            existingPrint.isToned = isToned
            existingPrint.tonerName = tonerName.isEmpty ? nil : tonerName
            existingPrint.printLocation = printLocation.isEmpty ? nil : printLocation
            existingPrint.isMounted = isMounted
            existingPrint.mountSize = mountSize.isEmpty ? nil : mountSize
            existingPrint.isSigned = isSigned
            existingPrint.editionNumber = editionNumber.isEmpty ? nil : editionNumber
            existingPrint.notes = notes
            existingPrint.updateTimestamp()
        } else {
            // Crea nuova stampa
            let newPrint = Print(
                printNumber: finalPrintNumber,
                exposure: exposure,
                title: title,
                datePrinted: datePrinted,
                enlargerBrand: enlargerBrand,
                enlargerModel: enlargerModel,
                enlargerLens: enlargerLens,
                magnification: magnification,
                paperBrand: paperBrand,
                paperModel: paperModel,
                paperType: paperType,
                paperGrade: paperGrade,
                paperSize: paperSize,
                filterValues: filterValues.isEmpty ? nil : filterValues,
                splitGrade: splitGrade,
                splitGradeLow: splitGradeLow.isEmpty ? nil : splitGradeLow,
                splitGradeHigh: splitGradeHigh.isEmpty ? nil : splitGradeHigh,
                baseExposureTime: baseExposureTime,
                aperture: aperture,
                developerName: developerName,
                developerDilution: developerDilution,
                developmentTime: developmentTime,
                developmentTemperature: developmentTemperature,
                stopBathTime: stopBathTime,
                fixerName: fixerName,
                fixerTime: fixerTime,
                washTime: washTime,
                hypoClearTime: hypoClearTime,
                wettingAgent: wettingAgent.isEmpty ? nil : wettingAgent,
                printRating: printRating,
                isFinalPrint: isFinalPrint,
                isToned: isToned,
                tonerName: tonerName.isEmpty ? nil : tonerName,
                printLocation: printLocation.isEmpty ? nil : printLocation,
                isMounted: isMounted,
                mountSize: mountSize.isEmpty ? nil : mountSize,
                isSigned: isSigned,
                editionNumber: editionNumber.isEmpty ? nil : editionNumber,
                notes: notes
            )
            modelContext.insert(newPrint)
            exposure.addPrint(newPrint)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func generatePrintNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "P-\(formatter.string(from: Date()))"
    }
}

// MARK: - Paper Picker View
struct PaperPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedBrand: String
    @Binding var selectedModel: String
    @Binding var selectedType: PaperType
    
    let paperPresets = [
        ("Ilford", "Multigrade IV RC", PaperType.rc),
        ("Ilford", "Multigrade IV FB", PaperType.fiber),
        ("Ilford", "Multigrade V RC", PaperType.rc),
        ("Ilford", "MG Art 300", PaperType.fiberMatte),
        ("Ilford", "Warmtone FB", PaperType.warmTone),
        ("Ilford", "Cooltone FB", PaperType.coolTone),
        ("Kodak", "Polymax RC", PaperType.rc),
        ("Kodak", "Elite Fine Art", PaperType.fiber),
        ("Foma", "Fomaspeed RC", PaperType.rc),
        ("Foma", "Fomatone FB", PaperType.warmTone),
        ("Adox", "MCC RC", PaperType.rc),
        ("Adox", "Vario Classic FB", PaperType.fiber),
        ("Oriental", "Seagull RC", PaperType.rc),
        ("Oriental", "New Seagull FB", PaperType.fiber),
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(paperPresets, id: \.1) { brand, model, type in
                    Button {
                        selectedBrand = brand
                        selectedModel = model
                        selectedType = type
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(brand) \(model)")
                                    .font(.subheadline)
                                Text(type.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if brand == selectedBrand && model == selectedModel {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Seleziona Carta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Print Detail View
struct PrintDetailView: View {
    let print: Print
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditSheet = false
    @State private var showingDodgeBurnSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                PrintHeaderCard(print: print)
                
                // Paper Info
                PaperInfoCard(print: print)
                
                // Exposure
                PrintExposureCard(print: print)
                
                // Processing
                PrintProcessingCard(print: print)
                
                // Dodge/Burn
                if print.hasDodgeBurn {
                    DodgeBurnCard(print: print)
                }
                
                // Storage
                if print.printLocation != nil || print.isMounted {
                    PrintStorageCard(print: print)
                }
                
                // Notes
                if !print.notes.isEmpty {
                    NotesCard(notes: print.notes)
                }
            }
            .padding()
        }
        .navigationTitle(print.displayTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Modifica", systemImage: "pencil")
                    }
                    
                    Button {
                        showingDodgeBurnSheet = true
                    } label: {
                        Label("Dodge/Burn", systemImage: "circle.dashed")
                    }
                    
                    Button {
                        print.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            print.isFavorite ? "Rimuovi Preferito" : "Aggiungi a Preferiti",
                            systemImage: print.isFavorite ? "star.slash" : "star"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                PrintFormView(exposure: print.exposure!, print: print)
            }
        }
    }
}

// MARK: - Print Header Card
struct PrintHeaderCard: View {
    let print: Print
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "photo.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(print.printNumber)
                        .font(.headline)
                    
                    Text(print.datePrinted, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if print.isFinalPrint {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            
            HStack {
                StatusBadge(status: print.printRating)
                
                if print.isToned {
                    Text("Tonalizzata")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Paper Info Card
struct PaperInfoCard: View {
    let print: Print
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                Text("Carta")
                    .font(.headline)
            }
            
            Divider()
            
            DetailRow(label: "Marca/Modello", value: "\(print.paperBrand) \(print.paperModel)")
            DetailRow(label: "Tipo", value: print.paperType.rawValue)
            DetailRow(label: "Grado", value: print.paperGrade.displayName)
            DetailRow(label: "Formato", value: print.paperSize.rawValue)
            
            if let filterValues = print.filterValues {
                DetailRow(label: "Filtri", value: filterValues)
            }
            
            if print.splitGrade {
                DetailRow(label: "Split Grade", value: "\(print.splitGradeLow ?? "-") / \(print.splitGradeHigh ?? "-")")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Print Exposure Card
struct PrintExposureCard: View {
    let print: Print
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "camera.aperture")
                    .foregroundColor(.green)
                Text("Esposizione")
                    .font(.headline)
            }
            
            Divider()
            
            DetailRow(label: "Ingrandimento", value: print.magnificationDisplay)
            DetailRow(label: "Tempo base", value: print.baseExposureFormatted)
            DetailRow(label: "Diaframma", value: "f/\(String(format: "%.1f", print.aperture))")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Print Processing Card
struct PrintProcessingCard: View {
    let print: Print
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.cyan)
                Text("Sviluppo")
                    .font(.headline)
            }
            
            Divider()
            
            DetailRow(label: "Sviluppatore", value: "\(print.developerName) \(print.developerDilution)")
            DetailRow(label: "Tempo", value: formatTime(print.developmentTime))
            
            if let temp = print.developmentTemperature {
                DetailRow(label: "Temperatura", value: String(format: "%.1f°C", temp))
            }
            
            DetailRow(label: "Fissativo", value: print.fixerName)
            DetailRow(label: "Tempo fissaggio", value: formatTime(print.fixerTime))
            DetailRow(label: "Tempo lavaggio", value: formatTime(print.washTime))
            DetailRow(label: "Tempo totale", value: print.totalWetTimeFormatted)
            
            if print.isArchival {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Trattamento archivistico")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Dodge Burn Card
struct DodgeBurnCard: View {
    let print: Print
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "circle.dashed")
                    .foregroundColor(.orange)
                Text("Dodge & Burn")
                    .font(.headline)
                
                Spacer()
                
                Text("\(print.dodgeBurnCount) operazioni")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if let operations = print.dodgeBurnOperations {
                ForEach(operations.sorted(by: { $0.order < $1.order })) { operation in
                    HStack {
                        Image(systemName: operation.type == .dodge ? "sun.max" : "moon.fill")
                            .foregroundColor(operation.type == .dodge ? .yellow : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(operation.area)
                                .font(.subheadline)
                            Text("\(Int(operation.exposurePercentage))% - \(formatTime(operation.duration))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        "\(Int(time))s"
    }
}

// MARK: - Print Storage Card
struct PrintStorageCard: View {
    let print: Print
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .foregroundColor(.gray)
                Text("Archiviazione")
                    .font(.headline)
            }
            
            Divider()
            
            if let location = print.printLocation {
                DetailRow(label: "Posizione", value: location)
            }
            
            if print.isMounted {
                DetailRow(label: "Montaggio", value: print.mountSize ?? "Sì")
            }
            
            if print.isSigned {
                HStack {
                    Image(systemName: "signature")
                        .foregroundColor(.blue)
                    Text("Firmata")
                        .font(.caption)
                }
            }
            
            if let edition = print.editionNumber {
                DetailRow(label: "Edizione", value: edition)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
