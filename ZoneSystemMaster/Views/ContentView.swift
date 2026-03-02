import SwiftUI
import SwiftData

// MARK: - Content View

/// Main content view with tab navigation
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab = 0
    @State private var showNewSessionSheet = false
    @State private var showPrintSessionSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home / Dashboard
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)
            
            // Recipes
            RecipeManagementView(modelContext: modelContext)
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }
                .tag(1)
            
            // History
            SessionHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)
            
            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showNewSessionSheet) {
            NewSessionView(modelContext: modelContext, isPresented: $showNewSessionSheet)
        }
        .sheet(isPresented: $showPrintSessionSheet) {
            NewPrintSessionView(modelContext: modelContext, isPresented: $showPrintSessionSheet)
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var watchManager = WatchConnectivityManager.shared
    
    @State private var showNewSessionSheet = false
    @State private var showNewPrintSheet = false
    @State private var quickStartRecipe: DeveloperRecipe?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Watch Status
                    watchStatusSection
                    
                    // Recent Sessions
                    recentSessionsSection
                    
                    // Tips
                    tipsSection
                }
                .padding()
            }
            .navigationTitle("Zone System Master")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Zone System Master")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Professional Darkroom Timer")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Film Development
                NavigationLink(destination: QuickStartFilmView(modelContext: modelContext)) {
                    QuickActionCard(
                        icon: "film",
                        title: "Develop Film",
                        subtitle: "Start development timer",
                        color: .blue
                    )
                }
                
                // Print
                NavigationLink(destination: QuickStartPrintView(modelContext: modelContext)) {
                    QuickActionCard(
                        icon: "photo",
                        title: "Make Print",
                        subtitle: "Enlarger timer",
                        color: .green
                    )
                }
                
                // Test Strip
                NavigationLink(destination: QuickStartTestStripView(modelContext: modelContext)) {
                    QuickActionCard(
                        icon: "rectangle.split.3x1",
                        title: "Test Strip",
                        subtitle: "Exposure test",
                        color: .orange
                    )
                }
                
                // Split Grade
                NavigationLink(destination: QuickStartSplitGradeView(modelContext: modelContext)) {
                    QuickActionCard(
                        icon: "circle.lefthalf.fill",
                        title: "Split Grade",
                        subtitle: "Advanced printing",
                        color: .purple
                    )
                }
            }
        }
    }
    
    // MARK: - Watch Status Section
    
    private var watchStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: watchManager.isWatchConnected ? "applewatch" : "applewatch.slash")
                .font(.title2)
                .foregroundColor(watchManager.isWatchConnected ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Watch")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(watchManager.isWatchConnected ? "Connected" : "Not Connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if watchManager.isWatchConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Recent Sessions Section
    
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
            
            // Placeholder for recent sessions
            HStack {
                Image(systemName: "film")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("HP5+ in D-76")
                        .font(.subheadline)
                    Text("2 hours ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("8:00")
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Tips Section
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Darkroom Tip")
                .font(.headline)
            
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Temperature Matters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Keep your developer at 20°C (68°F) for consistent results. Use a water bath to maintain temperature.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Quick Start Views

struct QuickStartFilmView: View {
    let modelContext: ModelContext
    @State private var selectedRecipe: DeveloperRecipe?
    @State private var showTimer = false
    
    var body: some View {
        RecipeSelectionView(modelContext: modelContext, selection: $selectedRecipe)
            .navigationTitle("Select Recipe")
            .sheet(isPresented: $showTimer) {
                if let recipe = selectedRecipe {
                    let session = FilmDevelopmentSession(modelContext: modelContext)
                    session.configure(with: recipe, context: modelContext)
                    TimerControlView(session: session)
                }
            }
            .onChange(of: selectedRecipe) { _, newValue in
                if newValue != nil {
                    showTimer = true
                }
            }
    }
}

struct QuickStartPrintView: View {
    let modelContext: ModelContext
    @State private var selectedRecipe: PrintRecipe?
    @State private var showTimer = false
    
    var body: some View {
        PrintRecipeSelectionView(modelContext: modelContext, selection: $selectedRecipe)
            .navigationTitle("Select Print Recipe")
            .sheet(isPresented: $showTimer) {
                if let recipe = selectedRecipe {
                    let session = PrintSession(modelContext: modelContext)
                    session.configureForFullPrint(
                        recipe: recipe,
                        exposureSeconds: 10.0,
                        context: modelContext
                    )
                    PrintTimerView(session: session)
                }
            }
            .onChange(of: selectedRecipe) { _, newValue in
                if newValue != nil {
                    showTimer = true
                }
            }
    }
}

struct QuickStartTestStripView: View {
    let modelContext: ModelContext
    @State private var selectedRecipe: PrintRecipe?
    @State private var showTimer = false
    
    var body: some View {
        PrintRecipeSelectionView(modelContext: modelContext, selection: $selectedRecipe)
            .navigationTitle("Test Strip")
            .sheet(isPresented: $showTimer) {
                if let recipe = selectedRecipe {
                    let session = PrintSession(modelContext: modelContext)
                    session.configureForTestStrip(
                        recipe: recipe,
                        baseExposure: 2.0,
                        context: modelContext
                    )
                    PrintTimerView(session: session)
                }
            }
            .onChange(of: selectedRecipe) { _, newValue in
                if newValue != nil {
                    showTimer = true
                }
            }
    }
}

struct QuickStartSplitGradeView: View {
    let modelContext: ModelContext
    @State private var selectedRecipe: PrintRecipe?
    @State private var showTimer = false
    
    var body: some View {
        PrintRecipeSelectionView(modelContext: modelContext, selection: $selectedRecipe)
            .navigationTitle("Split Grade")
            .sheet(isPresented: $showTimer) {
                if let recipe = selectedRecipe {
                    let session = PrintSession(modelContext: modelContext)
                    session.configureForSplitGrade(
                        recipe: recipe,
                        lowContrastSecs: 5.0,
                        highContrastSecs: 5.0,
                        context: modelContext
                    )
                    PrintTimerView(session: session)
                }
            }
            .onChange(of: selectedRecipe) { _, newValue in
                if newValue != nil {
                    showTimer = true
                }
            }
    }
}

// MARK: - Recipe Selection Views

struct RecipeSelectionView: View {
    let modelContext: ModelContext
    @Binding var selection: DeveloperRecipe?
    @State private var recipes: [DeveloperRecipe] = []
    
    var body: some View {
        List {
            ForEach(recipes) { recipe in
                Button(action: {
                    selection = recipe
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(recipe.summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(recipe.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            loadRecipes()
        }
    }
    
    private func loadRecipes() {
        let descriptor = FetchDescriptor<DeveloperRecipe>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        recipes = (try? modelContext.fetch(descriptor)) ?? []
    }
}

struct PrintRecipeSelectionView: View {
    let modelContext: ModelContext
    @Binding var selection: PrintRecipe?
    @State private var recipes: [PrintRecipe] = []
    
    var body: some View {
        List {
            ForEach(recipes) { recipe in
                Button(action: {
                    selection = recipe
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("\(recipe.paperType.rawValue) • \(recipe.developerName.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(recipe.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            loadRecipes()
        }
    }
    
    private func loadRecipes() {
        let descriptor = FetchDescriptor<PrintRecipe>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        recipes = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - New Session Views

struct NewSessionView: View {
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Text("New Session Configuration")
                .navigationTitle("New Session")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}

struct NewPrintSessionView: View {
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Text("New Print Session Configuration")
                .navigationTitle("New Print Session")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
