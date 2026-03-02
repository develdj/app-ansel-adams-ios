import SwiftUI
import SwiftData
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Main App Entry Point

@main
@MainActor
struct ZoneSystemMasterApp: App {
    
    // MARK: - Dependencies
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var dependencyContainer = DependencyContainer.shared
    @State private var appState = AppState()
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dependencyContainer)
                .environment(appState)
                .withDependencyContainer(dependencyContainer)
                .modelContainer(for: [
                    FilmRollModel.self,
                    ExposureRecordModel.self,
                    DevelopmentInfoModel.self
                ])
        }
        .defaultSize(width: 390, height: 844)
        
        // MARK: - Immersive Darkroom Space (visionOS)
        #if os(visionOS)
        ImmersiveSpace(id: "DarkroomSpace") {
            DarkroomImmersiveView()
        }
        #endif
    }
}

// MARK: - App State

@Observable
@MainActor
final class AppState {
    var isLoading = true
    var hasCompletedOnboarding = false
    var currentTheme: AppTheme = .system
    var isProUser = false
    var currentExperienceLevel: UserExperienceLevel = .beginner
    
    init() {
        loadState()
    }
    
    private func loadState() {
        // Load saved state from UserDefaults or SwiftData
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
        
        if let themeRaw = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: themeRaw) {
            currentTheme = theme
        }
        
        if let levelRaw = UserDefaults.standard.string(forKey: "experience_level"),
           let level = UserExperienceLevel(rawValue: levelRaw) {
            currentExperienceLevel = level
        }
        
        // Simulate loading
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            isLoading = false
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "app_theme")
    }
    
    func setExperienceLevel(_ level: UserExperienceLevel) {
        currentExperienceLevel = level
        UserDefaults.standard.set(level.rawValue, forKey: "experience_level")
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Configure appearance
        configureAppearance()
        
        // Register for notifications
        registerForNotifications()
        
        // Initialize services
        initializeServices()
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    private func registerForNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    private func initializeServices() {
        // Initialize core services
        Task {
            await DependencyContainer.shared.store.loadProducts()
        }
    }
}

// MARK: - Scene Delegate

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // Configure window scene
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 320, height: 568)
        windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1366, height: 1024)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Handle scene disconnection
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Handle scene becoming active
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Handle scene resigning active
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Handle scene entering foreground
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Handle scene entering background
    }
}

// MARK: - Extension for Store Protocol

extension StoreProtocol {
    func loadProducts() async {
        // Implementation in concrete type
    }
}
