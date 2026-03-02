import SwiftUI
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Exposure Meter View

@MainActor
struct ExposureMeterView: View {
    
    @State private var viewModel = ExposureMeterViewModel()
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LiquidGlassTheme.Spacing.xl) {
                    // Zone Scale
                    ZoneScaleView(
                        selectedZone: viewModel.selectedZone,
                        measuredZone: viewModel.measuredZone,
                        onZoneSelected: { zone in
                            viewModel.selectedZone = zone
                        }
                    )
                    
                    // EV Display
                    EVDisplayCard(ev: viewModel.currentEV)
                    
                    // Settings Panel
                    SettingsPanel(viewModel: viewModel)
                    
                    // Recommended Settings
                    if let settings = viewModel.recommendedSettings {
                        RecommendedSettingsCard(settings: settings)
                    }
                    
                    // Measure Button
                    Button {
                        viewModel.measure()
                    } label: {
                        HStack {
                            Image(systemName: "camera.metering.center.weighted")
                            Text("Measure")
                        }
                        .font(LiquidGlassTheme.Typography.bodyLarge.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .liquidGlassButton(style: .primary)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Zone Meter")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Metering Mode", selection: $viewModel.meteringMode) {
                            ForEach(MeteringMode.allCases) { mode in
                                Label(mode.rawValue, systemImage: modeIcon(for: mode))
                                    .tag(mode)
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            viewModel.calibrate()
                        } label: {
                            Label("Calibrate", systemImage: "wrench.adjust")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func modeIcon(for mode: MeteringMode) -> String {
        switch mode {
        case .spot: return "camera.metering.spot"
        case .centerWeighted: return "camera.metering.center.weighted"
        case .matrix: return "camera.metering.matrix"
        case .incident: return "sun.max"
        }
    }
}

// MARK: - Zone Scale View

struct ZoneScaleView: View {
    let selectedZone: Zone
    let measuredZone: Zone?
    let onZoneSelected: (Zone) -> Void
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.sm) {
            Text("Zone Scale")
                .font(LiquidGlassTheme.Typography.title3)
            
            HStack(spacing: 2) {
                ForEach(Zone.allCases) { zone in
                    ZoneButton(
                        zone: zone,
                        isSelected: selectedZone == zone,
                        isMeasured: measuredZone == zone
                    ) {
                        onZoneSelected(zone)
                    }
                }
            }
            .frame(height: 60)
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md))
            .padding(.horizontal)
            
            // Zone labels
            HStack {
                Text("Black")
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Middle Gray")
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("White")
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Zone Button

struct ZoneButton: View {
    let zone: Zone
    let isSelected: Bool
    let isMeasured: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                LiquidGlassTheme.Colors.zoneColor(zone)
                
                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 3)
                }
                
                // Measurement indicator
                if isMeasured {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(y: -12)
                }
                
                // Zone number
                Text("\(zone.rawValue)")
                    .font(LiquidGlassTheme.Typography.caption.weight(isSelected ? .bold : .regular))
                    .foregroundColor(zone.rawValue < 5 ? .white : .black)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EV Display Card

struct EVDisplayCard: View {
    let ev: ExposureValue
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.md) {
            HStack {
                Text("Exposure Value")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                Spacer()
                
                Text("ISO 100 @ f/8")
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("EV")
                    .font(LiquidGlassTheme.Typography.title2)
                    .foregroundColor(.secondary)
                
                Text("\(ev.rawValue)")
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }
            
            // Shutter speed display
            HStack {
                Image(systemName: "camera.shutter")
                Text(shutterSpeedForEV(ev.rawValue))
                    .font(LiquidGlassTheme.Typography.mono)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .liquidGlassCard()
        .padding(.horizontal)
    }
    
    private func shutterSpeedForEV(_ ev: Int) -> String {
        let speed = 1.0 / pow(2.0, Double(ev))
        if speed >= 1 {
            return String(format: "%.0f\"", speed)
        } else {
            let denominator = Int(1.0 / speed)
            return "1/\(denominator)"
        }
    }
}

// MARK: - Settings Panel

struct SettingsPanel: View {
    @Bindable var viewModel: ExposureMeterViewModel
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.md) {
            // ISO Setting
            HStack {
                Text("ISO")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                Spacer()
                
                Picker("ISO", selection: $viewModel.iso) {
                    ForEach([50, 100, 125, 200, 400, 800, 1600, 3200], id: \.self) { iso in
                        Text("\(iso)").tag(iso)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // Aperture Setting
            HStack {
                Text("Aperture")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                Spacer()
                
                Picker("Aperture", selection: $viewModel.aperture) {
                    ForEach([1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0], id: \.self) { f in
                        Text("f/\(String(format: "%.1f", f))").tag(f)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // Film Format
            HStack {
                Text("Format")
                    .font(LiquidGlassTheme.Typography.body.weight(.medium))
                
                Spacer()
                
                Picker("Format", selection: $viewModel.filmFormat) {
                    ForEach(FilmFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
        .liquidGlassCard()
        .padding(.horizontal)
    }
}

// MARK: - Recommended Settings Card

struct RecommendedSettingsCard: View {
    let settings: ExposureSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.md) {
            Text("Recommended Settings")
                .font(LiquidGlassTheme.Typography.body.weight(.medium))
            
            HStack(spacing: LiquidGlassTheme.Spacing.xl) {
                SettingItem(icon: "camera.aperture", value: "f/\(String(format: "%.1f", settings.aperture))")
                SettingItem(icon: "camera.shutter", value: formatShutterSpeed(settings.shutterSpeed))
                SettingItem(icon: "number", value: "Zone \(settings.zonePlacement.rawValue)")
            }
        }
        .padding()
        .liquidGlassCard(background: .thickMaterial)
        .padding(.horizontal)
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

// MARK: - Setting Item

struct SettingItem: View {
    let icon: String
    let value: String
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(LiquidGlassTheme.Typography.monoSmall)
        }
    }
}

// MARK: - View Model

@Observable
@MainActor
final class ExposureMeterViewModel {
    
    var selectedZone: Zone = .zone5
    var measuredZone: Zone?
    var currentEV: ExposureValue = .ev12
    var meteringMode: MeteringMode = .spot
    var iso: Int = 400
    var aperture: Double = 8.0
    var filmFormat: FilmFormat = .mm35
    var recommendedSettings: ExposureSettings?
    
    @ObservationIgnored
    @Inject(\.exposureMetering) private var exposureMetering
    
    func measure() {
        // Simulate measurement
        measuredZone = selectedZone
        
        // Calculate recommended settings
        recommendedSettings = ExposureSettings(
            aperture: aperture,
            shutterSpeed: 1.0 / 125.0,
            iso: iso,
            ev: currentEV,
            zonePlacement: selectedZone
        )
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func calibrate() {
        // Calibration logic
    }
}

// MARK: - Preview

#Preview {
    ExposureMeterView()
        .environment(DependencyContainer.preview())
}
