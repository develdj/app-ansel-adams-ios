import SwiftUI
import StoreKit
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Settings View

@MainActor
struct SettingsView: View {
    
    @State private var viewModel = SettingsViewModel()
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        NavigationStack {
            List {
                // PRO Status Section
                if !viewModel.isProUnlocked {
                    ProUpgradeSection(viewModel: viewModel)
                } else {
                    ProStatusSection()
                }
                
                // Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $viewModel.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    
                    Picker("Experience Level", selection: $viewModel.experienceLevel) {
                        ForEach(UserExperienceLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }
                
                // Default Settings Section
                Section("Default Settings") {
                    Picker("Film Format", selection: $viewModel.defaultFormat) {
                        ForEach(FilmFormat.allCases) { format in
                            Text(format.description).tag(format)
                        }
                    }
                    
                    Picker("Film Emulsion", selection: $viewModel.defaultEmulsion) {
                        ForEach(FilmEmulsion.allCases) { emulsion in
                            Text(emulsion.rawValue).tag(emulsion)
                        }
                    }
                    
                    Picker("Temperature Unit", selection: $viewModel.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }
                
                // Feedback Section
                Section("Feedback") {
                    Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedbackEnabled)
                    Toggle("Sound Effects", isOn: $viewModel.soundEffectsEnabled)
                }
                
                // Darkroom Section
                Section("Darkroom") {
                    Picker("Safe Light Color", selection: $viewModel.darkroomSafeColor) {
                        ForEach(DarkroomSafeColor.allCases) { color in
                            HStack {
                                Circle()
                                    .fill(safeColor(for: color))
                                    .frame(width: 12, height: 12)
                                Text(color.rawValue)
                            }
                            .tag(color)
                        }
                    }
                }
                
                // Data Section
                Section("Data") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("Data Management", systemImage: "externaldrive")
                    }
                    
                    NavigationLink {
                        ExportImportView()
                    } label: {
                        Label("Export & Import", systemImage: "arrow.up.arrow.down")
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://zonesystemmaster.com/help")!) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    
                    Link(destination: URL(string: "https://zonesystemmaster.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://zonesystemmaster.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                // Reset Section
                Section {
                    Button(role: .destructive) {
                        viewModel.showResetConfirmation = true
                    } label: {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showProUpgrade) {
                ProUpgradeSheet(viewModel: viewModel)
            }
            .alert("Reset Settings?", isPresented: $viewModel.showResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    viewModel.resetSettings()
                }
            } message: {
                Text("This will reset all settings to their default values. Your film archive data will not be affected.")
            }
        }
    }
    
    private func safeColor(for color: DarkroomSafeColor) -> Color {
        switch color {
        case .red: return LiquidGlassTheme.Colors.darkroomRed
        case .amber: return LiquidGlassTheme.Colors.darkroomAmber
        case .green: return LiquidGlassTheme.Colors.darkroomGreen
        case .dim: return Color.white.opacity(0.3)
        }
    }
}

// MARK: - PRO Upgrade Section

struct ProUpgradeSection: View {
    @Bindable var viewModel: SettingsViewModel
    
    var body: some View {
        Section {
            VStack(spacing: LiquidGlassTheme.Spacing.md) {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading) {
                        Text("Zone System Master PRO")
                            .font(LiquidGlassTheme.Typography.body.weight(.semibold))
                        Text("Unlock all professional features")
                            .font(LiquidGlassTheme.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Feature list
                VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.xs) {
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Emulsion Physics & Curves")
                    FeatureRow(icon: "wand.and.stars", text: "Advanced AI Critique")
                    FeatureRow(icon: "printer.fill", text: "Instax BLE Printing")
                    FeatureRow(icon: "panorama.fill", text: "Panoramic Tools")
                    FeatureRow(icon: "icloud", text: "Cloud Sync")
                }
                
                // Upgrade button
                Button {
                    viewModel.showProUpgrade = true
                } label: {
                    HStack {
                        Image(systemName: "lock.open.fill")
                        Text("Upgrade to PRO")
                    }
                    .font(LiquidGlassTheme.Typography.bodyLarge.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .liquidGlassButton(style: .primary)
            }
            .padding(.vertical, LiquidGlassTheme.Spacing.sm)
        }
    }
}

// MARK: - PRO Status Section

struct ProStatusSection: View {
    var body: some View {
        Section {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading) {
                    Text("PRO Unlocked")
                        .font(LiquidGlassTheme.Typography.body.weight(.semibold))
                    Text("All features enabled")
                        .font(LiquidGlassTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, LiquidGlassTheme.Spacing.xs)
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: LiquidGlassTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(LiquidGlassTheme.Typography.caption)
        }
    }
}

// MARK: - PRO Upgrade Sheet

struct ProUpgradeSheet: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LiquidGlassTheme.Spacing.xl) {
                    // Header
                    VStack(spacing: LiquidGlassTheme.Spacing.md) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Zone System Master PRO")
                            .font(LiquidGlassTheme.Typography.title1)
                        
                        Text("Unlock the full potential of your black and white photography")
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.md) {
                        ProFeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Emulsion Physics",
                            description: "Real characteristic curves for 16+ film emulsions"
                        )
                        
                        ProFeatureRow(
                            icon: "wand.and.stars",
                            title: "Advanced AI Critique",
                            description: "Detailed zone-by-zone analysis with improvement suggestions"
                        )
                        
                        ProFeatureRow(
                            icon: "printer.fill",
                            title: "Instax BLE Printing",
                            description: "Print directly to Fujifilm Instax printers"
                        )
                        
                        ProFeatureRow(
                            icon: "panorama.fill",
                            title: "Panoramic Tools",
                            description: "Composition guides for X-Pan and panoramic formats"
                        )
                        
                        ProFeatureRow(
                            icon: "icloud",
                            title: "Cloud Sync",
                            description: "Backup and sync your archive across devices"
                        )
                        
                        ProFeatureRow(
                            icon: "slider.horizontal.3",
                            title: "Pro Editor",
                            description: "Full editing with dodge & burn, split-grade simulation"
                        )
                    }
                    
                    Spacer()
                    
                    // Purchase button
                    VStack(spacing: LiquidGlassTheme.Spacing.md) {
                        if let product = viewModel.proProduct {
                            VStack(spacing: LiquidGlassTheme.Spacing.xs) {
                                Text(product.title)
                                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                                
                                Text("\(product.price) \(product.currency)")
                                    .font(LiquidGlassTheme.Typography.title2.weight(.bold))
                                
                                Text("One-time purchase, lifetime access")
                                    .font(LiquidGlassTheme.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button {
                            viewModel.purchasePro()
                        } label: {
                            if viewModel.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Purchase PRO")
                                    .font(LiquidGlassTheme.Typography.bodyLarge.weight(.semibold))
                            }
                        }
                        .liquidGlassButton(style: .primary)
                        .disabled(viewModel.isPurchasing)
                        
                        Button {
                            viewModel.restorePurchases()
                        } label: {
                            Text("Restore Purchases")
                                .font(LiquidGlassTheme.Typography.body)
                        }
                        .disabled(viewModel.isPurchasing)
                    }
                }
                .padding()
            }
            .navigationTitle("")
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
}

// MARK: - PRO Feature Row

struct ProFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: LiquidGlassTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(LiquidGlassTheme.Colors.primary)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.xxs) {
                Text(title)
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                Text(description)
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    // Clear cache
                } label: {
                    Label("Clear Image Cache", systemImage: "photo.on.rectangle.angled")
                }
                
