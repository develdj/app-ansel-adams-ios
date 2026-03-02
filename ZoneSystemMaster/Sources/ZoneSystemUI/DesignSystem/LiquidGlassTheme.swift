import SwiftUI

// MARK: - Liquid Glass Design System
/// Implements Apple's Liquid Glass Human Interface Guidelines

@MainActor
public struct LiquidGlassTheme {
    
    // MARK: - Colors
    
    public struct Colors {
        // Primary colors
        public static let primary = Color.accentColor
        public static let onPrimary = Color.white
        
        // Background colors with glass effect
        public static let background = Color(.systemBackground)
        public static let backgroundSecondary = Color(.secondarySystemBackground)
        public static let backgroundTertiary = Color(.tertiarySystemBackground)
        
        // Glass effect colors
        public static let glassUltraThin = Color.white.opacity(0.05)
        public static let glassThin = Color.white.opacity(0.10)
        public static let glassRegular = Color.white.opacity(0.20)
        public static let glassThick = Color.white.opacity(0.35)
        public static let glassUltraThick = Color.white.opacity(0.50)
        
        // Zone System specific colors
        public static let zone0 = Color.black
        public static let zone1 = Color(white: 0.10)
        public static let zone2 = Color(white: 0.20)
        public static let zone3 = Color(white: 0.30)
        public static let zone4 = Color(white: 0.40)
        public static let zone5 = Color(white: 0.50)
        public static let zone6 = Color(white: 0.60)
        public static let zone7 = Color(white: 0.70)
        public static let zone8 = Color(white: 0.80)
        public static let zone9 = Color(white: 0.90)
        public static let zone10 = Color.white
        
        public static func zoneColor(_ zone: Zone) -> Color {
            switch zone {
            case .zone0: return zone0
            case .zone1: return zone1
            case .zone2: return zone2
            case .zone3: return zone3
            case .zone4: return zone4
            case .zone5: return zone5
            case .zone6: return zone6
            case .zone7: return zone7
            case .zone8: return zone8
            case .zone9: return zone9
            case .zone10: return zone10
            }
        }
        
        // Darkroom safe colors
        public static let darkroomRed = Color(red: 0.8, green: 0.0, blue: 0.0)
        public static let darkroomAmber = Color(red: 1.0, green: 0.6, blue: 0.0)
        public static let darkroomGreen = Color(red: 0.0, green: 0.7, blue: 0.0)
        
        // Semantic colors
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue
        
        // Text colors
        public static let textPrimary = Color.primary
        public static let textSecondary = Color.secondary
        public static let textTertiary = Color.gray
    }
    
    // MARK: - Typography
    
    public struct Typography {
        // Large titles
        public static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        public static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        public static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
        public static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        
        // Body text
        public static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
        public static let body = Font.system(size: 16, weight: .regular, design: .default)
        public static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)
        
        // Specialized
        public static let caption = Font.system(size: 12, weight: .regular, design: .default)
        public static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        public static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        
        // Monospace for technical data
        public static let monoLarge = Font.system(size: 20, weight: .medium, design: .monospaced)
        public static let mono = Font.system(size: 16, weight: .medium, design: .monospaced)
        public static let monoSmall = Font.system(size: 14, weight: .medium, design: .monospaced)
        
