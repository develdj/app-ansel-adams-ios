import SwiftUI
import SwiftData

// MARK: - Recipe Management View

/// Main view for managing film and print recipes
struct RecipeManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var recipeManager: RecipeManager
    
    @State private var selectedTab = 0
    @State private var showAddRecipeSheet = false
    @State private var showAddPrintRecipeSheet = false
    @State private var searchText = ""
    @State private var selectedRecipe: DeveloperRecipe?
    @State private var showRecipeDetail = false
    
    init(modelContext: ModelContext) {
        _recipeManager = StateObject(wrappedValue: RecipeManager(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search recipes...")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Tab selector
                Picker("Type", selection: $selectedTab) {
                    Text("Film Recipes").tag(0)
                    Text("Print Recipes").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Content
                if selectedTab == 0 {
                    filmRecipesList
                } else {
                    printRecipesList
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            if selectedTab == 0 {
                                showAddRecipeSheet = true
                            } else {
                                showAddPrintRecipeSheet = true
                            }
                        }) {
                            Label("Add New", systemImage: "plus")
                        }
                        
                        Button(action: {
                            recipeManager.loadBuiltInPresets()
                            recipeManager.loadPrintPresets()
                        }) {
                            Label("Load Presets", systemImage: "arrow.down.circle")
                        }
                        
                        if selectedTab == 0 {
                            Button(action: {
                                // Export all recipes
                            }) {
                                Label("Export All", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddRecipeSheet) {
                AddRecipeView(recipeManager: recipeManager, isPresented: $showAddRecipeSheet)
            }
            .sheet(isPresented: $showAddPrintRecipeSheet) {
                AddPrintRecipeView(recipeManager: recipeManager, isPresented: $showAddPrintRecipeSheet)
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe, recipeManager: recipeManager)
            }
        }
    }
    
    // MARK: - Film Recipes List
    
    private var filmRecipesList: some View {
        List {
            // Favorites Section
            if !recipeManager.favoriteRecipes.isEmpty && searchText.isEmpty {
                Section("Favorites") {
                    ForEach(recipeManager.favoriteRecipes) { recipe in
                        RecipeRow(recipe: recipe, recipeManager: recipeManager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecipe = recipe
                            }
                    }
                }
            }
            
            // Recent Section
            if !recipeManager.recentRecipes.isEmpty && searchText.isEmpty {
                Section("Recently Used") {
                    ForEach(recipeManager.recentRecipes) { recipe in
                        RecipeRow(recipe: recipe, recipeManager: recipeManager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRecipe = recipe
                            }
                    }
                }
            }
            
            // All Recipes
            Section("All Recipes") {
                let recipes = searchText.isEmpty ? recipeManager.filmRecipes : recipeManager.searchResults
                ForEach(recipes) { recipe in
                    RecipeRow(recipe: recipe, recipeManager: recipeManager)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRecipe = recipe
                        }
                }
                .onDelete { indexSet in
                    recipeManager.deleteFilmRecipes(at: indexSet)
                }
            }
        }
        .listStyle(.insetGrouped)
        .onChange(of: searchText) { _, newValue in
            recipeManager.search(query: newValue)
        }
    }
    
    // MARK: - Print Recipes List
    
    private var printRecipesList: some View {
        List {
            ForEach(recipeManager.printRecipes) { recipe in
                PrintRecipeRow(recipe: recipe)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    recipeManager.deletePrintRecipe(recipeManager.printRecipes[index])
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Recipe Row

struct RecipeRow: View {
    let recipe: DeveloperRecipe
    @ObservedObject var recipeManager: RecipeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Zone system indicator
            ZStack {
                Circle()
                    .fill(zoneColor)
                    .frame(width: 36, height: 36)
                Text(recipe.zoneSystem.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Recipe info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(recipe.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(recipe.formattedTime, systemImage: "clock")
                        .font(.caption2)
                    
                    Label(String(format: "%.0f°C", recipe.temperatureCelsius), systemImage: "thermometer")
                        .font(.caption2)
                    
                    Label(recipe.agitationStyle.rawValue, systemImage: "arrow.2.circlepath")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Favorite button
            Button(action: {
                recipeManager.toggleFavorite(recipe)
            }) {
                Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                    .foregroundColor(recipe.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
    
    private var zoneColor: Color {
        switch recipe.zoneSystem {
        case .minus2: return .blue
        case .minus1: return .cyan
        case .normal: return .green
        case .plus1: return .orange
        case .plus2: return .red
        }
    }
}

// MARK: - Print Recipe Row

struct PrintRecipeRow: View {
    let recipe: PrintRecipe
    
    var body: some View {
        HStack(spacing: 12) {
            // Paper type icon
            Image(systemName: "photo")
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 36, height: 36)
                .background(Color.purple.opacity(0.1))
                .clipShape(Circle())
            
            // Recipe info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(recipe.paperType.rawValue) • \(recipe.developerName.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Label(recipe.formattedTime, systemImage: "clock")
                        .font(.caption2)
                    
                    Label(String(format: "%.0f°C", recipe.temperatureCelsius), systemImage: "thermometer")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Add Recipe View

struct AddRecipeView: View {
    @ObservedObject var recipeManager: RecipeManager
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var selectedDeveloper: DeveloperType = .d76
    @State private var filmName = ""
    @State private var iso = 400
    @State private var selectedDilution: DilutionRatio = .stock
    @State private var baseTimeMinutes = 6
    @State private var baseTimeSeconds = 0
    @State private var temperature = 20.0
    @State private var selectedAgitation: AgitationStyle = .standard
    @State private var selectedZone: ZoneSystemDevelopment = .normal
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Recipe Name", text: $name)
                    TextField("Film Name", text: $filmName)
                    
                    Stepper("ISO: \(iso)", value: $iso, in: 25...12800, step: 25)
                }
                
                Section("Developer") {
                    Picker("Developer", selection: $selectedDeveloper) {
                        ForEach(DeveloperType.allCases, id: \.self) { dev in
                            Text(dev.rawValue).tag(dev)
                        }
                    }
                    
                    Picker("Dilution", selection: $selectedDilution) {
                        ForEach(selectedDeveloper.typicalDilutions, id: \.self) { dil in
                            Text(dil.rawValue).tag(dil)
                        }
                    }
                }
                
                Section("Development Time") {
                    HStack {
                        Picker("Minutes", selection: $baseTimeMinutes) {
                            ForEach(0..<30, id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        
                        Picker("Seconds", selection: $baseTimeSeconds) {
                            ForEach(0..<60, id: \.self) { sec in
                                Text("\(sec) sec").tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                    }
                }
                
                Section("Conditions") {
                    VStack(alignment: .leading) {
                        Text("Temperature: \(String(format: "%.1f", temperature))°C")
                        Slider(value: $temperature, in: 15...25, step: 0.5)
                    }
                    
                    Picker("Agitation", selection: $selectedAgitation) {
                        ForEach(AgitationStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    
                    Picker("Zone System", selection: $selectedZone) {
                        ForEach(ZoneSystemDevelopment.allCases, id: \.self) { zone in
                            Text(zone.rawValue).tag(zone)
                        }
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .disabled(name.isEmpty || filmName.isEmpty)
                }
            }
        }
    }
    
    private func saveRecipe() {
        let totalSeconds = (baseTimeMinutes * 60) + baseTimeSeconds
        
        let recipe = DeveloperRecipe(
            name: name,
            developerName: selectedDeveloper,
            filmName: filmName,
            iso: iso,
            dilution: selectedDilution,
            baseTimeSeconds: totalSeconds,
            temperatureCelsius: temperature,
            agitationStyle: selectedAgitation,
            zoneSystem: selectedZone,
            notes: notes.isEmpty ? nil : notes
        )
        
        recipeManager.addFilmRecipe(recipe)
        isPresented = false
    }
}

// MARK: - Add Print Recipe View

struct AddPrintRecipeView: View {
    @ObservedObject var recipeManager: RecipeManager
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var selectedPaper: PaperType = .rcGlossy
    @State private var selectedDeveloper: PrintDeveloper = .dektol
    @State private var selectedDilution: DilutionRatio = .onePlusTwo
    @State private var devTimeSeconds = 60
    @State private var temperature = 20.0
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Recipe Name", text: $name)
                }
                
                Section("Paper") {
                    Picker("Paper Type", selection: $selectedPaper) {
                        ForEach(PaperType.allCases, id: \.self) { paper in
                            Text(paper.rawValue).tag(paper)
                        }
                    }
                }
                
                Section("Developer") {
                    Picker("Developer", selection: $selectedDeveloper) {
                        ForEach(PrintDeveloper.allCases, id: \.self) { dev in
                            Text(dev.rawValue).tag(dev)
                        }
                    }
                    
                    Picker("Dilution", selection: $selectedDilution) {
                        ForEach(DilutionRatio.allCases, id: \.self) { dil in
                            Text(dil.rawValue).tag(dil)
                        }
                    }
                }
                
                Section("Development Time") {
                    Stepper("\(devTimeSeconds) seconds", value: $devTimeSeconds, in: 30...300, step: 5)
                }
                
                Section("Conditions") {
                    VStack(alignment: .leading) {
                        Text("Temperature: \(String(format: "%.1f", temperature))°C")
                        Slider(value: $temperature, in: 18...24, step: 0.5)
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Print Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveRecipe() {
        let recipe = PrintRecipe(
            name: name,
            paperType: selectedPaper,
            developerName: selectedDeveloper,
            dilution: selectedDilution,
            developmentTimeSeconds: devTimeSeconds,
            temperatureCelsius: temperature,
            notes: notes.isEmpty ? nil : notes
        )
        
        recipeManager.addPrintRecipe(recipe)
        isPresented = false
    }
}

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    let recipe: DeveloperRecipe
    @ObservedObject var recipeManager: RecipeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Recipe Info") {
                    DetailRow(label: "Name", value: recipe.name)
                    DetailRow(label: "Film", value: recipe.filmName)
                    DetailRow(label: "ISO", value: "\(recipe.iso)")
                    DetailRow(label: "Developer", value: recipe.developerName.rawValue)
                    DetailRow(label: "Dilution", value: recipe.dilution.rawValue)
                }
                
                Section("Development") {
                    DetailRow(label: "Base Time", value: recipe.formattedBaseTime)
                    DetailRow(label: "Adjusted Time", value: recipe.formattedTime)
                    DetailRow(label: "Zone System", value: recipe.zoneSystem.rawValue)
                    DetailRow(label: "Temperature", value: String(format: "%.1f°C", recipe.temperatureCelsius))
                    DetailRow(label: "Agitation", value: recipe.agitationStyle.rawValue)
                }
                
                if let notes = recipe.notes {
                    Section("Notes") {
                        Text(notes)
                    }
                }
                
                Section("Actions") {
                    Button(action: {
                        let _ = recipeManager.duplicateRecipe(recipe)
                        dismiss()
                    }) {
                        Label("Duplicate Recipe", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: {
                        recipeManager.deleteFilmRecipe(recipe)
                        dismiss()
                    }) {
                        Label("Delete Recipe", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Recipe Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    RecipeManagementView(modelContext: ModelContext(try! ModelContainer(for: DeveloperRecipe.self, PrintRecipe.self)))
}
