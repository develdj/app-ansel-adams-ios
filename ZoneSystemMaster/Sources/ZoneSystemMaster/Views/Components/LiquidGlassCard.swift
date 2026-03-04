import SwiftUI
import ZoneSystemUI

// MARK: - Enhanced Glass Card
/// An enhanced glass card component with subtle border highlights and visual depth
/// Provides ethereal, translucent appearance following Liquid Glass design principles

struct EnhancedGlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 16
    var shadowRadius: CGFloat = 10

    @State private var isAppeared = false

    init(
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }

    var body: some View {
        content
            .background(
                ZStack {
                    // Main glass background with dynamic blur
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(isAppeared ? 0.85 : 0.6)

                    // Shimmer effect overlay
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(isAppeared ? 0.08 : 0),
                                    Color.white.opacity(0)
                                ],
                                startPoint: isAppeared .topLeading : .bottomLeading,
                                endPoint: isAppeared ? .bottomTrailing : .topTrailing
                            )
                        )
                        .opacity(isAppeared ? 1 : 0)

                    // Subtle border highlight with gradient
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isAppeared ? 0.2 : 0.1),
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(isAppeared ? 0.12 : 0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )

                    // Inner shadow for depth perception
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 2)
                        .blur(radius: 3)

                    // Subtle glow at edges
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isAppeared ? 0.15 : 0.05),
                                    .clear,
                                    Color.white.opacity(isAppeared ? 0.1 : 0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .blur(radius: 4)
                }
            )
            .shadow(
                color: Color.black.opacity(isAppeared ? 0.12 : 0.08),
                radius: isAppeared ? shadowRadius : shadowRadius * 0.7,
                x: 0,
                y: isAppeared ? 4 : 2
            )
            .scaleEffect(isAppeared ? 1.0 : 0.97)
            .opacity(isAppeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAppeared)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) {
                    isAppeared = true
                }
            }
    }
}

// MARK: - Preview

#Preview("Enhanced Glass Card") {
    ScrollView {
        VStack(spacing: 30) {
            EnhancedGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.accentColor)
                        Text("AI Suggestion")
                            .font(.headline)
                        Spacer()
                    }

                    Text("This is an enhanced glass card with subtle borders, shimmer animation, and improved visual depth.")
                        .font(.body)
                        .foregroundColor(.secondary)

                    HStack {
                        Button("Apply") {}
                            .buttonStyle(.borderedProminent)
                        Button("Dismiss") {}
                            .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .frame(width: 280)

            EnhancedGlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zone V")
                            .font(.title.bold())
                        Text("Middle Gray")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.8), Color.gray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.2), radius: 4)
                }
                .padding()
            }
            .frame(width: 200)

            EnhancedGlassCard(cornerRadius: 20, shadowRadius: 15) {
                HStack(spacing: 16) {
                    Image(systemName: "camera.aperture")
                        .font(.largeTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exposure Control")
                            .font(.headline)
                        Text("Adjust aperture and shutter")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .padding()
    }
    .background(
        ZStack {
            Color.black.opacity(0.05)
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.08),
                    Color.pink.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    )
}