        // Zone System specific
        public static let zoneNumber = Font.system(size: 24, weight: .bold, design: .rounded)
        public static let evValue = Font.system(size: 32, weight: .bold, design: .monospaced)
        public static let timerDisplay = Font.system(size: 48, weight: .bold, design: .monospaced)
    }
    
    // MARK: - Spacing
    
    public struct Spacing {
        public static let xxxs: CGFloat = 2
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
        public static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    public struct CornerRadius {
        public static let none: CGFloat = 0
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
        public static let full: CGFloat = 9999
    }
    
    // MARK: - Shadows
    
    public struct Shadows {
        public static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        public static let xs = ShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        public static let sm = ShadowStyle(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        public static let md = ShadowStyle(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        public static let lg = ShadowStyle(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
        public static let xl = ShadowStyle(color: .black.opacity(0.20), radius: 24, x: 0, y: 12)
    }
    
    public struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Animation
    
    public struct Animation {
        public static let instant: SwiftUI.Animation = .easeInOut(duration: 0.1)
        public static let fast: SwiftUI.Animation = .easeInOut(duration: 0.2)
        public static let normal: SwiftUI.Animation = .easeInOut(duration: 0.3)
        public static let slow: SwiftUI.Animation = .easeInOut(duration: 0.5)
        public static let spring: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.8)
        public static let bouncy: SwiftUI.Animation = .spring(response: 0.5, dampingFraction: 0.6)
    }
    
    // MARK: - Glass Material
    
    public struct Glass {
        public static let ultraThin: Material = .ultraThinMaterial
        public static let thin: Material = .thinMaterial
        public static let regular: Material = .regularMaterial
        public static let thick: Material = .thickMaterial
        public static let ultraThick: Material = .ultraThickMaterial
    }
}

// MARK: - View Extensions

public extension View {
    func liquidGlassCard(
        background: Material = .regularMaterial,
        cornerRadius: CGFloat = LiquidGlassTheme.CornerRadius.lg,
        shadow: LiquidGlassTheme.ShadowStyle = LiquidGlassTheme.Shadows.md
    ) -> some View {
        self
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func liquidGlassButton(
        style: LiquidGlassButtonStyle.Style = .primary
    ) -> some View {
        self.buttonStyle(LiquidGlassButtonStyle(style: style))
    }
    
    func zoneBorder(_ zone: Zone, width: CGFloat = 2) -> some View {
        self.border(LiquidGlassTheme.Colors.zoneColor(zone), width: width)
    }
    
    func darkroomSafe(color: DarkroomSafeColor = .red) -> some View {
        self.colorMultiply(LiquidGlassTheme.Colors.darkroomRed)
    }
}

// MARK: - Liquid Glass Button Style

public struct LiquidGlassButtonStyle: ButtonStyle {
    
    public enum Style {
        case primary
        case secondary
        case tertiary
        case destructive
        case zone(Zone)
    }
    
    let style: Style
    
    public init(style: Style = .primary) {
        self.style = style
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LiquidGlassTheme.Typography.bodyLarge.weight(.semibold))
            .padding(.horizontal, LiquidGlassTheme.Spacing.lg)
            .padding(.vertical, LiquidGlassTheme.Spacing.md)
            .background(background(for: style, isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor(for: style))
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(LiquidGlassTheme.Animation.fast, value: configuration.isPressed)
    }
    
    private func background(for style: Style, isPressed: Bool) -> some View {
        Group {
            switch style {
            case .primary:
                LiquidGlassTheme.Colors.primary
                    .opacity(isPressed ? 0.8 : 1.0)
            case .secondary:
                LiquidGlassTheme.Colors.glassRegular
                    .opacity(isPressed ? 0.3 : 0.2)
            case .tertiary:
                Color.clear
            case .destructive:
                LiquidGlassTheme.Colors.error
                    .opacity(isPressed ? 0.8 : 1.0)
            case .zone(let zone):
                LiquidGlassTheme.Colors.zoneColor(zone)
                    .opacity(isPressed ? 0.8 : 1.0)
            }
        }
    }
    
    private func foregroundColor(for style: Style) -> Color {
        switch style {
        case .primary, .destructive, .zone:
            return .white
        case .secondary, .tertiary:
            return .primary
        }
    }
}

// MARK: - Zone Badge

public struct ZoneBadge: View {
    let zone: Zone
    let size: Size
    
    public enum Size {
        case small
        case medium
        case large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 36
            case .large: return 48
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .caption.weight(.bold)
            case .medium: return .body.weight(.bold)
            case .large: return .title3.weight(.bold)
            }
        }
    }
    
    public init(zone: Zone, size: Size = .medium) {
        self.zone = zone
        self.size = size
    }
    
    public var body: some View {
        Text("\(zone.rawValue)")
            .font(size.font)
            .foregroundColor(zone.rawValue < 5 ? .white : .black)
            .frame(width: size.dimension, height: size.dimension)
            .background(LiquidGlassTheme.Colors.zoneColor(zone))
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.sm, style: .continuous))
    }
}

// MARK: - EV Display

public struct EVDisplay: View {
    let ev: ExposureValue
    let showDecimal: Bool
    
