import SwiftUI
import SwiftData

// MARK: - Analog Archive App
@main
struct AnalogArchiveApp: App {
    
    // MARK: - Model Container
    let container: ModelContainer
    
    init() {
        // Configura lo schema SwiftData
        let schema = Schema([
            Roll.self,
            Exposure.self,
            Print.self,
            DodgeBurnOperation.self
        ])
        
        // Configura il model configuration
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        // Crea il container
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Inizializza il manager
            AnalogArchiveManager.shared.initialize(with: container)
            
        } catch {
            fatalError("Impossibile creare ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

// MARK: - Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab = 0
    @State private var showingSettings = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Rullini Tab
            NavigationStack {
                RollListView()
            }
            .tabItem {
                Label("Rullini", systemImage: "film")
            }
            .tag(0)
            
            // Esposizioni Tab
            NavigationStack {
                AllExposuresView()
            }
            .tabItem {
                Label("Esposizioni", systemImage: "camera.fill")
            }
            .tag(1)
            
            // Statistiche Tab
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statistiche", systemImage: "chart.bar.fill")
            }
            .tag(2)
            
            // Keepers Tab
            NavigationStack {
                KeepersView()
            }
            .tabItem {
                Label("Keepers", systemImage: "star.fill")
            }
            .tag(3)
        }
        .sheet(isPresented: $showingSettings) {
            ArchiveSettingsView()
        }
    }
}

// MARK: - All Exposures View
struct AllExposuresView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exposure.dateTaken, order: .reverse) private var exposures: [Exposure]
    
    @State private var searchText = ""
    @State private var selectedExposure: Exposure?
    @State private var showingFilters = false
    
    private var filteredExposures: [Exposure] {
        if searchText.isEmpty {
            return exposures
        }
        return exposures.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.cameraModel.localizedCaseInsensitiveContains(searchText) ||
            $0.locationName?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredExposures) { exposure in
                Button {
                    selectedExposure = exposure
                } label: {
                    ExposureListRow(exposure: exposure)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Tutte le Esposizioni")
        .searchable(text: $searchText, prompt: "Cerca esposizioni...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(item: $selectedExposure) { exposure in
            NavigationStack {
                ExposureDetailView(exposure: exposure)
            }
        }
    }
}

// MARK: - Exposure List Row
struct ExposureListRow: View {
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
                    
                    if let roll = exposure.roll {
                        Text("•")
                            .font(.caption)
                        
                        Text(roll.filmName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(exposure.dateTaken, style: .date)
                        .font(.caption2)
                    
                    if let location = exposure.locationName {
                        Text("•")
                            .font(.caption2)
                        
                        Text(location)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Rating
            if exposure.rating != .unrated {
                Text(exposure.rating.rawValue)
                    .font(.caption)
            }
            
            if exposure.keepers {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Keepers View
struct KeepersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exposure.dateTaken, order: .reverse) private var allExposures: [Exposure]
    
    @State private var selectedExposure: Exposure?
    @State private var showingExportSheet = false
    
    private var keepers: [Exposure] {
        allExposures.filter { $0.keepers || $0.rating.stars >= 3 }
    }
    
    var body: some View {
        List {
            if keepers.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Nessun Keeper", systemImage: "star.slash")
                    } description: {
                        Text("Le foto valutate come keepers appariranno qui")
                    }
                }
            } else {
                Section("\(keepers.count) foto selezionate") {
                    ForEach(keepers) { exposure in
                        Button {
                            selectedExposure = exposure
                        } label: {
                            ExposureListRow(exposure: exposure)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Keepers")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(keepers.isEmpty)
            }
        }
        .sheet(item: $selectedExposure) { exposure in
            NavigationStack {
                ExposureDetailView(exposure: exposure)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            KeepersExportView(keepers: keepers)
        }
    }
}

// MARK: - Keepers Export View
struct KeepersExportView: View {
    let keepers: [Exposure]
    
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var pdfData: Data?
    @State private var showingPDFPreview = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Esporta Keepers") {
                    Text("\(keepers.count) foto selezionate")
                        .foregroundColor(.secondary)
                    
                    Button {
                        exportPDF()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Esporta PDF")
                        }
                    }
                    .disabled(isExporting)
                    
                    if isExporting {
                        ProgressView()
                    }
                }
                
                Section("Preview") {
                    ForEach(keepers.prefix(5)) { exposure in
                        HStack {
                            Text("#\(exposure.frameNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(exposure.displayTitle)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(exposure.rating.rawValue)
                                .font(.caption)
                        }
                    }
                    
                    if keepers.count > 5 {
                        Text("...e altre \(keepers.count - 5) foto")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Esporta Keepers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPDFPreview) {
                if let data = pdfData {
                    PDFPreviewView(pdfData: data)
                }
            }
        }
    }
    
    private func exportPDF() {
        isExporting = true
        Task {
            pdfData = try? await PDFExporter.shared.exportKeepers(exposures: keepers)
            isExporting = false
            showingPDFPreview = pdfData != nil
        }
    }
}
