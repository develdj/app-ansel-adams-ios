import SwiftUI
import SwiftData

// MARK: - Exposure Form View
struct ExposureFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let roll: Roll
    var exposure: Exposure?
    
    // MARK: - Form State
    @State private var frameNumber = 1
    @State private var title = ""
    @State private var dateTaken = Date()
    
    // Camera & Lens
    @State private var cameraBrand = ""
    @State private var cameraModel = ""
    @State private var lensBrand = ""
    @State private var lensModel = ""
    @State private var focalLength = 50
    
    // Exposure
    @State private var selectedShutterSpeed: ShutterSpeed = ShutterSpeed(fraction: 125)
    @State private var selectedAperture: Aperture = Aperture(fStop: 8)
    @State private var isoUsed = 400
    
    // Focus
    @State private var focusDistance: Double?
    @State private var isHyperfocal = false
    @State private var isInfinity = false
    
    // Filter
    @State private var filterName = ""
    @State private var filterStops = 0.0
    
    // Light & Metering
    @State private var lightCondition: LightCondition = .other
    @State private var meteringMode: MeteringMode = .matrix
    @State private var meteredEV: Double?
    
    // Location
    @State private var locationName = ""
    @State private var locationNotes = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    
    // Zone System
    @State private var zonePlacement: Int?
    @State private var subjectBrightnessRange = ""
    @State private var reciprocityCorrection = ""
    
    // Rating & Notes
    @State private var rating: ExposureRating = .unrated
    @State private var keepers = false
    @State private var notes = ""
    
    // UI State
    @State private var showingShutterPicker = false
    @State private var showingAperturePicker = false
    @State private var showingLocationPicker = false
    
    private var isEditing: Bool { exposure != nil }
    
    init(roll: Roll, exposure: Exposure? = nil) {
        self.roll = roll
        self.exposure = exposure
        
        if let exposure = exposure {
            _frameNumber = State(initialValue: exposure.frameNumber)
            _title = State(initialValue: exposure.title)
            _dateTaken = State(initialValue: exposure.dateTaken)
            _cameraBrand = State(initialValue: exposure.cameraBrand)
            _cameraModel = State(initialValue: exposure.cameraModel)
            _lensBrand = State(initialValue: exposure.lensBrand)
            _lensModel = State(initialValue: exposure.lensModel)
            _focalLength = State(initialValue: exposure.focalLength)
            _selectedShutterSpeed = State(initialValue: exposure.shutterSpeed)
            _selectedAperture = State(initialValue: exposure.aperture)
            _isoUsed = State(initialValue: exposure.isoUsed)
            _focusDistance = State(initialValue: exposure.focusDistance)
            _isHyperfocal = State(initialValue: exposure.isHyperfocal)
            _isInfinity = State(initialValue: exposure.isInfinity)
            _filterName = State(initialValue: exposure.filterName ?? "")
            _filterStops = State(initialValue: exposure.filterStops)
            _lightCondition = State(initialValue: exposure.lightCondition)
            _meteringMode = State(initialValue: exposure.meteringMode)
            _meteredEV = State(initialValue: exposure.meteredEV)
            _locationName = State(initialValue: exposure.locationName ?? "")
            _locationNotes = State(initialValue: exposure.locationNotes ?? "")
            _latitude = State(initialValue: exposure.latitude)
            _longitude = State(initialValue: exposure.longitude)
            _zonePlacement = State(initialValue: exposure.zonePlacement)
            _subjectBrightnessRange = State(initialValue: exposure.subjectBrightnessRange ?? "")
            _reciprocityCorrection = State(initialValue: exposure.reciprocityCorrection ?? "")
            _rating = State(initialValue: exposure.rating)
            _keepers = State(initialValue: exposure.keepers)
            _notes = State(initialValue: exposure.notes)
        } else {
            _frameNumber = State(initialValue: roll.nextFrameNumber())
            _isoUsed = State(initialValue: roll.effectiveISO)
        }
    }
    
    var body: some View {
        Form {
            Section("Informazioni Base") {
                Stepper("Fotogramma #\(frameNumber)", value: $frameNumber, in: 1...50)
                
                TextField("Titolo (opzionale)", text: $title)
                
                DatePicker("Data e ora", selection: $dateTaken)
            }
            
            Section("Camera e Obiettivo") {
                TextField("Marca camera", text: $cameraBrand)
                TextField("Modello camera", text: $cameraModel)
                
                TextField("Marca obiettivo", text: $lensBrand)
                TextField("Modello obiettivo", text: $lensModel)
                
                Stepper("Lunghezza focale: \(focalLength)mm", value: $focalLength, in: 10...1000, step: 1)
            }
            
            Section("Esposizione") {
                HStack {
                    Text("Tempo")
                    Spacer()
                    Button(selectedShutterSpeed.displayString) {
                        showingShutterPicker = true
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    Text("Diaframma")
                    Spacer()
                    Button("f/\(selectedAperture.displayString)") {
                        showingAperturePicker = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Stepper("ISO usata: \(isoUsed)", value: $isoUsed, in: 3...102400, step: 1)
                
                // EV calcolato
                if let ev = calculateEV() {
                    HStack {
                        Text("EV calcolato")
                        Spacer()
                        Text(String(format: "%.1f", ev))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Messa a Fuoco") {
                Toggle("Iperfocale", isOn: $isHyperfocal)
                Toggle("Infinito", isOn: $isInfinity)
                
                if !isHyperfocal && !isInfinity {
                    HStack {
                        Text("Distanza")
                        Spacer()
                        TextField("metri", value: $focusDistance, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                    }
                }
            }
            
            Section("Filtro") {
                TextField("Nome filtro", text: $filterName)
                
                if !filterName.isEmpty {
                    Stepper("Compensazione: \(String(format: "%.1f", filterStops)) stop", value: $filterStops, in: 0...5, step: 0.5)
                }
            }
            
            Section("Luce e Misurazione") {
                Picker("Condizioni luce", selection: $lightCondition) {
                    ForEach(LightCondition.allCases, id: \.self) { condition in
                        Label(condition.rawValue, systemImage: condition.icon).tag(condition)
                    }
                }
                
                Picker("Modalità misurazione", selection: $meteringMode) {
                    ForEach(MeteringMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                HStack {
                    Text("EV misurato")
                    Spacer()
                    TextField("EV", value: $meteredEV, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                }
            }
            
            Section("Sistema Zona") {
                Picker("Zona piazzata", selection: $zonePlacement) {
                    Text("Non specificata").tag(nil as Int?)
                    ForEach(0...10, id: \.self) { zone in
                        Text("Zona \(zone)").tag(zone as Int?)
                    }
                }
                
                TextField("Range luminosità soggetto", text: $subjectBrightnessRange)
                TextField("Correzione reciprocità", text: $reciprocityCorrection)
            }
            
            Section("Luogo") {
                TextField("Nome luogo", text: $locationName)
                TextField("Note luogo", text: $locationNotes, axis: .vertical)
                    .lineLimit(2...4)
                
                if let lat = latitude, let lon = longitude {
                    HStack {
                        Text("Coordinate GPS")
                        Spacer()
                        Text("\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Aggiungi posizione GPS") {
                    showingLocationPicker = true
                }
            }
            
            Section("Valutazione") {
                Picker("Rating", selection: $rating) {
                    ForEach(ExposureRating.allCases, id: \.self) { rating in
                        Text(rating.rawValue).tag(rating)
                    }
                }
                
                Toggle("Keeper", isOn: $keepers)
            }
            
            Section("Note") {
                TextField("Note", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(isEditing ? "Modifica Esposizione" : "Nuova Esposizione")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") {
                    saveExposure()
                }
            }
        }
        .sheet(isPresented: $showingShutterPicker) {
            ShutterSpeedPickerView(selectedSpeed: $selectedShutterSpeed)
        }
        .sheet(isPresented: $showingAperturePicker) {
            AperturePickerView(selectedAperture: $selectedAperture)
        }
    }
    
    private func calculateEV() -> Double? {
        guard selectedShutterSpeed.seconds > 0 else { return nil }
        return log2(selectedAperture.fStop * selectedAperture.fStop / selectedShutterSpeed.seconds)
    }
    
    private func saveExposure() {
        if let existingExposure = exposure {
            // Aggiorna esposizione esistente
            existingExposure.frameNumber = frameNumber
            existingExposure.title = title
            existingExposure.dateTaken = dateTaken
            existingExposure.cameraBrand = cameraBrand
            existingExposure.cameraModel = cameraModel
            existingExposure.lensBrand = lensBrand
            existingExposure.lensModel = lensModel
            existingExposure.focalLength = focalLength
            existingExposure.shutterSpeedRaw = selectedShutterSpeed.seconds
            existingExposure.apertureRaw = selectedAperture.fStop
            existingExposure.isoUsed = isoUsed
            existingExposure.focusDistance = focusDistance
            existingExposure.isHyperfocal = isHyperfocal
            existingExposure.isInfinity = isInfinity
            existingExposure.filterName = filterName.isEmpty ? nil : filterName
            existingExposure.filterStops = filterStops
            existingExposure.lightConditionRaw = lightCondition.rawValue
            existingExposure.meteringMode = meteringMode
            existingExposure.meteredEV = meteredEV
            existingExposure.locationName = locationName.isEmpty ? nil : locationName
            existingExposure.locationNotes = locationNotes.isEmpty ? nil : locationNotes
            existingExposure.latitude = latitude
            existingExposure.longitude = longitude
            existingExposure.zonePlacement = zonePlacement
            existingExposure.subjectBrightnessRange = subjectBrightnessRange.isEmpty ? nil : subjectBrightnessRange
            existingExposure.reciprocityCorrection = reciprocityCorrection.isEmpty ? nil : reciprocityCorrection
            existingExposure.rating = rating
            existingExposure.keepers = keepers
            existingExposure.notes = notes
            existingExposure.updateTimestamp()
        } else {
            // Crea nuova esposizione
            let newExposure = Exposure(
                frameNumber: frameNumber,
                roll: roll,
                title: title,
                dateTaken: dateTaken,
                cameraBrand: cameraBrand,
                cameraModel: cameraModel,
                lensBrand: lensBrand,
                lensModel: lensModel,
                focalLength: focalLength,
                shutterSpeed: selectedShutterSpeed,
                aperture: selectedAperture,
                isoUsed: isoUsed,
                focusDistance: focusDistance,
                isHyperfocal: isHyperfocal,
                isInfinity: isInfinity,
                filterName: filterName.isEmpty ? nil : filterName,
                filterStops: filterStops,
                lightCondition: lightCondition,
                meteringMode: meteringMode,
                meteredEV: meteredEV,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName.isEmpty ? nil : locationName,
                locationNotes: locationNotes.isEmpty ? nil : locationNotes,
                rating: rating,
                keepers: keepers,
                zonePlacement: zonePlacement,
                subjectBrightnessRange: subjectBrightnessRange.isEmpty ? nil : subjectBrightnessRange,
                reciprocityCorrection: reciprocityCorrection.isEmpty ? nil : reciprocityCorrection,
                notes: notes
            )
            modelContext.insert(newExposure)
            roll.addExposure(newExposure)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Exposure Detail View
struct ExposureDetailView: View {
    let exposure: Exposure
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEditSheet = false
    @State private var showingAddPrint = false
    @State private var showingPDFPreview = false
    @State private var pdfData: Data?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                ExposureHeaderCard(exposure: exposure)
                
                // Exposure Settings
                ExposureSettingsCard(exposure: exposure)
                
                // Focus & Filter
                FocusFilterCard(exposure: exposure)
                
                // Light & Metering
                LightMeteringCard(exposure: exposure)
                
                // Zone System
                if exposure.zonePlacement != nil {
                    ZoneSystemCard(exposure: exposure)
                }
                
                // Location
                if exposure.locationName != nil || exposure.hasGPS {
                    LocationCard(exposure: exposure)
                }
                
                // Prints
                PrintsSection(exposure: exposure)
                
                // Notes
                if !exposure.notes.isEmpty {
                    NotesCard(notes: exposure.notes)
                }
            }
            .padding()
        }
        .navigationTitle(exposure.displayTitle)
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
                        showingAddPrint = true
                    } label: {
                        Label("Aggiungi Stampa", systemImage: "photo.stack")
                    }
                    
                    Button {
                        Task {
                            if let roll = exposure.roll {
                                pdfData = try? await PDFExporter.shared.exportRoll(roll)
                                showingPDFPreview = pdfData != nil
                            }
                        }
                    } label: {
                        Label("Esporta PDF", systemImage: "doc.text")
                    }
                    
                    Divider()
                    
                    Button {
                        exposure.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            exposure.isFavorite ? "Rimuovi Preferito" : "Aggiungi a Preferiti",
                            systemImage: exposure.isFavorite ? "star.slash" : "star"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                ExposureFormView(roll: exposure.roll!, exposure: exposure)
            }
        }
        .sheet(isPresented: $showingAddPrint) {
            NavigationStack {
                PrintFormView(exposure: exposure)
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let data = pdfData {
                PDFPreviewView(pdfData: data)
            }
        }
    }
}

// MARK: - Exposure Header Card
struct ExposureHeaderCard: View {
    let exposure: Exposure
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Text("\(exposure.frameNumber)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if !exposure.title.isEmpty {
                        Text(exposure.title)
                            .font(.headline)
                    }
                    
                    Text(exposure.dateTaken, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if exposure.keepers {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            
            if exposure.rating != .unrated {
                HStack {
                    Text(exposure.rating.rawValue)
                        .font(.title3)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Exposure Settings Card
struct ExposureSettingsCard: View {
    let exposure: Exposure
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "camera.aperture")
                    .foregroundColor(.blue)
                Text("Impostazioni Esposizione")
                    .font(.headline)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                ExposureValueItem(
                    icon: "timer",
                    label: "Tempo",
                    value: exposure.shutterSpeed.displayString
                )
                
                ExposureValueItem(
                    icon: "camera.aperture",
                    label: "Diaframma",
                    value: "f/\(exposure.aperture.displayString)"
                )
                
                ExposureValueItem(
                    icon: "number",
                    label: "ISO",
                    value: "\(exposure.isoUsed)"
                )
            }
            
            if let ev = exposure.exposureValue {
                Divider()
                HStack {
                    Text("EV calcolato:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", ev))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ExposureValueItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Focus & Filter Card
struct FocusFilterCard: View {
    let exposure: Exposure
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Messa a Fuoco e Filtri")
                .font(.headline)
            
            Divider()
            
            DetailRow(label: "Messa a fuoco", value: exposure.focusDistanceDisplay)
            
            if let filterName = exposure.filterName {
                DetailRow(label: "Filtro", value: filterName)
                if exposure.filterStops > 0 {
                    DetailRow(label: "Compensazione", value: "+\(String(format: "%.1f", exposure.filterStops)) stop")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Light & Metering Card
struct LightMeteringCard: View {
    let exposure: Exposure
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Luce e Misurazione")
                .font(.headline)
            
            Divider()
            
            DetailRow(label: "Condizioni", value: exposure.lightCondition.rawValue)
            DetailRow(label: "Modalità", value: exposure.meteringMode.rawValue)
            
            if let ev = exposure.meteredEV {
                DetailRow(label: "EV misurato", value: String(format: "%.1f", ev))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Zone System Card
struct ZoneSystemCard: View {
    let exposure: Exposure
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "circle.righthalf.filled")
                    .foregroundColor(.gray)
                Text("Sistema Zona")
                    .font(.headline)
            }
            
            Divider()
            
            DetailRow(label: "Zona piazzata", value: exposure.zoneSystemDisplay)
            
            if let sbr = exposure.subjectBrightnessRange, !sbr.isEmpty {
                DetailRow(label: "Range luminosità", value: sbr)
            }
            
            if let rec = exposure.reciprocityCorrection, !rec.isEmpty {
                DetailRow(label: "Correzione reciprocità", value: rec)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Location Card
struct LocationCard: View {
    let exposure: Exposure
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.red)
                Text("Luogo")
                    .font(.headline)
            }
            
            Divider()
            
            if let locationName = exposure.locationName {
                DetailRow(label: "Nome", value: locationName)
            }
            
            if let locationNotes = exposure.locationNotes, !locationNotes.isEmpty {
                DetailRow(label: "Note", value: locationNotes)
            }
            
            if exposure.hasGPS {
                HStack {
                    Text("Coordinate GPS")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let lat = exposure.latitude, let lon = exposure.longitude {
                        Text("\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Prints Section
struct PrintsSection: View {
    let exposure: Exposure
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundColor(.purple)
                Text("Stampe")
                    .font(.headline)
                
                Spacer()
                
                Text("\(exposure.printCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if exposure.printCount == 0 {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Nessuna stampa")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(exposure.sortedPrints) { print in
                        PrintRow(print: print)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Print Row
struct PrintRow: View {
    let print: Print
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "photo")
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(print.printNumber)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(print.paperBrand) \(print.paperModel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text("Gr.\(print.paperGrade.displayName)")
                        .font(.caption2)
                    
                    Text("•")
                        .font(.caption2)
                    
                    Text(print.baseExposureFormatted)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if print.isFinalPrint {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Notes Card
struct NotesCard: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.secondary)
                Text("Note")
                    .font(.headline)
            }
            
            Divider()
            
            Text(notes)
                .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Shutter Speed Picker
struct ShutterSpeedPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSpeed: ShutterSpeed
    
    let speeds = ShutterSpeed.standardSpeeds
    
    var body: some View {
        NavigationStack {
            List {
                Section("Tempi Standard") {
                    ForEach(speeds, id: \.seconds) { speed in
                        Button {
                            selectedSpeed = speed
                            dismiss()
                        } label: {
                            HStack {
                                Text(speed.displayString)
                                if speed.seconds == selectedSpeed.seconds {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("Tempi Lunghi") {
                    ForEach([1, 2, 4, 8, 15, 30, 60], id: \.self) { seconds in
                        Button {
                            selectedSpeed = ShutterSpeed(seconds: Double(seconds))
                            dismiss()
                        } label: {
                            HStack {
                                Text("\(seconds)\"")
                                if selectedSpeed.seconds == Double(seconds) {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section {
                    Button {
                        selectedSpeed = ShutterSpeed.bulb
                        dismiss()
                    } label: {
                        HStack {
                            Text("Bulb")
                            if selectedSpeed.seconds == 0 {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Tempo di Esposizione")
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

// MARK: - Aperture Picker
struct AperturePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAperture: Aperture
    
    var body: some View {
        NavigationStack {
            List {
                Section("Diaframmi Interi") {
                    ForEach(Aperture.fullStops, id: \.fStop) { aperture in
                        Button {
                            selectedAperture = aperture
                            dismiss()
                        } label: {
                            HStack {
                                Text("f/\(aperture.displayString)")
                                if aperture.fStop == selectedAperture.fStop {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("Diaframmi a 1/3") {
                    ForEach(Aperture.thirdStops, id: \.fStop) { aperture in
                        Button {
                            selectedAperture = aperture
                            dismiss()
                        } label: {
                            HStack {
                                Text("f/\(aperture.displayString)")
                                if aperture.fStop == selectedAperture.fStop {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Diaframma")
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
