import SwiftUI
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Content View

@MainActor
struct ContentView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        Group {
            if appState.isLoading {
                SplashScreen()
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(colorScheme)
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
    }
}

// MARK: - Onboarding View

@MainActor
struct OnboardingView: View {
    
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPage(
            title: "Welcome to Zone System Master",
            description: "The definitive digital companion for Ansel Adams' Zone System. Master exposure, development, and printing with precision.",
            image: "camera.aperture",
            color: .blue
        ),
        OnboardingPage(
            title: "Scientific Exposure Meter",
            description: "Measure light and place tones exactly where you want them. Visualize the 11 zones from pure black to pure white.",
            image: "camera.metering.center.weighted",
            color: .orange
        ),
        OnboardingPage(
            title: "Darkroom Timer",
            description: "Precise multi-phase timing for development, stop bath, fixing, and washing. Never miss a critical moment.",
            image: "timer",
            color: .green
        ),
        OnboardingPage(
            title: "Chat with Ansel",
            description: "Ask questions and receive guidance powered by Apple Intelligence. Learn from the master himself.",
            image: "bubble.left.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "Analog Archive",
            description: "Track every roll, every frame, every exposure. Build a complete record of your photographic journey.",
            image: "film.stack.fill",
            color: .pink
        )
    ]
    
    var body: some View {
        ZStack {
            LiquidGlassTheme.Colors.background
                .ignoresSafeArea()
            
            VStack {
                // Page indicator
                HStack(spacing: LiquidGlassTheme.Spacing.xs) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? LiquidGlassTheme.Colors.primary : LiquidGlassTheme.Colors.glassThick)
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(LiquidGlassTheme.Animation.spring, value: currentPage)
                    }
                }
                .padding(.top)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                        if currentPage == pages.count - 1 {
                            appState.completeOnboarding()
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
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

#Preview("Splash Screen") {
    SplashScreen()
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
