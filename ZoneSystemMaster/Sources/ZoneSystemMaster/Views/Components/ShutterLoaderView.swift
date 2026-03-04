import SwiftUI

// MARK: - Shutter Loader View
// A modern camera shutter-inspired loading animation

struct ShutterLoaderView: View {
    @State private var isAnimating = false
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.3

    var body: some View {
        ZStack {
            // Outer ring - aperture blades
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    ShutterBlade(
                        angle: Double(index) * 45,
                        isOpen: isAnimating,
                        delay: Double(index) * 0.05
                    )
                }
            }
            .frame(width: 120, height: 120)
            .rotationEffect(.degrees(rotation))

            // Center lens element
            Circle()
                .fill(
                    LinearGradient(
                        colors: [LiquidGlassTheme.Colors.primary, LiquidGlassTheme.Colors.zone5],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40 * scale, height: 40 * scale)
                .opacity(opacity)
                .blur(radius: 5)

            // Inner highlight
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 20 * scale, height: 20 * scale)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }

            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.3
                opacity = 0.8
            }
        }
    }
}

// MARK: - Shutter Blade

struct ShutterBlade: View {
    let angle: Double
    let isOpen: Bool
    let delay: Double

    @State private var bladeScale: CGFloat = 0.0
    @State private var bladeRotation: CGFloat = 0.0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        LiquidGlassTheme.Colors.zone0.opacity(0.6),
                        LiquidGlassTheme.Colors.zone10.opacity(0.6)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 50, height: 8)
            .rotationEffect(.degrees(angle + bladeRotation), anchor: .trailing)
            .offset(x: 25)
            .rotationEffect(.degrees(angle))
            .scaleEffect(bladeScale)
            .onAppear {
                let baseDelay = delay + 0.3

                // Opening animation
                DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        bladeScale = 1.0
                    }
                }

                // Continuous breathing animation
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.6)) {
                    bladeRotation = isOpen ? 15 : 0
                }
            }
    }
}

// MARK: - Enhanced Splash Screen

struct EnhancedSplashScreen: View {
    @State private var titleScale: CGFloat = 0.8
    @State private var titleOpacity: Double = 0.0
    @State private var subtitleOpacity: Double = 0.0
    @State private var progress: Double = 0.0
    @State private var isDismissed = false

    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Background matching LaunchScreen.storyboard
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.1, green: 0.05, blue: 0.15).opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: LiquidGlassTheme.Spacing.xl) {
                Spacer()

                // Shutter loader
                ShutterLoaderView()

                // App title
                VStack(spacing: LiquidGlassTheme.Spacing.sm) {
                    Text("Zone System")
                        .font(LiquidGlassTheme.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [LiquidGlassTheme.Colors.primary, LiquidGlassTheme.Colors.zone7],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(titleScale)
                        .opacity(titleOpacity)

                    Text("Master")
                        .font(LiquidGlassTheme.Typography.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .opacity(titleOpacity)

                    Text("by PAI")
                        .font(LiquidGlassTheme.Typography.caption)
                        .foregroundColor(LiquidGlassTheme.Colors.primary)
                        .opacity(subtitleOpacity)
                }

                Spacer()

                // Loading progress
                VStack(spacing: LiquidGlassTheme.Spacing.sm) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.3, green: 0.4, blue: 0.7), Color(red: 0.3, green: 0.5, blue: 0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text("Loading your photography studio...")
                        .font(LiquidGlassTheme.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .opacity(isDismissed ? 0 : 1)
        .task {
            // Start animations immediately on appear
            await animateAndDismiss()
        }
    }

    private func animateAndDismiss() async {
        // Animate title appearance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            titleScale = 1.0
            titleOpacity = 1.0
        }

        // Animate subtitle
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.easeIn(duration: 0.2)) {
            subtitleOpacity = 1.0
        }

        // Animate progress
        withAnimation(.easeOut(duration: 0.6)) {
            progress = 1.0
        }

        // Wait a bit then dismiss
        try? await Task.sleep(for: .milliseconds(400))

        withAnimation(.easeOut(duration: 0.3)) {
            isDismissed = true
        }

        // Notify parent to dismiss
        try? await Task.sleep(for: .milliseconds(300))
        await MainActor.run {
            onDismiss?()
        }
    }
}

// MARK: - Preview

#Preview("Shutter Loader") {
    ZStack {
        Color.black
            .ignoresSafeArea()

        VStack(spacing: 40) {
            ShutterLoaderView()

            Text("Loading...")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

#Preview("Enhanced Splash") {
    EnhancedSplashScreen {
        print("Splash dismissed")
    }
}
