import SwiftUI
import SwiftData

// MARK: - Roll List View
struct RollListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Roll.dateLoaded, order: .reverse) private var rolls: [Roll]
    
    @State private var showingAddRoll = false
    @State private var selectedRoll: Roll?
    @State private var searchText = ""
    @State private var filterStatus: RollStatus?
    @State private var showingExportSheet = false
    
    private var filteredRolls: [Roll] {
        rolls.filter { roll in
            let matchesSearch = searchText.isEmpty ||
                roll.displayName.localizedCaseInsensitiveContains(searchText) ||
                roll.filmName.localizedCaseInsensitiveContains(searchText) ||
                roll.developerName.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = filterStatus == nil || roll.status == filterStatus
            
            return matchesSearch && matchesStatus
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRolls) { roll in
                    NavigationLink(value: roll) {
                        RollRowView(roll: roll)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteRoll(roll)
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                        
                        Button {
                            selectedRoll = roll
                        } label: {
                            Label("Modifica", systemImage: "pencil")
                        }
                        .tint(.indigo)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            roll.isFavorite.toggle()
                            try? modelContext.save()
                        } label: {
                            Label("Preferito", systemImage: roll.isFavorite ? "star.slash" : "star.fill")
                        }
                        .tint(.yellow)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Rullini")
            .navigationDestination(for: Roll.self) { roll in
                RollDetailView(roll: roll)
            }
            .searchable(text: $searchText, prompt: "Cerca rullini...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Stato", selection: $filterStatus) {
                            Text("Tutti").tag(nil as RollStatus?)
                            ForEach(RollStatus.allCases, id: \.self) { status in
                                Label(status.rawValue, systemImage: status.icon)
                                    .tag(status as RollStatus?)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddRoll = true
                        } label: {
                            Label("Nuovo Rullino", systemImage: "plus")
                        }
                        
                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Esporta", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoll) {
                NavigationStack {
                    RollFormView()
                }
            }
            .sheet(item: $selectedRoll) { roll in
                NavigationStack {
                    RollFormView(roll: roll)
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportOptionsView(rolls: rolls)
            }
            .overlay {
                if rolls.isEmpty {
                    ContentUnavailableView {
                        Label("Nessun Rullino", systemImage: "film")
                    } description: {
                        Text("Aggiungi il tuo primo rullino per iniziare")
                    } actions: {
                        Button("Aggiungi Rullino") {
                            showingAddRoll = true
                        }
                    }
                }
            }
        }
    }
    
    private func deleteRoll(_ roll: Roll) {
        modelContext.delete(roll)
        try? modelContext.save()
    }
}

// MARK: - Roll Row View
struct RollRowView: View {
    let roll: Roll
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(roll.displayName)
                        .font(.headline)
                    