    public init(ev: ExposureValue, showDecimal: Bool = false) {
        self.ev = ev
        self.showDecimal = showDecimal
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            Text("EV")
                .font(LiquidGlassTheme.Typography.caption)
                .foregroundColor(.secondary)
            
            if showDecimal {
                Text(String(format: "%+.1f", Double(ev.rawValue)))
                    .font(LiquidGlassTheme.Typography.evValue)
            } else {
                Text("\(ev.rawValue)")
                    .font(LiquidGlassTheme.Typography.evValue)
            }
        }
        .monospacedDigit()
    }
}

// MARK: - Timer Display

public struct TimerDisplay: View {
    let remaining: TimeInterval
    let total: TimeInterval
    let phase: DarkroomPhase?
    
    public init(remaining: TimeInterval, total: TimeInterval, phase: DarkroomPhase? = nil) {
        self.remaining = remaining
        self.total = total
        self.phase = phase
    }
    
    public var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.sm) {
            if let phase = phase {
                Label(phase.rawValue, systemImage: phase.icon)
                    .font(LiquidGlassTheme.Typography.title3)
                    .foregroundColor(Color(hex: phase.color))
            }
            
            Text(formattedTime(remaining))
                .font(LiquidGlassTheme.Typography.timerDisplay)
                .monospacedDigit()
            
            ProgressView(value: remaining, total: total)
                .progressViewStyle(LiquidGlassProgressStyle())
                .frame(maxWidth: 200)
        }
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Liquid Glass Progress Style

public struct LiquidGlassProgressStyle: ProgressViewStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.xs)
                    .fill(LiquidGlassTheme.Colors.glassThin)
                
                if let fractionCompleted = configuration.fractionCompleted {
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.xs)
                        .fill(LiquidGlassTheme.Colors.primary)
                        .frame(width: geometry.size.width * fractionCompleted)
                        .animation(LiquidGlassTheme.Animation.normal, value: fractionCompleted)
                }
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Film Format Picker

public struct FilmFormatPicker: View {
    @Binding var selection: FilmFormat
    
    public init(selection: Binding<FilmFormat>) {
        self._selection = selection
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LiquidGlassTheme.Spacing.sm) {
                ForEach(FilmFormat.allCases) { format in
                    FormatButton(
                        format: format,
                        isSelected: selection == format
                    ) {
                        withAnimation(LiquidGlassTheme.Animation.spring) {
                            selection = format
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FormatButton: View {
    let format: FilmFormat
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: LiquidGlassTheme.Spacing.xs) {
                // Aspect ratio preview
                RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.xs)
                    .stroke(isSelected ? LiquidGlassTheme.Colors.primary : LiquidGlassTheme.Colors.glassThick, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.xs)
                            .fill(isSelected ? LiquidGlassTheme.Colors.primary.opacity(0.2) : LiquidGlassTheme.Colors.glassThin)
                    )
                    .frame(width: 50, height: 50 / format.aspectRatio)
                
                Text(format.rawValue)
                    .font(LiquidGlassTheme.Typography.caption)
                    .foregroundColor(isSelected ? LiquidGlassTheme.Colors.primary : .primary)
            }
            .padding(LiquidGlassTheme.Spacing.sm)
            .background(isSelected ? LiquidGlassTheme.Colors.glassRegular : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Emulsion Picker

public struct EmulsionPicker: View {
    @Binding var selection: FilmEmulsion
    
    public init(selection: Binding<FilmEmulsion>) {
        self._selection = selection
    }
    
    public var body: some View {
        List(FilmEmulsion.allCases) { emulsion in
            EmulsionRow(emulsion: emulsion, isSelected: selection == emulsion) {
                selection = emulsion
            }
        }
        .listStyle(.plain)
    }
}

private struct EmulsionRow: View {
    let emulsion: FilmEmulsion
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: LiquidGlassTheme.Spacing.xxs) {
                    Text(emulsion.rawValue)
                        .font(LiquidGlassTheme.Typography.body.weight(.medium))
                    
                    HStack(spacing: LiquidGlassTheme.Spacing.xs) {
                        Text("ISO \(emulsion.iso)")
                            .font(LiquidGlassTheme.Typography.caption)
                            .foregroundColor(.secondary)
                        
                        Text("γ: \(String(format: "%.2f", emulsion.contrastIndex))")
                            .font(LiquidGlassTheme.Typography.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LiquidGlassTheme.Colors.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, LiquidGlassTheme.Spacing.xs)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
