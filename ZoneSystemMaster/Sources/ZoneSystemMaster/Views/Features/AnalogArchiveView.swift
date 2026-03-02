import SwiftUI
import SwiftData
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Analog Archive View

@MainActor
struct AnalogArchiveView: View {
    
    @State private var viewModel = AnalogArchiveViewModel()
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.rolls.isEmpty {
                    EmptyArchiveView()
                } else {
                    ArchiveListView(viewModel: viewModel)
                }
            }
            .navigationTitle("Film Archive")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showNewRollSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort By", selection: $viewModel.sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        
                        Divider()
                        
                        Toggle("Show Developed Only", isOn: $viewModel.showDevelopedOnly)
                        Toggle("Show Active Only", isOn: $viewModel.showActiveOnly)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search rolls...")
            .sheet(isPresented: $viewModel.showNewRollSheet) {
                NewRollSheet(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedRoll) { roll in
                RollDetailSheet(roll: roll, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Empty Archive View

struct EmptyArchiveView: View {
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.xl) {
            Spacer()
            
            Image(systemName: "film.stack")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("No Film Rolls")
                .font(LiquidGlassTheme.Typography.title2)
            
            Text("Start tracking your film photography journey by adding your first roll.")
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Archive List View

struct ArchiveListView: View {
    @Bindable var viewModel: AnalogArchiveViewModel
    
    var body: some View {
        List {
            // Stats section
            ArchiveStatsView(viewModel: viewModel)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            
            // Rolls list
            Section {
                ForEach(viewModel.filteredRolls) { roll in
                    RollRow(roll: roll)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedRoll = roll
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteRoll(roll)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                viewModel.duplicateRoll(roll)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(.blue)
                        }
                }
            } header: {
                Text("\(viewModel.filteredRolls.count) Rolls")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Archive Stats View

struct ArchiveStatsView: View {
    @Bindable var viewModel: AnalogArchiveViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LiquidGlassTheme.Spacing.md) {
                StatCard(
                    title: "Total Rolls",
                    value: "\(viewModel.rolls.count)",
                    icon: "film.stack",
                    color: .blue
                )
                
                StatCard(
                    title: "Exposures",
                    value: "\(viewModel.totalExposures)",
                    icon: "camera",
                    color: .green
                )
                
                StatCard(
                    title: "Developed",
                    value: "\(viewModel.developedRolls)",
                    icon: "checkmark.circle",
                    color: .orange
                )
                
                StatCard(
                    title: "Active",
                    value: "\(viewModel.activeRolls)",
                    icon: "play.circle",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, LiquidGlassTheme.Spacing.sm)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(LiquidGlassTheme.Typography.title1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(LiquidGlassTheme.Typography.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(width: 120)
        .background(LiquidGlassTheme.Colors.glassThin)
        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md))
    }
}

// MARK: - Roll Row

struct RollRow: View {
    let roll: FilmRoll
    
    var body: some View {
        HStack(spacing: LiquidGlassTheme.Spacing.md) {
            // Format indicator
            VStack {
                Text(roll.format.rawValue)
                    .font(LiquidGlassTheme.Typography.caption2.weight(.bold))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary)
                    .frame(width: 24, height: 24 / CGFloat(roll.format.aspectRatio))
            }
            .frame(width: 44)
            
            // Roll info
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.xxs) {
                Text(roll.name)
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                HStack(spacing: LiquidGlassTheme.Spacing.xs) {
                    Text(roll.emulsion.rawValue)
                        .font(LiquidGlassTheme.Typography.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(LiquidGlassTheme.Typography.caption)
                        .foregroundColor(.secondary)
                    
                    Text("ISO \(roll.iso)")
                        .font(LiquidGlassTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: LiquidGlassTheme.Spacing.xs) {
                    Text(roll.dateLoaded, style: .date)
                        .font(LiquidGlassTheme.Typography.caption2)
                        .foregroundColor(.secondary)
                    
                    if roll.isDeveloped {
                        Label("Developed", systemImage: "checkmark.circle.fill")
                            .font(LiquidGlassTheme.Typography.caption2)
                            .foregroundColor(.green)
                    } else {
                        Label("Active", systemImage: "play.circle.fill")
                            .font(LiquidGlassTheme.Typography.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Frame count
            VStack(alignment: .trailing) {
                Text("\(roll.exposures.count)")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                Text("frames")
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, LiquidGlassTheme.Spacing.xs)
    }
}

// MARK: - New Roll Sheet

struct NewRollSheet: View {
    @Bindable var viewModel: AnalogArchiveViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedFormat: FilmFormat = .mm35
    @State private var selectedEmulsion: FilmEmulsion = .ilfordHP5
    @State private var iso: Int = 400
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Roll Details") {
                    TextField("Roll Name", text: $name)
                    
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(FilmFormat.allCases) { format in
                            Text(format.description).tag(format)
                        }
                    }
                }
                
                Section("Film") {
                    Picker("Emulsion", selection: $selectedEmulsion) {
                        ForEach(FilmEmulsion.allCases) { emulsion in
                            Text(emulsion.rawValue).tag(emulsion)
                        }
                    }
                    
                    HStack {
                        Text("ISO Rating")
                        Spacer()
                        TextField("ISO", value: $iso, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                
                Section("Preview") {
                    HStack {
                        Text("Format")
                        Spacer()
                        Text(selectedFormat.description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Aspect Ratio")
                        Spacer()
                        Text(String(format: "%.2f:1", selectedFormat.aspectRatio))
                            .font(LiquidGlassTheme.Typography.mono)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Film Roll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        viewModel.createRoll(
                            name: name.isEmpty ? "New Roll" : name,
                            format: selectedFormat,
                            emulsion: selectedEmulsion,
                            iso: iso
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Roll Detail Sheet

struct RollDetailSheet: View {
    let roll: FilmRoll
    @Bindable var viewModel: AnalogArchiveViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Roll info section
                Section("Roll Information") {
                    InfoRow(label: "Name", value: roll.name)
                    InfoRow(label: "Format", value: roll.format.description)
                    InfoRow(label: "Emulsion", value: roll.emulsion.rawValue)
                    InfoRow(label: "ISO", value: "\(roll.iso)")
                    InfoRow(label: "Date Loaded", value: roll.dateLoaded.formatted(date: .long, time: .omitted))
                }
                
                // Development section
                if let devInfo = roll.developmentInfo {
                    Section("Development") {
                        InfoRow(label: "Developer", value: devInfo.developer.rawValue)
                        InfoRow(label: "Dilution", value: devInfo.dilution)
                        InfoRow(label: "Temperature", value: "\(Int(devInfo.temperature))°C")
                        InfoRow(label: "Time", value: formatTime(devInfo.developmentTime))
                        InfoRow(label: "Agitation", value: devInfo.agitation.rawValue)
                    }
                } else if roll.isDeveloped {
                    Button("Add Development Info") {
                        // Show development info sheet
                    }
                }
                
                // Exposures section
                Section("Exposures (\(roll.exposures.count))") {
                    if roll.exposures.isEmpty {
                        Text("No exposures recorded")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(roll.exposures) { exposure in
                            ExposureRow(exposure: exposure)
                        }
                    }
                    
                    if !roll.isDeveloped {
                        Button {
                            // Add exposure
                        } label: {
                            Label("Add Exposure", systemImage: "plus")
                        }
                    }
                }
                
                // Actions section
                Section {
                    if !roll.isDeveloped {
                        Button {
                            viewModel.markAsDeveloped(roll)
                        } label: {
                            Label("Mark as Developed", systemImage: "checkmark.circle")
                        }
                        .foregroundColor(.green)
                    }
                    
                    Button {
                        viewModel.exportRoll(roll)
                    } label: {
                        Label("Export Roll Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive) {
                        viewModel.deleteRoll(roll)
                        dismiss()
                    } label: {
                        Label("Delete Roll", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(roll.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Info Row

struct InfoRow: View {
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

// MARK: - Exposure Row

struct ExposureRow: View {
    let exposure: ExposureRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.xxs) {
            HStack {
                Text("Frame \(exposure.frameNumber)")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                Spacer()
                
                ZoneBadge(zone: exposure.zonePlacement, size: .small)
            }
            
            HStack(spacing: LiquidGlassTheme.Spacing.xs) {
                Label("f/\(String(format: "%.1f", exposure.aperture))", systemImage: "camera.aperture")
                Label(formatShutterSpeed(exposure.shutterSpeed), systemImage: "camera.shutter")
                Label("EV \(exposure.ev)", systemImage: "sun.max")
            }
            .font(LiquidGlassTheme.Typography.caption)
            .foregroundColor(.secondary)
            
            if !exposure.subjectDescription.isEmpty {
                Text(exposure.subjectDescription)
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, LiquidGlassTheme.Spacing.xs)
    }
    
    private func formatShutterSpeed(_ speed: Double) -> String {
        if speed >= 1 {
            return String(format: "%.0f\"", speed)
        } else {
            let denominator = Int(1.0 / speed)
            return "1/\(denominator)"
        }
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable, Identifiable {
    case dateNewest = "Date (Newest)"
    case dateOldest = "Date (Oldest)"
    case name = "Name"
    case format = "Format"
    
    var id: String { rawValue }
}

// MARK: - View Model

@Observable
@MainActor
final class AnalogArchiveViewModel {
    
    var rolls: [FilmRoll] = []
    var searchText = ""
    var sortOption: SortOption = .dateNewest
    var showDevelopedOnly = false
    var showActiveOnly = false
    var showNewRollSheet = false
    var selectedRoll: FilmRoll?
    
    @ObservationIgnored
    @Inject(\.analogArchive) private var analogArchive
    
    var filteredRolls: [FilmRoll] {
        var result = rolls
        
        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { roll in
                roll.name.localizedCaseInsensitiveContains(searchText) ||
                roll.emulsion.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply status filter
        if showDevelopedOnly {
            result = result.filter { $0.isDeveloped }
        }
        if showActiveOnly {
            result = result.filter { !$0.isDeveloped }
        }
        
        // Apply sort
        switch sortOption {
        case .dateNewest:
            result.sort { $0.dateLoaded > $1.dateLoaded }
        case .dateOldest:
            result.sort { $0.dateLoaded < $1.dateLoaded }
        case .name:
            result.sort { $0.name < $1.name }
        case .format:
            result.sort { $0.format.rawValue < $1.format.rawValue }
        }
        
        return result
    }
    
    var totalExposures: Int {
        rolls.reduce(0) { $0 + $1.exposures.count }
    }
    
    var developedRolls: Int {
        rolls.filter { $0.isDeveloped }.count
    }
    
    var activeRolls: Int {
        rolls.filter { !$0.isDeveloped }.count
    }
    
    init() {
        loadRolls()
    }
    
    private func loadRolls() {
        Task {
            do {
                let loadedRolls = try await analogArchive.getAllRolls()
                await MainActor.run {
                    self.rolls = loadedRolls
                }
            } catch {
                print("Error loading rolls: \(error)")
            }
        }
    }
    
    func createRoll(name: String, format: FilmFormat, emulsion: FilmEmulsion, iso: Int) {
        Task {
            do {
                let roll = try await analogArchive.createFilmRoll(format: format, emulsion: emulsion, iso: iso)
                await MainActor.run {
                    self.rolls.append(roll)
                }
            } catch {
                print("Error creating roll: \(error)")
            }
        }
    }
    
    func deleteRoll(_ roll: FilmRoll) {
        rolls.removeAll { $0.id == roll.id }
    }
    
    func duplicateRoll(_ roll: FilmRoll) {
        let newRoll = FilmRoll(
            name: "\(roll.name) Copy",
            format: roll.format,
            emulsion: roll.emulsion,
            iso: roll.iso
        )
        rolls.append(newRoll)
    }
    
    func markAsDeveloped(_ roll: FilmRoll) {
        if let index = rolls.firstIndex(where: { $0.id == roll.id }) {
            rolls[index].isDeveloped = true
        }
    }
    
    func exportRoll(_ roll: FilmRoll) {
        Task {
            do {
                let data = try await analogArchive.exportRoll(id: roll.id, format: .json)
                // Share data
            } catch {
                print("Error exporting roll: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AnalogArchiveView()
        .environment(DependencyContainer.preview())
}
