import SwiftUI
import SwiftData
import Charts

// MARK: - Statistics View
struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = StatisticsEngine.shared
    
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showingExportSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if engine.isLoading {
                        ProgressView("Caricamento statistiche...")
                            .padding()
                    } else {
                        // Overview Cards
                        if let stats = engine.currentStats {
                            OverviewSection(stats: stats)
                        }
                        
                        // Monthly Chart
                        MonthlyChartSection(stats: engine.monthlyStats)
                        
                        // Film Usage
                        if !engine.filmUsageStats.isEmpty {
                            FilmUsageSection(stats: engine.filmUsageStats)
                        }
                        
                        // Camera Usage
                        if !engine.cameraUsageStats.isEmpty {
                            CameraUsageSection(stats: engine.cameraUsageStats)
                        }
                        
                        // Exposure Distribution
                        if let exposureDist = engine.exposureDistribution {
                            ExposureDistributionSection(stats: exposureDist)
                        }
                        
                        // Time Distribution
                        if let timeDist = engine.timeDistribution {
                            TimeDistributionSection(stats: timeDist)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistiche")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let stats = engine.currentStats {
                    StatisticsExportView(statistics: stats)
                }
            }
            .task {
                try? await engine.calculateAllStatistics(context: modelContext)
                engine.monthlyStats = try! await engine.calculateMonthlyStatistics(year: selectedYear, context: modelContext)
            }
        }
    }
}

// MARK: - Overview Section
struct OverviewSection: View {
    let stats: ArchiveStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Panoramica")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Rullini",
                    value: "\(stats.totalRolls)",
                    icon: "film.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Esposizioni",
                    value: "\(stats.totalExposures)",
                    icon: "camera.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Stampe",
                    value: "\(stats.totalPrints)",
                    icon: "photo.stack",
                    color: .purple
                )
                
                StatCard(
                    title: "Keepers",
                    value: "\(stats.keepersCount)",
                    subtitle: String(format: "%.1f%%", stats.keeperRate),
                    icon: "checkmark.seal.fill",
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Monthly Chart Section
struct MonthlyChartSection: View {
    let stats: [MonthlyStatistics]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Attività Mensile")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            if #available(iOS 17.0, *) {
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Mese", stat.monthName),
                        y: .value("Esposizioni", stat.exposureCount)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    
                    BarMark(
                        x: .value("Mese", stat.monthName),
                        y: .value("Keepers", stat.keeperCount)
                    )
                    .foregroundStyle(Color.green.gradient)
                }
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                // Fallback per iOS 16
                Text("Grafico richiede iOS 17+")
                    .foregroundColor(.secondary)
            }
            
            // Legend
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                    Text("Esposizioni")
                        .font(.caption)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("Keepers")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Film Usage Section
struct FilmUsageSection: View {
    let stats: [FilmUsageStat]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Pellicole Più Usate")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(stats.prefix(5)) { stat in
                    FilmUsageRow(stat: stat)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Film Usage Row
struct FilmUsageRow: View {
    let stat: FilmUsageStat
    
