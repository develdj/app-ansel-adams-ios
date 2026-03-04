import SwiftUI
import ZoneSystemUI

// MARK: - Liquid Glass Toolbar Button
/// A compact, glass-styled button for toolbar actions
/// Features scale animation on press and liquid glass visual style

struct LiquidGlassToolbarButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.body.bold())
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    // Main glass background
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(isEnabled ? 1.0 : 0.5)

                    // Border with highlight
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: isEnabled ? [
                                    Color.white.opacity(isHovered ? 0.25 : 0.15),
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(isHovered ? 0.15 : 0.08)
                                ] : [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.02),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )

                    // Subtle glow for enabled state
                    if isEnabled && !isPressed {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1)
                            .blur(radius: 4)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

// MARK: - Preview

#Preview("Toolbar Buttons") {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            LiquidGlassToolbarButton(
                icon: "sparkles",
                title: "Apply AI"
            ) {
                print("Apply AI tapped")
            }

            LiquidGlassToolbarButton(
                icon: "slider.horizontal.3",
                title: "Edit"
            ) {
                print("Edit tapped")
            }

            LiquidGlassToolbarButton(
                icon: "chevron.down",
                title: "Done"
            ) {
                print("Done tapped")
            }
        }

        HStack(spacing: 12) {
            LiquidGlassToolbarButton(
                icon: "sparkles",
                title: "Apply AI",
                isEnabled: false
            ) {
                print("Apply AI tapped")
            }

            LiquidGlassToolbarButton(
                icon: "slider.horizontal.3",
                title: "Edit",
                isEnabled: false
            ) {
                print("Edit tapped")
            }
        }
    }
    .padding()
    .background(
        ZStack {
            Color.black.opacity(0.1)
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    )
}