                    if roll.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 8) {
                    Label(roll.format.rawValue, systemImage: "film")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("ISO \(roll.effectiveISO)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if roll.isPushPull {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(roll.pushPullDescription)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                HStack(spacing: 8) {
                    Label("\(roll.exposureCount)/\(roll.expectedFrameCount)", systemImage: "camera")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(roll.dateLoaded, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Progress indicator
            CircularProgressView(
                progress: Double(roll.exposureCount) / Double(roll.expectedFrameCount),
                color: statusColor
            )
            .frame(width: 36, height: 36)
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch roll.status {
        case .loaded: return .blue
        case .inProgress: return .green
        case .exposed: return .orange
        case .developed: return .purple
        case .scanned: return .cyan
        case .archived: return .gray
        case .discarded: return .red
        }
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Roll Detail View
struct RollDetailView: View {
    let roll: Roll
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddExposure = false
    @State private var showingPDFPreview = false
    @State private var selectedExposure: Exposure?
    @State private var pdfData: Data?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header info
                RollHeaderCard(roll: roll)
                
                // Development info
                if roll.status == .developed || roll.status == .scanned || roll.status == .archived {
                    DevelopmentCard(roll: roll)
                }
                
                // Exposures
                ExposuresSection(roll: roll, onSelect: { exposure in
                    selectedExposure = exposure
                })
            }
            .padding()
        }
        .navigationTitle(roll.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAddExposure = true
                    } label: {
                        Label("Aggiungi Esposizione", systemImage: "camera.fill")
                    }
                    .disabled(!roll.status.canAddExposures)
                    
                    Button {
                        Task {
                            pdfData = try? await PDFExporter.shared.exportRoll(roll)
                            showingPDFPreview = pdfData != nil
                        }
                    } label: {
                        Label("Esporta PDF", systemImage: "doc.text")
                    }
                    
                    Divider()
                    
                    Button {
                        roll.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            roll.isFavorite ? "Rimuovi Preferito" : "Aggiungi a Preferiti",
                            systemImage: roll.isFavorite ? "star.slash" : "star"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddExposure) {
            NavigationStack {
                ExposureFormView(roll: roll)
            }
        }
        .sheet(item: $selectedExposure) { exposure in
            NavigationStack {
                ExposureDetailView(exposure: exposure)
            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let data = pdfData {
                PDFPreviewView(pdfData: data)
            }
        }
    }
}

// MARK: - Roll Header Card
struct RollHeaderCard: View {
    let roll: Roll
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(roll.fullFilmName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(roll.format.rawValue) • \(roll.filmType.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: roll.status)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                InfoItem(title: "ISO Nominale", value: "\(roll.nominalISO)")
                InfoItem(title: "ISO Effettiva", value: "\(roll.effectiveISO)")
                InfoItem(title: "Esposizioni", value: "\(roll.exposureCount)/\(roll.expectedFrameCount)")
            }
            
            if roll.isPushPull {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(roll.pushPullDescription)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
            
            HStack {
                Label(roll.dateLoaded, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let dateDeveloped = roll.dateDeveloped {
                    Label(dateDeveloped, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Development Card
struct DevelopmentCard: View {
    let roll: Roll
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.purple)
                Text("Sviluppo")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Sviluppatore", value: roll.developerName.isEmpty ? "Non specificato" : roll.developerName)
                DetailRow(label: "Diluizione", value: roll.dilution)
                DetailRow(label: "Tempo", value: roll.developmentTimeFormatted)
                DetailRow(label: "Temperatura", value: roll.temperatureFormatted)
                DetailRow(label: "Agitazione", value: roll.developmentAgitation.rawValue)
            }
            
            if !roll.developmentNotes.isEmpty {
                Divider()
                Text("Note sviluppo:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(roll.developmentNotes)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Exposures Section
struct ExposuresSection: View {
    let roll: Roll
    let onSelect: (Exposure) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.blue)
                Text("Esposizioni")
                    .font(.headline)
                
                Spacer()
                
                Text("\(roll.exposureCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if roll.exposures?.isEmpty ?? true {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Nessuna esposizione")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(roll.sortedExposures()) { exposure in
                        ExposureRow(exposure: exposure)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(exposure)
                            }
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

// MARK: - Exposure Row
struct ExposureRow: View {
    let exposure: Exposure
    
    var body: some View {
        HStack(spacing: 12) {
            // Frame number
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Text("\(exposure.frameNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exposure.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(exposure.exposureSettings)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !exposure.cameraModel.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(exposure.cameraModel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Rating
            if exposure.rating != .unrated {
                Text(exposure.rating.rawValue)
                    .font(.caption)
            }
            
            // Keeper indicator
            if exposure.keepers {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            // Print count
            if exposure.printCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "photo.stack")
                        .font(.caption)
                    Text("\(exposure.printCount)")
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Views
struct StatusBadge: View {
    let status: RollStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.rawValue)
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .loaded: return .blue
        case .inProgress: return .green
        case .exposed: return .orange
        case .developed: return .purple
        case .scanned: return .cyan
        case .archived: return .gray
        case .discarded: return .red
        }
    }
}

struct InfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
