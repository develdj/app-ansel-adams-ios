import SwiftUI
import SwiftData

// MARK: - Roll Form View
struct RollFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var roll: Roll?
    
    // MARK: - Form State
    @State private var name = ""
    @State private var selectedFilmStock: FilmStock?
    @State private var filmManufacturer: FilmManufacturer = .ilford
    @State private var filmName = ""
    @State private var nominalISO = 400
    @State private var effectiveISO = 400
    @State private var format: FilmFormat = .mm35
    @State private var filmType: FilmType = .blackWhite
    @State private var dateLoaded = Date()
    @State private var dateDeveloped: Date?
    @State private var status: RollStatus = .loaded
    
    // Development
    @State private var developerName = ""
    @State private var dilution = "1+1"
    @State private var developmentTime: TimeInterval?
    @State private var developmentTemperature: Double = 20.0
    @State private var developmentAgitation: AgitationType = .standard
    @State private var developmentNotes = ""
    
    // Push/Pull
    @State private var isPushPull = false
    @State private var pushPullStops = 0.0
    
    // Notes
    @State private var notes = ""
    @State private var isFavorite = false
    @State private var rating = 0
    
    // Storage
    @State private var storageLocation = ""
    @State private var negativePage: Int?
    @State private var negativeSleeveNumber = ""
    
    // UI State
    @State private var showingFilmPicker = false
    @State private var showingDeveloperPicker = false
    @State private var selectedSection = 0
    
    private var isEditing: Bool { roll != nil }
    
    init(roll: Roll? = nil) {
        self.roll = roll
        if let roll = roll {
            _name = State(initialValue: roll.name)
            _filmManufacturer = State(initialValue: roll.filmManufacturer)
            _filmName = State(initialValue: roll.filmName)
            _nominalISO = State(initialValue: roll.nominalISO)
            _effectiveISO = State(initialValue: roll.effectiveISO)
            _format = State(initialValue: roll.format)
            _filmType = State(initialValue: roll.filmType)
            _dateLoaded = State(initialValue: roll.dateLoaded)
            _dateDeveloped = State(initialValue: roll.dateDeveloped)
            _status = State(initialValue: roll.status)
            _developerName = State(initialValue: roll.developerName)
            _dilution = State(initialValue: roll.dilution)
            _developmentTime = State(initialValue: roll.developmentTime)
            _developmentTemperature = State(initialValue: roll.developmentTemperature ?? 20.0)
            _developmentAgitation = State(initialValue: roll.developmentAgitation)
            _developmentNotes = State(initialValue: roll.developmentNotes)
            _isPushPull = State(initialValue: roll.isPushPull)
            _pushPullStops = State(initialValue: roll.pushPullStops)
            _notes = State(initialValue: roll.notes)
            _isFavorite = State(initialValue: roll.isFavorite)
            _rating = State(initialValue: roll.rating)
            _storageLocation = State(initialValue: roll.storageLocation ?? "")
            _negativePage = State(initialValue: roll.negativePage)
            _negativeSleeveNumber = State(initialValue: roll.negativeSleeveNumber ?? "")
        }
    }
    
    var body: some View {
        Form {
            Section("Informazioni Base") {
                TextField("Nome (opzionale)", text: $name)
                    .autocorrectionDisabled()
                
                Button {
                    showingFilmPicker = true
                } label: {
                    HStack {
                        Text("Pellicola")
                        Spacer()
                        if let stock = selectedFilmStock {
                            Text(stock.displayName)
                                .foregroundColor(.primary)
                        } else {
                            Text("Seleziona...")
                                .foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Picker("Produttore", selection: $filmManufacturer) {
                    ForEach(FilmManufacturer.allCases, id: \.self) { manufacturer in
                        Text(manufacturer.rawValue).tag(manufacturer)
                    }
                }
                
                TextField("Nome pellicola", text: $filmName)
                
                Picker("Formato", selection: $format) {
                    ForEach(FilmFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                
                Picker("Tipo", selection: $filmType) {
                    ForEach(FilmType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }
            }
            
            Section("Sensibilità") {
                Stepper("ISO Nominale: \(nominalISO)", value: $nominalISO, in: 6...12800, step: 1)
                
                Toggle("Push/Pull processing", isOn: $isPushPull)
                
                if isPushPull {
                    VStack(alignment: .leading) {
                        Text("ISO Effettiva: \(effectiveISO)")
                            .font(.subheadline)
                        
                        Slider(
                            value: $pushPullStops,
                            in: -3...3,
                            step: 0.5
                        )
                        
                        HStack {
                            Text("Pull -3")
                            Spacer()
                            Text(pushPullDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Push +3")
                        }
                        .font(.caption)
                    }
                    
                    Stepper("ISO Effettiva: \(effectiveISO)", value: $effectiveISO, in: 6...25600, step: 1)
                }
            }
            
            Section("Date") {
                DatePicker("Data caricamento", selection: $dateLoaded, displayedComponents: [.date])
                
                Picker("Stato", selection: $status) {
                    ForEach(RollStatus.allCases, id: \.self) { status in
                        Label(status.rawValue, systemImage: status.icon).tag(status)
                    }
                }
                
                if status == .developed || status == .scanned || status == .archived {
                    DatePicker(
                        "Data sviluppo",
                        selection: Binding(
                            get: { dateDeveloped ?? Date() },
                            set: { dateDeveloped = $0 }
                        ),
                        displayedComponents: [.date]
                    )
                }
            }
            
            Section("Sviluppo") {
                Button {
                    showingDeveloperPicker = true
                } label: {
                    HStack {
                        Text("Sviluppatore")
                        Spacer()
                        if developerName.isEmpty {
                            Text("Seleziona...")
                                .foregroundColor(.secondary)
                        } else {
                            Text(developerName)
                                .foregroundColor(.primary)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                TextField("Diluizione", text: $dilution)
                
                HStack {
                    Text("Tempo")
                    Spacer()
                    if let time = developmentTime {
                        Text(formatTime(time))
                            .foregroundColor(.primary)
                    } else {
                        Text("Non impostato")
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Mostra time picker
                }
                
                HStack {
                    Stepper("Temperatura: \(String(format: "%.1f", developmentTemperature))°C", value: $developmentTemperature, in: 15...30, step: 0.5)
                }
                
                Picker("Agitazione", selection: $developmentAgitation) {
                    ForEach(AgitationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                TextField("Note sviluppo", text: $developmentNotes, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section("Archiviazione") {
                TextField("Posizione", text: $storageLocation)
                
                HStack {
                    Text("Pagina negativi")
                    Spacer()
                    TextField("#", value: $negativePage, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                
                TextField("Numero busta", text: $negativeSleeveNumber)
            }
            
            Section("Note e Valutazione") {
                TextField("Note generali", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                
                Toggle("Preferito", isOn: $isFavorite)
                
                HStack {
                    Text("Valutazione")
                    Spacer()
                    StarRatingView(rating: $rating)
                }
            }
        }
        .navigationTitle(isEditing ? "Modifica Rullino" : "Nuovo Rullino")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") {
                    saveRoll()
                }
                .disabled(filmName.isEmpty)
            }
        }
        .sheet(isPresented: $showingFilmPicker) {
            FilmStockPickerView(selectedStock: $selectedFilmStock) { stock in
                filmManufacturer = stock.manufacturer
                filmName = stock.name
                nominalISO = stock.iso
                effectiveISO = stock.iso
                format = stock.format
                filmType = stock.type
            }
        }
        .sheet(isPresented: $showingDeveloperPicker) {
            DeveloperPickerView(selectedDeveloper: $developerName, selectedDilution: $dilution)
        }
        .onChange(of: pushPullStops) { _, newValue in
            // Calcola ISO effettiva in base agli stop
            let factor = pow(2, newValue)
            effectiveISO = Int(Double(nominalISO) * factor)
        }
    }
    
    private var pushPullDescription: String {
        if pushPullStops == 0 {
            return "Box speed"
        } else if pushPullStops > 0 {
            return "Push +\(String(format: "%.1f", pushPullStops))"
        } else {
            return "Pull \(String(format: "%.1f", pushPullStops))"
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
    
    private func saveRoll() {
        if let existingRoll = roll {
            // Aggiorna rullino esistente
            existingRoll.name = name
            existingRoll.filmManufacturerRaw = filmManufacturer.rawValue
            existingRoll.filmName = filmName
            existingRoll.nominalISO = nominalISO
            existingRoll.effectiveISO = effectiveISO
            existingRoll.formatRaw = format.rawValue
            existingRoll.filmTypeRaw = filmType.rawValue
            existingRoll.dateLoaded = dateLoaded
            existingRoll.dateDeveloped = dateDeveloped
            existingRoll.status = status
            existingRoll.developerName = developerName
            existingRoll.dilution = dilution
            existingRoll.developmentTime = developmentTime
            existingRoll.developmentTemperature = developmentTemperature
            existingRoll.developmentAgitation = developmentAgitation
            existingRoll.developmentNotes = developmentNotes
            existingRoll.isPushPull = isPushPull
            existingRoll.pushPullStops = pushPullStops
            existingRoll.notes = notes
            existingRoll.isFavorite = isFavorite
            existingRoll.rating = rating
            existingRoll.storageLocation = storageLocation.isEmpty ? nil : storageLocation
            existingRoll.negativePage = negativePage
            existingRoll.negativeSleeveNumber = negativeSleeveNumber.isEmpty ? nil : negativeSleeveNumber
            existingRoll.updateTimestamp()
        } else {
            // Crea nuovo rullino
            let newRoll = Roll(
                name: name,
                filmManufacturer: filmManufacturer,
                filmName: filmName,
                nominalISO: nominalISO,
                effectiveISO: effectiveISO,
                format: format,
                filmType: filmType,
                dateLoaded: dateLoaded,
                dateDeveloped: dateDeveloped,
                developerName: developerName,
                dilution: dilution,
                developmentTime: developmentTime,
                developmentTemperature: developmentTemperature,
                developmentAgitation: developmentAgitation,
                developmentNotes: developmentNotes,
                status: status,
                isPushPull: isPushPull,
                pushPullStops: pushPullStops,
                notes: notes,
                isFavorite: isFavorite,
                rating: rating,
                storageLocation: storageLocation.isEmpty ? nil : storageLocation,
                negativePage: negativePage,
                negativeSleeveNumber: negativeSleeveNumber.isEmpty ? nil : negativeSleeveNumber
            )
            modelContext.insert(newRoll)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Film Stock Picker View
struct FilmStockPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStock: FilmStock?
    let onSelect: (FilmStock) -> Void
    
    @State private var searchText = ""
    @State private var selectedManufacturer: FilmManufacturer?
    
    private var filteredStocks: [FilmStock] {
        var stocks = FilmStock.predefinedStocks
        
        if let manufacturer = selectedManufacturer {
            stocks = stocks.filter { $0.manufacturer == manufacturer }
        }
        
        if !searchText.isEmpty {
            stocks = stocks.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return stocks
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "Tutti",
                                isSelected: selectedManufacturer == nil
                            ) {
                                selectedManufacturer = nil
                            }
                            
                            ForEach(FilmManufacturer.allCases, id: \.self) { manufacturer in
                                FilterChip(
                                    title: manufacturer.rawValue,
                                    isSelected: selectedManufacturer == manufacturer
                                ) {
                                    selectedManufacturer = manufacturer
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                ForEach(filteredStocks) { stock in
                    Button {
                        selectedStock = stock
                        onSelect(stock)
                        dismiss()
                    } label: {
                        FilmStockRow(stock: stock)
                    }
                }
            }
            .navigationTitle("Seleziona Pellicola")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Cerca pellicola...")
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

// MARK: - Film Stock Row
struct FilmStockRow: View {
    let stock: FilmStock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stock.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text("ISO \(stock.iso)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            Text(stock.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                Label(stock.format.rawValue, systemImage: "film")
                    .font(.caption2)
                
                Label(stock.type.displayName, systemImage: stock.type.icon)
                    .font(.caption2)
                
                Label(stock.characteristics.grain.rawValue, systemImage: "circle.grid.2x2")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Developer Picker View
struct DeveloperPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDeveloper: String
    @Binding var selectedDilution: String
    
    private let presets = DeveloperPreset.presets
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Sviluppatore personalizzato", text: $selectedDeveloper)
                    TextField("Diluizione", text: $selectedDilution)
                }
                
                Section("Preset") {
                    ForEach(presets, id: \.id) { preset in
                        Button {
                            selectedDeveloper = preset.name
                            selectedDilution = preset.dilution
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(preset.name) \(preset.dilution)")
                                    .font(.subheadline)
                                
                                if !preset.description.isEmpty {
                                    Text(preset.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Sviluppatore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Star Rating View
struct StarRatingView: View {
    @Binding var rating: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundColor(star <= rating ? .yellow : .gray)
                    .onTapGesture {
                        rating = star
                    }
            }
        }
    }
}
