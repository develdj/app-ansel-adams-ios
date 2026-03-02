import Foundation
import SwiftData
import Combine

// MARK: - Recipe Manager

/// Manages film development and print recipes
/// Provides CRUD operations and recipe discovery
@MainActor
final class RecipeManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var filmRecipes: [DeveloperRecipe] = []
    @Published var printRecipes: [PrintRecipe] = []
    @Published var favoriteRecipes: [DeveloperRecipe] = []
    @Published var recentRecipes: [DeveloperRecipe] = []
    @Published var searchResults: [DeveloperRecipe] = []
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRecipes()
    }
    
    // MARK: - Loading
    
    func loadRecipes() {
        isLoading = true
        
        do {
            let filmDescriptor = FetchDescriptor<DeveloperRecipe>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            filmRecipes = try modelContext.fetch(filmDescriptor)
            
            let printDescriptor = FetchDescriptor<PrintRecipe>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            printRecipes = try modelContext.fetch(printDescriptor)
            
            updateFavorites()
            updateRecent()
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load recipes: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Film Recipes
    
    func addFilmRecipe(_ recipe: DeveloperRecipe) {
        modelContext.insert(recipe)
        save()
        filmRecipes.insert(recipe, at: 0)
    }
    
    func updateFilmRecipe(_ recipe: DeveloperRecipe) {
        save()
        if let index = filmRecipes.firstIndex(where: { $0.id == recipe.id }) {
            filmRecipes[index] = recipe
        }
    }
    
    func deleteFilmRecipe(_ recipe: DeveloperRecipe) {
        modelContext.delete(recipe)
        save()
        filmRecipes.removeAll { $0.id == recipe.id }
    }
    
    func deleteFilmRecipes(at offsets: IndexSet) {
        for index in offsets {
            let recipe = filmRecipes[index]
            modelContext.delete(recipe)
        }
        save()
        filmRecipes.remove(atOffsets: offsets)
    }
    
    func duplicateRecipe(_ recipe: DeveloperRecipe) -> DeveloperRecipe {
        let copy = DeveloperRecipe(
            name: "\(recipe.name) (Copy)",
            developerName: recipe.developerName,
            filmName: recipe.filmName,
            iso: recipe.iso,
            dilution: recipe.dilution,
            baseTimeSeconds: recipe.baseTimeSeconds,
            temperatureCelsius: recipe.temperatureCelsius,
            agitationStyle: recipe.agitationStyle,
            zoneSystem: recipe.zoneSystem,
            notes: recipe.notes
        )
        addFilmRecipe(copy)
        return copy
    }
    
    // MARK: - Print Recipes
    
    func addPrintRecipe(_ recipe: PrintRecipe) {
        modelContext.insert(recipe)
        save()
        printRecipes.insert(recipe, at: 0)
    }
    
    func updatePrintRecipe(_ recipe: PrintRecipe) {
        save()
        if let index = printRecipes.firstIndex(where: { $0.id == recipe.id }) {
            printRecipes[index] = recipe
        }
    }
    
    func deletePrintRecipe(_ recipe: PrintRecipe) {
        modelContext.delete(recipe)
        save()
        printRecipes.removeAll { $0.id == recipe.id }
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(_ recipe: DeveloperRecipe) {
        recipe.isFavorite.toggle()
        save()
        updateFavorites()
    }
    
    private func updateFavorites() {
        favoriteRecipes = filmRecipes.filter { $0.isFavorite }
    }
    
    // MARK: - Recent
    
    func markAsUsed(_ recipe: DeveloperRecipe) {
        recipe.lastUsed = Date()
        save()
        updateRecent()
    }
    
    private func updateRecent() {
        recentRecipes = filmRecipes
            .filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? Date.distantPast) > ($1.lastUsed ?? Date.distantPast) }
            .prefix(10)
            .map { $0 }
    }
    
    // MARK: - Search
    
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let lowerQuery = query.lowercased()
        searchResults = filmRecipes.filter { recipe in
            recipe.name.lowercased().contains(lowerQuery) ||
            recipe.filmName.lowercased().contains(lowerQuery) ||
            recipe.developerName.rawValue.lowercased().contains(lowerQuery) ||
            recipe.notes?.lowercased().contains(lowerQuery) == true
        }
    }
    
    func searchByFilm(_ filmName: String) -> [DeveloperRecipe] {
        return filmRecipes.filter { $0.filmName.lowercased() == filmName.lowercased() }
    }
    
    func searchByDeveloper(_ developer: DeveloperType) -> [DeveloperRecipe] {
        return filmRecipes.filter { $0.developerName == developer }
    }
    
    func searchByISO(_ iso: Int) -> [DeveloperRecipe] {
        return filmRecipes.filter { $0.iso == iso }
    }
    
    // MARK: - Built-in Presets
    
    func loadBuiltInPresets() {
        let presets = RecipePresets.allFilmRecipes
        
        for preset in presets {
            // Check if preset already exists
            let exists = filmRecipes.contains {
                $0.name == preset.name && $0.filmName == preset.filmName
            }
            
            if !exists {
                addFilmRecipe(preset)
            }
        }
    }
    
    func loadPrintPresets() {
        let presets = RecipePresets.allPrintRecipes
        
        for preset in presets {
            let exists = printRecipes.contains { $0.name == preset.name }
            
            if !exists {
                addPrintRecipe(preset)
            }
        }
    }
    
    // MARK: - Import/Export
    
    func exportRecipe(_ recipe: DeveloperRecipe) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            return try encoder.encode(recipe)
        } catch {
            errorMessage = "Failed to export recipe: \(error.localizedDescription)"
            return nil
        }
    }
    
    func importRecipe(from data: Data) -> DeveloperRecipe? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let recipe = try decoder.decode(DeveloperRecipe.self, from: data)
            recipe.id = UUID() // Generate new ID to avoid conflicts
            addFilmRecipe(recipe)
            return recipe
        } catch {
            errorMessage = "Failed to import recipe: \(error.localizedDescription)"
            return nil
        }
    }
    
    func exportAllRecipes() -> Data? {
        let exportData = RecipeExport(
            filmRecipes: filmRecipes,
            printRecipes: printRecipes,
            exportDate: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            return try encoder.encode(exportData)
        } catch {
            errorMessage = "Failed to export recipes: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Statistics
    
    func getRecipeStatistics() -> RecipeStatistics {
        let totalRecipes = filmRecipes.count
        let totalPrintRecipes = printRecipes.count
        let favoriteCount = favoriteRecipes.count
        
        let developerCounts = Dictionary(grouping: filmRecipes) { $0.developerName }
            .mapValues { $0.count }
        
        let filmCounts = Dictionary(grouping: filmRecipes) { $0.filmName }
            .mapValues { $0.count }
        
        return RecipeStatistics(
            totalFilmRecipes: totalRecipes,
            totalPrintRecipes: totalPrintRecipes,
            favoriteCount: favoriteCount,
            developerUsage: developerCounts,
            filmUsage: filmCounts
        )
    }
    
    // MARK: - Private Methods
    
    private func save() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Recipe Presets

/// Built-in recipe presets based on manufacturer data and common practices
enum RecipePresets {
    
    // MARK: - Kodak Films
    
    static let triX_D76: DeveloperRecipe = {
        let recipe = DeveloperRecipe(
            name: "Tri-X 400 in D-76",
            developerName: .d76,
            filmName: "Kodak Tri-X 400",
            iso: 400,
            dilution: .stock,
            baseTimeSeconds: 570, // 9:30 at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Classic grain structure, rich tonal range"
        )
        return recipe
    }()
    
    static let triX_HC110: DeveloperRecipe = {
        let recipe = DeveloperRecipe(
            name: "Tri-X 400 in HC-110",
            developerName: .hc110DilB,
            filmName: "Kodak Tri-X 400",
            iso: 400,
            dilution: .dilutionB,
            baseTimeSeconds: 300, // 5:00 at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Sharp, crisp negatives"
        )
        return recipe
    }()
    
    static let tmax400_TMax: DeveloperRecipe = {
        let recipe = DeveloperRecipe(
            name: "T-Max 400 in T-Max Dev",
            developerName: .tmax,
            filmName: "Kodak T-Max 400",
            iso: 400,
            dilution: .onePlusFour,
            baseTimeSeconds: 390, // 6:30 at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Fine grain, high sharpness"
        )
        return recipe
    }()
    
    // MARK: - Ilford Films
    
    static let hp5_D76: DeveloperRecipe = {
        let recipe = DeveloperRecipe(
            name: "HP5+ in D-76",
            developerName: .d76,
            filmName: "Ilford HP5+",
            iso: 400,
            dilution: .stock,
            baseTimeSeconds: 480, // 8:00 at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Versatile, forgiving film"
        )
        return recipe
    }()
    
    static let hp5_HC110: DeveloperRecipe = {
        let recipe = DeveloperRecipe(
            name: "HP5+ in HC-110",
            developerName: .hc110DilB,
            filmName: "Ilford HP5+",
            iso: 400,
            dilution: .dilutionB,
            baseTimeSeconds: 300, // 5:00 at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Good sharpness and speed"
        )
        return recipe
    }()
    
    static let hp5_Rodinal: DeveloperRecipe = {
        let recipe = DeveloperRecipe(
            name: "HP5+ in Rodinal",
            developerName: .rodinalOnePlusFifty,
            filmName: "Ilford HP5+",
            iso: 400,
            dilution: .onePlusFifty,
            baseTimeSeconds: 900, // 15:00 at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .minimal,
            zoneSystem: .normal,
            notes: "High acutance, visible grain"
        )
        return recipe
    }()
    
    static let fp4_D76: DeveloperRecipe = {
        let recipe = DeveloperRecipe(
            name: "FP4+ in D-76",
            developerName: .d76,
            filmName: "Ilford FP4+",
            iso: 125,
            dilution: .stock,
            baseTimeSeconds: 540, // 9:00 at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "Fine grain, excellent detail"
        )
        return recipe
    }()
    
    static let delta3200_Microphen: DeveloperRecipe = {
        let recipe = DeveloperRecipe(
            name: "Delta 3200 in Microphen",
            developerName: .microphen,
            filmName: "Ilford Delta 3200",
            iso: 3200,
            dilution: .stock,
            baseTimeSeconds: 540, // 9:00 at 20°C
            temperatureCelsius: 20.0,
            agitationStyle: .standard,
            zoneSystem: .normal,
            notes: "High speed, manageable grain"
        )
        return recipe
    }()
    
    // MARK: - Print Recipes
    
    static let dektol_RC: PrintRecipe = {
        let recipe = PrintRecipe(
            name: "Dektol for RC Paper",
            paperType: .rcGlossy,
            developerName: .dektol,
            dilution: .onePlusTwo,
            developmentTimeSeconds: 60,
            temperatureCelsius: 20.0,
            notes: "Standard dilution for RC papers"
        )
        return recipe
    }()
    
    static let dektol_Fiber: PrintRecipe = {
        let recipe = PrintRecipe(
            name: "Dektol for Fiber Paper",
            paperType: .fiberGlossy,
            developerName: .dektol,
            dilution: .onePlusTwo,
            developmentTimeSeconds: 120,
            temperatureCelsius: 20.0,
            notes: "Extended time for fiber base"
        )
        return recipe
    }()
    
    static let ilfordMultigrade: PrintRecipe = {
        let recipe = PrintRecipe(
            name: "Ilford Multigrade Dev",
            paperType: .rcGlossy,
            developerName: .ilfordMultigrade,
            dilution: .onePlusNine,
            developmentTimeSeconds: 60,
            temperatureCelsius: 20.0,
            notes: "Clean working, long life"
        )
        return recipe
    }()
    
    // MARK: - Collections
    
    static var allFilmRecipes: [DeveloperRecipe] {
        [
            triX_D76,
            triX_HC110,
            tmax400_TMax,
            hp5_D76,
            hp5_HC110,
            hp5_Rodinal,
            fp4_D76,
            delta3200_Microphen
        ]
    }
    
    static var allPrintRecipes: [PrintRecipe] {
        [
            dektol_RC,
            dektol_Fiber,
            ilfordMultigrade
        ]
    }
}

// MARK: - Supporting Types

struct RecipeExport: Codable {
    let filmRecipes: [DeveloperRecipe]
    let printRecipes: [PrintRecipe]
    let exportDate: Date
}

struct RecipeStatistics {
    let totalFilmRecipes: Int
    let totalPrintRecipes: Int
    let favoriteCount: Int
    let developerUsage: [DeveloperType: Int]
    let filmUsage: [String: Int]
}

// MARK: - Recipe Extensions

extension DeveloperRecipe {
    var formattedTime: String {
        let minutes = adjustedTimeSeconds / 60
        let seconds = adjustedTimeSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    var formattedBaseTime: String {
        let minutes = baseTimeSeconds / 60
        let seconds = baseTimeSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    var summary: String {
        "\(filmName) @ ISO \(iso) in \(developerName.rawValue) \(dilution.rawValue)"
    }
}

extension PrintRecipe {
    var formattedTime: String {
        let minutes = developmentTimeSeconds / 60
        let seconds = developmentTimeSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}