                Button(role: .destructive) {
                    // Delete all data
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
            } footer: {
                Text("Deleting all data will permanently remove your film archive. This action cannot be undone.")
            }
        }
        .navigationTitle("Data Management")
    }
}

// MARK: - Export Import View

struct ExportImportView: View {
    var body: some View {
        List {
            Section("Export") {
                Button {
                    // Export all data
                } label: {
                    Label("Export All Data", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    // Export archive only
                } label: {
                    Label("Export Film Archive Only", systemImage: "film.stack")
                }
            }
            
            Section("Import") {
                Button {
                    // Import data
                } label: {
                    Label("Import from File", systemImage: "square.and.arrow.down")
                }
            }
        }
        .navigationTitle("Export & Import")
    }
}

// MARK: - View Model

@Observable
@MainActor
final class SettingsViewModel {
    
    var theme: AppTheme = .system
    var experienceLevel: UserExperienceLevel = .beginner
    var defaultFormat: FilmFormat = .mm35
    var defaultEmulsion: FilmEmulsion = .ilfordHP5
    var temperatureUnit: TemperatureUnit = .celsius
    var hapticFeedbackEnabled = true
    var soundEffectsEnabled = true
    var darkroomSafeColor: DarkroomSafeColor = .red
    
    var showProUpgrade = false
    var showResetConfirmation = false
    var isPurchasing = false
    
    @ObservationIgnored
    @Inject(\.store) private var store
    
    @ObservationIgnored
    @Inject(\.settings) private var settings
    
    var isProUnlocked: Bool {
        store.isProUnlocked
    }
    
    var proProduct: Product? {
        store.proProduct
    }
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        theme = settings.theme
        experienceLevel = settings.experienceLevel
        defaultFormat = settings.defaultFormat
        defaultEmulsion = settings.defaultEmulsion
        temperatureUnit = settings.temperatureUnit
        hapticFeedbackEnabled = settings.hapticFeedbackEnabled
        soundEffectsEnabled = settings.soundEffectsEnabled
        darkroomSafeColor = settings.darkroomSafeColor
    }
    
    func purchasePro() {
        isPurchasing = true
        
        Task {
            do {
                let result = try await store.purchasePro()
                await MainActor.run {
                    isPurchasing = false
                    if result == .success {
                        showProUpgrade = false
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                }
            }
        }
    }
    
    func restorePurchases() {
        isPurchasing = true
        
        Task {
            do {
                let success = try await store.restorePurchases()
                await MainActor.run {
                    isPurchasing = false
                    if success {
                        showProUpgrade = false
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                }
            }
        }
    }
    
    func resetSettings() {
        Task {
            await settings.resetToDefaults()
            loadSettings()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(DependencyContainer.preview())
        .environment(AppState())
}