    var body: some View {
        HStack(spacing: 12) {
            // Film indicator
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(filmColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "film.fill")
                    .foregroundColor(filmColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.filmName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text("\(stat.rollCount) rullini")
                        .font(.caption)
                    
                    Text("•")
                        .font(.caption)
                    
                    Text("\(stat.exposureCount) foto")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Keeper rate
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f%%", stat.keeperRate))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(stat.keeperRate > 50 ? .green : .orange)
                
                Text("\(stat.keeperCount) keepers")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var filmColor: Color {
        switch stat.manufacturer {
        case .ilford: return .gray
        case .kodak: return .yellow
        case .fujifilm: return .green
        case .foma: return .blue
        case .adox: return .purple
        default: return .orange
        }
    }
}

// MARK: - Camera Usage Section
struct CameraUsageSection: View {
    let stats: [CameraUsageStat]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Camere Più Usate")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(stats.prefix(5)) { stat in
                    CameraUsageRow(stat: stat)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Camera Usage Row
struct CameraUsageRow: View {
    let stat: CameraUsageStat
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "camera.fill")
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.cameraName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text("\(stat.exposureCount) foto")
                        .font(.caption)
                    
                    Text("•")
                        .font(.caption)
                    
                    Text("\(stat.rollCount) rullini")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.0f%%", stat.keeperRate))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(stat.keeperRate > 50 ? .green : .orange)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Exposure Distribution Section
struct ExposureDistributionSection: View {
    let stats: ExposureDistributionStats
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Distribuzione Esposizioni")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // ISO Distribution
            VStack(alignment: .leading, spacing: 8) {
                Text("ISO")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if #available(iOS 17.0, *) {
                    Chart(stats.isoDistribution, id: \.key) { item in
                        BarMark(
                            x: .value("ISO", "\(item.key)"),
                            y: .value("Conteggio", item.value)
                        )
                        .foregroundStyle(Color.purple.gradient)
                    }
                    .frame(height: 120)
                }
            }
            .padding(.horizontal)
            
            // Aperture Distribution
            VStack(alignment: .leading, spacing: 8) {
                Text("Diaframma")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if #available(iOS 17.0, *) {
                    Chart(stats.apertureDistribution, id: \.0) { item in
                        BarMark(
                            x: .value("Range", item.0),
                            y: .value("Conteggio", item.1)
                        )
                        .foregroundStyle(Color.orange.gradient)
                    }
                    .frame(height: 120)
                }
            }
            .padding(.horizontal)
            
            // Focal Length Distribution
            VStack(alignment: .leading, spacing: 8) {
                Text("Lunghezza Focale")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if #available(iOS 17.0, *) {
                    Chart(stats.focalLengthDistribution, id: \.0) { item in
                        BarMark(
                            x: .value("Range", item.0),
                            y: .value("Conteggio", item.1)
                        )
                        .foregroundStyle(Color.cyan.gradient)
                    }
                    .frame(height: 120)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Time Distribution Section
struct TimeDistributionSection: View {
    let stats: TimeDistributionStats
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Distribuzione Temporale")
                .font(.title3)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Hourly Distribution
            VStack(alignment: .leading, spacing: 8) {
                Text("Per Ora del Giorno")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if #available(iOS 17.0, *) {
                    let hourlyData = stats.hourlyDistribution.enumerated().map { (index, count) in
                        (hour: index, count: count)
                    }
                    
                    Chart(hourlyData, id: \.hour) { item in
                        BarMark(
                            x: .value("Ora", "\(item.hour):00"),
                            y: .value("Foto", item.count)
                        )
                        .foregroundStyle(Color.indigo.gradient)
                    }
                    .frame(height: 120)
                }
            }
            .padding(.horizontal)
            
            // Weekday Distribution
            VStack(alignment: .leading, spacing: 8) {
                Text("Per Giorno della Settimana")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if #available(iOS 17.0, *) {
                    let weekdays = ["Dom", "Lun", "Mar", "Mer", "Gio", "Ven", "Sab"]
                    let weekdayData = stats.weekdayDistribution.enumerated().map { (index, count) in
                        (day: weekdays[index], count: count)
                    }
                    
                    Chart(weekdayData, id: \.day) { item in
                        BarMark(
                            x: .value("Giorno", item.day),
                            y: .value("Foto", item.count)
                        )
                        .foregroundStyle(Color.teal.gradient)
                    }
                    .frame(height: 120)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Statistics Export View
struct StatisticsExportView: View {
    let statistics: ArchiveStatistics
    
    @Environment(\.dismiss) private var dismiss
    @State private var pdfData: Data?
    @State private var showingPDFPreview = false
    @State private var isGenerating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Esporta Statistiche") {
                    Button {
                        generatePDF()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Genera PDF")
                        }
                    }
                    .disabled(isGenerating)
                    
                    if isGenerating {
                        ProgressView()
                    }
                }
                
                Section("Riepilogo") {
                    StatRow(label: "Rullini totali", value: "\(statistics.totalRolls)")
                    StatRow(label: "Esposizioni totali", value: "\(statistics.totalExposures)")
                    StatRow(label: "Stampe totali", value: "\(statistics.totalPrints)")
                    StatRow(label: "Keepers", value: "\(statistics.keepersCount)")
                    StatRow(label: "Keeper Rate", value: String(format: "%.1f%%", statistics.keeperRate))
                    StatRow(label: "Media foto/rullino", value: String(format: "%.1f", statistics.averageExposuresPerRoll))
                }
            }
            .navigationTitle("Esporta Statistiche")
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
    
    private func generatePDF() {
        isGenerating = true
        Task {
            pdfData = try? await PDFExporter.shared.exportStatistics(statistics)
            isGenerating = false
            showingPDFPreview = pdfData != nil
        }
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
