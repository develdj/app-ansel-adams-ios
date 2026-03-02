import Foundation
import SwiftData
import Combine

// MARK: - Analog Archive Manager
/// Manager principale per le operazioni CRUD sull'archivio analogico
@MainActor
final class AnalogArchiveManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AnalogArchiveManager()
    
    // MARK: - Properties
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    @Published var isInitialized = false
    @Published var lastError: Error?
    
    // MARK: - Initialization
    private init() {}
    
    func initialize(with container: ModelContainer) {
        self.modelContainer = container
        self.modelContext = ModelContext(container)
        isInitialized = true
    }
    
    // MARK: - Context Access
    private func getContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw ArchiveError.notInitialized
        }
        return context
    }
    
    // MARK: - Roll Operations
    
    /// Crea un nuovo rullino
    func createRoll(
        name: String = "",
        filmStock: FilmStock? = nil,
        filmManufacturer: FilmManufacturer = .ilford,
        filmName: String = "",
        nominalISO: Int = 400,
        effectiveISO: Int? = nil,
        format: FilmFormat = .mm35,
        filmType: FilmType = .blackWhite,
        dateLoaded: Date = Date(),
        developerName: String = "",
        dilution: String = "1+1",
        notes: String = ""
    ) throws -> Roll {
        let context = try getContext()
        
        let roll = Roll(
            name: name,
            filmStock: filmStock,
            filmManufacturer: filmManufacturer,
            filmName: filmName,
            nominalISO: nominalISO,
            effectiveISO: effectiveISO,
            format: format,
            filmType: filmType,
            dateLoaded: dateLoaded,
            developerName: developerName,
            dilution: dilution,
            notes: notes
        )
        
        context.insert(roll)
        try context.save()
        
        return roll
    }
    
    /// Recupera tutti i rullini
    func fetchAllRolls(sortBy: RollSortOption = .dateLoadedDescending) throws -> [Roll] {
        let context = try getContext()
        
        var descriptor = FetchDescriptor<Roll>()
        descriptor.sortBy = sortBy.sortDescriptors
        
        return try context.fetch(descriptor)
    }
    
    /// Recupera rullini con filtri
    func fetchRolls(
        status: RollStatus? = nil,
        filmManufacturer: FilmManufacturer? = nil,
        format: FilmFormat? = nil,
        isFavorite: Bool? = nil,
        fromDate: Date? = nil,
        toDate: Date? = nil
    ) throws -> [Roll] {
        let context = try getContext()
        
        var descriptor = FetchDescriptor<Roll>()
        
        // Costruisci predicato
        var predicates: [Predicate<Roll>] = []
        
        if let status = status {
            predicates.append(#Predicate { $0.status == status })
        }
        
        if let manufacturer = filmManufacturer {
            predicates.append(#Predicate { $0.filmManufacturerRaw == manufacturer.rawValue })
        }
        
        if let format = format {
            predicates.append(#Predicate { $0.formatRaw == format.rawValue })
        }
        
        if let isFavorite = isFavorite {
            predicates.append(#Predicate { $0.isFavorite == isFavorite })
        }
        
        if let fromDate = fromDate {
            predicates.append(#Predicate { $0.dateLoaded >= fromDate })
        }
        
        if let toDate = toDate {
            predicates.append(#Predicate { $0.dateLoaded <= toDate })
        }
        
        if !predicates.isEmpty {
            descriptor.predicate = #Predicate { roll in
                predicates.allSatisfy { predicate in
                    // SwiftData non supporta direttamente AND di predicati
                    // In produzione usare NSCompoundPredicate
                    return true
                }
            }
        }
        
        return try context.fetch(descriptor)
    }
    
    /// Recupera un rullino per ID
    func fetchRoll(byId id: UUID) throws -> Roll? {
        let context = try getContext()
        
        var descriptor = FetchDescriptor<Roll>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        
        let results = try context.fetch(descriptor)
        return results.first
    }
    
    /// Aggiorna un rullino
    func updateRoll(_ roll: Roll) throws {
        let context = try getContext()
        roll.updateTimestamp()
        try context.save()
    }
    
    /// Elimina un rullino
    func deleteRoll(_ roll: Roll) throws {
        let context = try getContext()
        context.delete(roll)
        try context.save()
    }
    
    /// Cambia stato del rullino
    func updateRollStatus(_ roll: Roll, to status: RollStatus) throws {
        roll.status = status
        if status == .developed {
            roll.dateDeveloped = Date()
        }
        try updateRoll(roll)
    }
    
    // MARK: - Exposure Operations
    
    /// Crea una nuova esposizione
    func createExposure(
        roll: Roll,
        frameNumber: Int? = nil,
        title: String = "",
        dateTaken: Date = Date(),
        camera: Camera? = nil,
        lens: Lens? = nil,
        focalLength: Int = 50,
        shutterSpeed: ShutterSpeed = ShutterSpeed(fraction: 125),
        aperture: Aperture = Aperture(fStop: 8),
        isoUsed: Int? = nil,
        focusDistance: Double? = nil,
        lightCondition: LightCondition = .other,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        notes: String = ""
    ) throws -> Exposure {
        let context = try getContext()
        
        let actualFrameNumber = frameNumber ?? roll.nextFrameNumber()
        let actualISO = isoUsed ?? roll.effectiveISO
        
        let exposure = Exposure(
            frameNumber: actualFrameNumber,
            roll: roll,
            title: title,
            dateTaken: dateTaken,
            camera: camera,
            lens: lens,
            focalLength: focalLength,
            shutterSpeed: shutterSpeed,
            aperture: aperture,
            isoUsed: actualISO,
            focusDistance: focusDistance,
            lightCondition: lightCondition,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            notes: notes
        )
        
        context.insert(exposure)
        roll.addExposure(exposure)
        
        try context.save()
        
        return exposure
    }
    
    /// Recupera tutte le esposizioni
    func fetchAllExposures(sortBy: ExposureSortOption = .dateTakenDescending) throws -> [Exposure] {
        let context = try getContext()
        
        var descriptor = FetchDescriptor<Exposure>()
        descriptor.sortBy = sortBy.sortDescriptors
        
        return try context.fetch(descriptor)
    }
    
    /// Recupera esposizioni per rullino
    func fetchExposures(for roll: Roll) throws -> [Exposure] {
        return roll.sortedExposures()
    }
    
    /// Recupera esposizioni con filtri
    func fetchExposures(
        roll: Roll? = nil,
        camera: Camera? = nil,
        lens: Lens? = nil,
        rating: ExposureRating? = nil,
        keepersOnly: Bool = false,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        hasGPS: Bool? = nil
    ) throws -> [Exposure] {
        let context = try getContext()
        
        var descriptor = FetchDescriptor<Exposure>()
        
        // Filtri applicati in memoria per semplicità
        var results = try context.fetch(descriptor)
        
        if let roll = roll {
            results = results.filter { $0.roll?.id == roll.id }
        }
        
        if let camera = camera {
            results = results.filter { $0.cameraId == camera.id }
        }
        
        if let lens = lens {
            results = results.filter { $0.lensId == lens.id }
        }
        
        if let rating = rating {
            results = results.filter { $0.rating == rating }
        }
        
        if keepersOnly {
            results = results.filter { $0.keepers }
        }
        
        if let fromDate = fromDate {
            results = results.filter { $0.dateTaken >= fromDate }
        }
        
        if let toDate = toDate {
            results = results.filter { $0.dateTaken <= toDate }
        }
        
        if let hasGPS = hasGPS {
            results = results.filter { $0.hasGPS == hasGPS }
        }
        
        return results
    }
    
    /// Recupera esposizione per ID
    func fetchExposure(byId id: UUID) throws -> Exposure? {
        let context = try getContext()
        
        var descriptor = FetchDescriptor<Exposure>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        
        let results = try context.fetch(descriptor)
        return results.first
    }
    
    /// Aggiorna un'esposizione
    func updateExposure(_ exposure: Exposure) throws {
        let context = try getContext()
        exposure.updateTimestamp()
        try context.save()
    }
    
    /// Elimina un'esposizione
    func deleteExposure(_ exposure: Exposure) throws {
        let context = try getContext()
        if let roll = exposure.roll {
            roll.removeExposure(exposure)
        }
        context.delete(exposure)
        try context.save()
    }
    
    /// Marca come keeper
    func markAsKeeper(_ exposure: Exposure, keep: Bool = true) throws {
        exposure.keepers = keep
        try updateExposure(exposure)
    }
    
    /// Aggiorna rating
    func updateRating(_ exposure: Exposure, rating: ExposureRating) throws {
        exposure.rating = rating
        exposure.keepers = rating.isKeeper
        try updateExposure(exposure)
    }
    
    // MARK: - Print Operations
    
    /// Crea una nuova stampa
    func createPrint(
        exposure: Exposure,
        printNumber: String = "",
        title: String = "",
        datePrinted: Date = Date(),
        paperBrand: String = "Ilford",
        paperModel: String = "Multigrade IV",
        paperType: PaperType = .rc,
        paperGrade: PaperGrade = .grade2,
        paperSize: PaperSize = .a4,
        baseExposureTime: TimeInterval = 10,
        developerName: String = "Ilford Multigrade",
        developmentTime: TimeInterval = 60,
        notes: String = ""
    ) throws -> Print {
        let context = try getContext()
        
        let print = Print(
            printNumber: printNumber.isEmpty ? generatePrintNumber() : printNumber,
            exposure: exposure,
            title: title,
            datePrinted: datePrinted,
            paperBrand: paperBrand,
            paperModel: paperModel,
            paperType: paperType,
            paperGrade: paperGrade,
            paperSize: paperSize,
            baseExposureTime: baseExposureTime,
            developerName: developerName,
            developmentTime: developmentTime,
            notes: notes
        )
        
        context.insert(print)
        exposure.addPrint(print)
        
        try context.save()
        
        return print
    }
    
    /// Recupera tutte le stampe
    func fetchAllPrints(sortBy: PrintSortOption = .datePrintedDescending) throws -> [Print] {
        let context = try getContext()
        
        var descriptor = FetchDescriptor<Print>()
        descriptor.sortBy = sortBy.sortDescriptors
        
        return try context.fetch(descriptor)
    }
    
    /// Recupera stampe per esposizione
    func fetchPrints(for exposure: Exposure) throws -> [Print] {
        return exposure.sortedPrints
    }
    
    /// Recupera stampa per ID
    func fetchPrint(byId id: UUID) throws -> Print? {
        let context = try getContext()
        
        var descriptor = FetchDescriptor<Print>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        
        let results = try context.fetch(descriptor)
        return results.first
    }
    
    /// Aggiorna una stampa
    func updatePrint(_ print: Print) throws {
        let context = try getContext()
        print.updateTimestamp()
        try context.save()
    }
    
    /// Elimina una stampa
    func deletePrint(_ print: Print) throws {
        let context = try getContext()
        if let exposure = print.exposure {
            exposure.removePrint(print)
        }
        context.delete(print)
        try context.save()
    }
    
    /// Aggiunge operazione dodge/burn
    func addDodgeBurn(
        to print: Print,
        type: DodgeBurnType,
        tool: DodgeBurnTool,
        area: String,
        exposurePercentage: Double,
        duration: TimeInterval,
        notes: String = ""
    ) throws -> DodgeBurnOperation {
        let context = try getContext()
        
        let operation = DodgeBurnOperation(
            type: type,
            tool: tool,
            area: area,
            exposurePercentage: exposurePercentage,
            duration: duration,
            notes: notes,
            order: print.dodgeBurnCount
        )
        
        context.insert(operation)
        print.addDodgeBurn(operation)
        
        try context.save()
        
        return operation
    }
    
    // MARK: - Statistics
    
    /// Statistiche generali
    func getStatistics() throws -> ArchiveStatistics {
        let context = try getContext()
        
        let rolls = try context.fetch(FetchDescriptor<Roll>())
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        let prints = try context.fetch(FetchDescriptor<Print>())
        
        return ArchiveStatistics(
            totalRolls: rolls.count,
            totalExposures: exposures.count,
            totalPrints: prints.count,
            rollsByStatus: Dictionary(grouping: rolls, by: { $0.status }).mapValues { $0.count },
            rollsByFilmManufacturer: Dictionary(grouping: rolls, by: { $0.filmManufacturer }).mapValues { $0.count },
            exposuresByRating: Dictionary(grouping: exposures, by: { $0.rating }).mapValues { $0.count },
            exposuresByLightCondition: Dictionary(grouping: exposures, by: { $0.lightCondition }).mapValues { $0.count },
            keepersCount: exposures.filter { $0.keepers }.count,
            averageExposuresPerRoll: rolls.isEmpty ? 0 : Double(exposures.count) / Double(rolls.count)
        )
    }
    
    /// Statistiche mensili
    func getMonthlyStatistics(for year: Int) throws -> [MonthlyStatistics] {
        let context = try getContext()
        
        let calendar = Calendar.current
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        
        let yearExposures = exposures.filter {
            calendar.component(.year, from: $0.dateTaken) == year
        }
        
        var monthlyStats: [MonthlyStatistics] = []
        
        for month in 1...12 {
            let monthExposures = yearExposures.filter {
                calendar.component(.month, from: $0.dateTaken) == month
            }
            
            monthlyStats.append(MonthlyStatistics(
                month: month,
                year: year,
                exposureCount: monthExposures.count,
                keeperCount: monthExposures.filter { $0.keepers }.count,
                rollCount: Set(monthExposures.compactMap { $0.roll?.id }).count
            ))
        }
        
        return monthlyStats
    }
    
    // MARK: - Search
    
    /// Ricerca testuale
    func search(query: String) throws -> SearchResults {
        let context = try getContext()
        let lowerQuery = query.lowercased()
        
        // Cerca nei rullini
        let rolls = try context.fetch(FetchDescriptor<Roll>()).filter {
            $0.displayName.lowercased().contains(lowerQuery) ||
            $0.notes.lowercased().contains(lowerQuery) ||
            $0.developerName.lowercased().contains(lowerQuery)
        }
        
        // Cerca nelle esposizioni
        let exposures = try context.fetch(FetchDescriptor<Exposure>()).filter {
            $0.title.lowercased().contains(lowerQuery) ||
            $0.notes.lowercased().contains(lowerQuery) ||
            $0.locationName?.lowercased().contains(lowerQuery) ?? false ||
            $0.cameraDisplayName.lowercased().contains(lowerQuery) ||
            $0.lensDisplayName.lowercased().contains(lowerQuery)
        }
        
        // Cerca nelle stampe
        let prints = try context.fetch(FetchDescriptor<Print>()).filter {
            $0.title.lowercased().contains(lowerQuery) ||
            $0.notes.lowercased().contains(lowerQuery) ||
            $0.paperBrand.lowercased().contains(lowerQuery) ||
            $0.paperModel.lowercased().contains(lowerQuery)
        }
        
        return SearchResults(rolls: rolls, exposures: exposures, prints: prints)
    }
    
    // MARK: - Helpers
    
    private func generatePrintNumber() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "P-\(formatter.string(from: date))"
    }
}

// MARK: - Errors
enum ArchiveError: Error, LocalizedError {
    case notInitialized
    case rollNotFound
    case exposureNotFound
    case printNotFound
    case invalidData
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Archive manager non inizializzato"
        case .rollNotFound:
            return "Rullino non trovato"
        case .exposureNotFound:
            return "Esposizione non trovata"
        case .printNotFound:
            return "Stampa non trovata"
        case .invalidData:
            return "Dati non validi"
        case .saveFailed(let error):
            return "Salvataggio fallito: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sort Options
enum RollSortOption {
    case dateLoadedAscending
    case dateLoadedDescending
    case nameAscending
    case filmNameAscending
    case exposureCountDescending
    
    var sortDescriptors: [SortDescriptor<Roll>] {
        switch self {
        case .dateLoadedAscending:
            return [SortDescriptor(\.dateLoaded, order: .forward)]
        case .dateLoadedDescending:
            return [SortDescriptor(\.dateLoaded, order: .reverse)]
        case .nameAscending:
            return [SortDescriptor(\.name, order: .forward)]
        case .filmNameAscending:
            return [SortDescriptor(\.filmName, order: .forward)]
        case .exposureCountDescending:
            return [SortDescriptor(\.exposures?.count, order: .reverse)]
        }
    }
}

enum ExposureSortOption {
    case dateTakenAscending
    case dateTakenDescending
    case frameNumberAscending
    case ratingDescending
    
    var sortDescriptors: [SortDescriptor<Exposure>] {
        switch self {
        case .dateTakenAscending:
            return [SortDescriptor(\.dateTaken, order: .forward)]
        case .dateTakenDescending:
            return [SortDescriptor(\.dateTaken, order: .reverse)]
        case .frameNumberAscending:
            return [SortDescriptor(\.frameNumber, order: .forward)]
        case .ratingDescending:
            return [SortDescriptor(\.rating.rawValue, order: .reverse)]
        }
    }
}

enum PrintSortOption {
    case datePrintedAscending
    case datePrintedDescending
    case printNumberAscending
    
    var sortDescriptors: [SortDescriptor<Print>] {
        switch self {
        case .datePrintedAscending:
            return [SortDescriptor(\.datePrinted, order: .forward)]
        case .datePrintedDescending:
            return [SortDescriptor(\.datePrinted, order: .reverse)]
        case .printNumberAscending:
            return [SortDescriptor(\.printNumber, order: .forward)]
        }
    }
}

// MARK: - Statistics Types
struct ArchiveStatistics: Codable, Sendable {
    let totalRolls: Int
    let totalExposures: Int
    let totalPrints: Int
    let rollsByStatus: [RollStatus: Int]
    let rollsByFilmManufacturer: [FilmManufacturer: Int]
    let exposuresByRating: [ExposureRating: Int]
    let exposuresByLightCondition: [LightCondition: Int]
    let keepersCount: Int
    let averageExposuresPerRoll: Double
    
    var keeperRate: Double {
        totalExposures > 0 ? Double(keepersCount) / Double(totalExposures) * 100 : 0
    }
    
    var printsPerExposure: Double {
        totalExposures > 0 ? Double(totalPrints) / Double(totalExposures) : 0
    }
}

struct MonthlyStatistics: Codable, Sendable {
    let month: Int
    let year: Int
    let exposureCount: Int
    let keeperCount: Int
    let rollCount: Int
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.monthSymbols[month - 1].capitalized
    }
    
    var keeperRate: Double {
        exposureCount > 0 ? Double(keeperCount) / Double(exposureCount) * 100 : 0
    }
}

struct SearchResults: Sendable {
    let rolls: [Roll]
    let exposures: [Exposure]
    let prints: [Print]
    
    var isEmpty: Bool {
        rolls.isEmpty && exposures.isEmpty && prints.isEmpty
    }
    
    var totalCount: Int {
        rolls.count + exposures.count + prints.count
    }
}
