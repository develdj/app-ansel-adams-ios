import SwiftUI
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Content View

@MainActor
struct ContentView: View {

    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var container
    @State private var showSplash = true
    @State private var showMainContent = false

    var body: some View {
        ZStack {
            // Main content (only shown after splash)
            if showMainContent {
                Group {
                    if appState.hasCompletedOnboarding {
                        MainTabView()
                    } else {
                        OnboardingView()
                    }
                }
                .preferredColorScheme(colorScheme)
                .transition(.opacity)
            }

            // Splash screen overlay (always shows first)
            if showSplash {
                EnhancedSplashScreen {
                    dismissSplash()
                }
                .zIndex(1)
            }
        }
        .onAppear {
            // Fallback: ensure splash dismisses after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if showSplash {
                    dismissSplash()
                }
            }
        }
    }

    private func dismissSplash() {
        withAnimation(.easeOut(duration: 0.3)) {
            showSplash = false
        }
        // Show main content after splash starts fading out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.3)) {
                showMainContent = true
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appState.currentTheme {
        case .light: return .light
        case .dark, .darkroom: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Splash Screen

struct SplashScreen: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            LiquidGlassTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: LiquidGlassTheme.Spacing.xl) {
                // Logo
                ZStack {
                    // Zone scale gradient
                    LinearGradient(
                        colors: [
                            LiquidGlassTheme.Colors.zone0,
                            LiquidGlassTheme.Colors.zone5,
                            LiquidGlassTheme.Colors.zone10
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    
                    // App icon overlay
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white)
                }
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
                
                VStack(spacing: LiquidGlassTheme.Spacing.sm) {
                    Text("Zone System")
                        .font(LiquidGlassTheme.Typography.largeTitle)
                    
                    Text("Master")
                        .font(LiquidGlassTheme.Typography.title1)
                        .foregroundColor(.secondary)
                }
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
                
                Spacer()
                
                ProgressView()
                    .scaleEffect(1.2)
                    .opacity(isAnimating ? 1.0 : 0.0)
            }
            .padding(.top, 100)
            .padding(.bottom, 60)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Main Tab View

@MainActor
struct MainTabView: View {

    @State private var selectedTab: Tab = .meter
    @Environment(DependencyContainer.self) private var container
    @State private var navigationManager = ChatNavigationManager.shared

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case meter = "Meter"
        case timer = "Timer"
        case archive = "Archive"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat: return "bubble.left.fill"
            case .meter: return "camera.metering.center.weighted"
            case .timer: return "timer"
            case .archive: return "film.stack.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // Convert AppDestination to Tab
    private func tab(for destination: AppDestination) -> Tab? {
        switch destination {
        case .chat: return .chat
        case .exposureMeter: return .meter
        case .darkroomTimer: return .timer
        case .filmArchive: return .archive
        case .photoEditor: return .archive // Editor is under Archive tab for now
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AnselChatView()
                .tabItem {
                    Label(Tab.chat.rawValue, systemImage: Tab.chat.icon)
                }
                .tag(Tab.chat)
            
            ExposureMeterView()
                .tabItem {
                    Label(Tab.meter.rawValue, systemImage: Tab.meter.icon)
                }
                .tag(Tab.meter)
            
            DarkroomTimerView()
                .tabItem {
                    Label(Tab.timer.rawValue, systemImage: Tab.timer.icon)
                }
                .tag(Tab.timer)
            
            AnalogArchiveView()
                .tabItem {
                    Label(Tab.archive.rawValue, systemImage: Tab.archive.icon)
                }
                .tag(Tab.archive)
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(LiquidGlassTheme.Colors.primary)
        .onChange(of: navigationManager.selectedDestination) { _, destination in
            if let destination = destination,
               let tab = tab(for: destination) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = tab
                }
                // Clear the destination after navigating
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navigationManager.selectedDestination = nil
                }
            }
        }
    }
}

// MARK: - Onboarding View

@MainActor
struct OnboardingView: View {

    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    @State private var isDismissed = false

    private let pages = [
        OnboardingPage(
            title: "Welcome to Zone System Master",
            description: "The definitive digital companion for mastering Ansel Adams' Zone System. Precision exposure, development, and printing tools in your pocket.",
            image: "camera.aperture",
            color: .blue
        ),
        OnboardingPage(
            title: "Scientific Exposure Meter",
            description: "Measure light and place tones exactly where you want them. Visualize the 11 zones from pure black to pure white with real-time feedback.",
            image: "camera.metering.center.weighted",
            color: .orange
        ),
        OnboardingPage(
            title: "Darkroom Timer",
            description: "Precise multi-phase timing for development, stop bath, fixing, and washing. Temperature-compensated timing ensures perfect results every time.",
            image: "timer",
            color: .green
        ),
        OnboardingPage(
            title: "Chat with PAI",
            description: "Ask questions and receive guidance powered by Apple Intelligence. Your Photography AI assistant helps you master the Zone System and navigate every feature.",
            image: "bubble.left.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "Analog Archive",
            description: "Track every roll, every frame, every exposure. Build a complete record of your photographic journey and learn from your shooting patterns.",
            image: "film.stack.fill",
            color: .pink
        )
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    pages[currentPage].color.opacity(0.1),
                    LiquidGlassTheme.Colors.background,
                    pages[currentPage].color.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.completeOnboarding()
                            isDismissed = true
                        }
                    } label: {
                        Text("Skip")
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                Spacer()

                // Page indicator
                HStack(spacing: LiquidGlassTheme.Spacing.xs) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? pages[currentPage].color : LiquidGlassTheme.Colors.glassThick)
                            .frame(width: currentPage == index ? 28 : 8, height: 8)
                            .animation(LiquidGlassTheme.Animation.spring, value: currentPage)
                    }
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer()

                // Navigation buttons
                HStack(spacing: LiquidGlassTheme.Spacing.md) {
                    if currentPage > 0 {
                        Button {
                            withAnimation(.easeInOut) {
                                currentPage -= 1
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(LiquidGlassTheme.Typography.body)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(LiquidGlassTheme.Colors.glassRegular)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Spacer()

                    Button {
                        if currentPage == pages.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                appState.completeOnboarding()
                                isDismissed = true
                            }
                        } else {
                            withAnimation(.easeInOut) {
                                currentPage += 1
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                            if currentPage < pages.count - 1 {
                                Image(systemName: "chevron.right")
                            } else {
                                Image(systemName: "checkmark")
                            }
                        }
                        .font(LiquidGlassTheme.Typography.body.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(pages[currentPage].color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: pages[currentPage].color.opacity(0.3), radius: 8, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .opacity(isDismissed ? 0 : 1)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -100 {
                        // Swipe up to dismiss
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.completeOnboarding()
                            isDismissed = true
                        }
                    }
                }
        )
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let image: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: LiquidGlassTheme.Spacing.xl) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.2))
                    .frame(width: 140, height: 140)
                
                Image(systemName: page.image)
                    .font(.system(size: 60))
                    .foregroundColor(page.color)
            }
            
            // Text
            VStack(spacing: LiquidGlassTheme.Spacing.md) {
                Text(page.title)
                    .font(LiquidGlassTheme.Typography.title1)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Enhanced Splash Screen") {
    EnhancedSplashScreen {
        print("Splash dismissed in preview")
    }
}

#Preview("Main Tab View") {
    MainTabView()
        .environment(DependencyContainer.preview())
        .environment(AppState())
}

#Preview("Onboarding") {
    OnboardingView()
        .environment(AppState())
}
